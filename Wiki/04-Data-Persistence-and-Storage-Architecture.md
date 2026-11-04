# Module 04: Data Persistence & Storage Architecture

This module provides the complete technical specification for Kikobar's storage layer: the direct SQLite C API database engine, cascading relational schema, container filesystem layout, security-scoped bookmark serialization, and QuickLook thumbnail caching.

---

## 1. Direct SQLite C-API Engine (`libsqlite3`)

Rather than relying on bulky ORM frameworks (such as CoreData or SwiftData) that impose substantial runtime overhead and schema migration complexities, Kikobar implements a lightweight, pure Swift wrapper around the native system SQLite C library (`libsqlite3`).

### Thread-Safety & Re-entrant Execution Architecture

SQLite database handles (`OpaquePointer`) are not inherently thread-safe across concurrent threads. Kikobar enforces safety using a dedicated serial `DispatchQueue` combined with a re-entrant `DispatchSpecificKey`:

```swift
public final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.kikobar.database", qos: .userInitiated)
    private static let queueSpecificKey = DispatchSpecificKey<Void>()

    public init(databaseURL: URL? = nil, inMemory: Bool = false) throws {
        queue.setSpecific(key: Self.queueSpecificKey, value: ())
        // Open connection and configure pragmas...
    }

    /// Re-entrant dispatcher: executes immediately if already on the database queue,
    /// otherwise dispatches synchronously to serialize access.
    public func perform<T>(_ block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.queueSpecificKey) != nil {
            return try block()
        } else {
            return try queue.sync {
                try block()
            }
        }
    }
}
```

This architecture guarantees that nested operations (e.g. an item insertion inside an ongoing category transaction) will **never deadlock**.

---

## 2. Pragmas & ACID Concurrency

Upon establishing a database connection, Kikobar immediately configures three critical SQLite PRAGMAs:

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

### Purpose of Each Pragma

1. **`PRAGMA foreign_keys = ON;`**:
   SQLite defaults to ignoring foreign key constraints. Enabling this is mandatory for cascading deletes: when a category/board is deleted, all child items stored in `items` are automatically deleted by the database engine.
2. **`PRAGMA journal_mode = WAL;` (Write-Ahead Logging)**:
   In WAL mode, readers do not block writers, and writers do not block readers. Reads execute concurrently with background file ingestion tasks without lock contention.
3. **`PRAGMA busy_timeout = 5000;`**:
   Instructs SQLite to wait up to 5,000 milliseconds before throwing a `SQLITE_BUSY` error if another thread is momentarily finalizing a disk commit.

---

## 3. Relational Database Schema & DDL

The database file resides at `~/Library/Application Support/Kikobar/Database/kikobar.sqlite`.

```
┌─────────────────────────────────┐
│           categories            │
├─────────────────────────────────┤
│ id: TEXT (PK, UUID)             │
│ name: TEXT                      │
│ hex_color: TEXT                 │
│ is_expanded: INTEGER (0 or 1)   │
│ sort_order: INTEGER             │
│ created_at: REAL (Epoch time)   │
│ updated_at: REAL (Epoch time)   │
└───────────────┬─────────────────┘
                │ 1
                │
                │ N (ON DELETE CASCADE)
                ▼
┌─────────────────────────────────┐
│              items              │
├─────────────────────────────────┤
│ id: TEXT (PK, UUID)             │
│ name: TEXT                      │
│ category_id: TEXT (FK)          │
│ content_type: TEXT              │
│ storage_type: TEXT              │
│ source_url: TEXT (Nullable)     │
│ local_path: TEXT (Nullable)     │
│ bookmark_data: BLOB (Nullable)  │
│ text_content: TEXT (Nullable)   │
│ thumbnail_path: TEXT (Nullable) │
│ file_size: INTEGER (Nullable)   │
│ uti: TEXT (Nullable)            │
│ date_added: REAL (Epoch time)   │
│ is_source_available: INTEGER    │
└─────────────────────────────────┘
```

### Complete Schema DDL

```sql
-- 1. Categories / Boards Table
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    hex_color TEXT NOT NULL,
    is_expanded INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- 2. Collected Items Table
CREATE TABLE IF NOT EXISTS items (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category_id TEXT NOT NULL,
    content_type TEXT NOT NULL,
    storage_type TEXT NOT NULL,
    source_url TEXT,
    local_path TEXT,
    bookmark_data BLOB,
    text_content TEXT,
    thumbnail_path TEXT,
    file_size INTEGER,
    uti TEXT,
    date_added REAL NOT NULL,
    is_source_available INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 3. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id);
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON categories(sort_order);
```

---

## 4. Prepared Statement Abstraction (`SQLiteStatement`)

To prevent SQL injection and avoid string parsing overhead, all queries use prepared statements:

```swift
public struct SQLiteStatement {
    public let handle: OpaquePointer

    public func bind(index: Int32, _ value: String?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let rc = sqlite3_bind_text(handle, index, value, -1, SQLITE_TRANSIENT)
        if rc != SQLITE_OK { throw SQLiteError.bindFailed("Failed to bind String") }
    }

    public func bind(index: Int32, _ value: Data?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let rc = value.withUnsafeBytes { ptr in
            sqlite3_bind_blob(handle, index, ptr.baseAddress, Int32(value.count), SQLITE_TRANSIENT)
        }
        if rc != SQLITE_OK { throw SQLiteError.bindFailed("Failed to bind Blob") }
    }

    public func columnString(index: Int32) -> String? {
        guard let cString = sqlite3_column_text(handle, index) else { return nil }
        return String(cString: cString)
    }

    public func columnDouble(index: Int32) -> Double {
        sqlite3_column_double(handle, index)
    }
}
```

---

## 5. Sandboxed Filesystem Storage Hierarchy

Kikobar maintains a dedicated application support container:

```
~/Library/Application Support/Kikobar/
├── Database/
│   ├── kikobar.sqlite
│   ├── kikobar.sqlite-wal
│   └── kikobar.sqlite-shm
└── Storage/
    ├── Files/          # Managed file duplicates and documents
    ├── Images/         # Browser-extracted bitmaps and web graphics
    ├── Snippets/       # Plain text snippet files (.txt)
    └── Thumbnails/     # Cached QuickLook preview images (.png)
```

### Collision-Proof File Storage (`LocalFileStorageService.swift`)

When storing files into the managed container, file names are sanitized and assigned a unique UUID prefix:

```swift
public func storeFile(from sourceURL: URL, preferredName: String?) async throws -> StoredFileResult {
    let rawName = preferredName ?? sourceURL.lastPathComponent
    let sanitized = sanitizeFileName(rawName)
    let uniqueName = "\(UUID().uuidString)_\(sanitized)"
    let targetURL = storageDirectory.appendingPathComponent("Files").appendingPathComponent(uniqueName)

    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    let attributes = try FileManager.default.attributesOfItem(atPath: targetURL.path)
    let fileSize = attributes[.size] as? Int64 ?? 0

    return StoredFileResult(
        localPath: targetURL.path,
        fileSize: fileSize,
        storageType: .managedCopy
    )
}
```

---

## 6. Security-Scoped Bookmarks vs Managed Copies

Kikobar utilizes two distinct storage strategies depending on content type:

| Storage Type | Description | When Used |
| :--- | :--- | :--- |
| **`StorageType.managedCopy`** | Physical file duplicate stored inside `~/Library/Application Support/Kikobar/Storage/`. | Web browser images, promised files, and text snippets. Guaranteed persistent even if the original source disappears. |
| **`StorageType.reference`** | Stores the original path plus a macOS **Security-Scoped Bookmark** (`Data`). | Large Finder files, system documents, and folders. Avoids duplicating large gigabyte files while retaining access permissions. |

### Generating & Resolving Bookmarks

```swift
// Generating bookmark on drop
let bookmark = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

// Resolving bookmark on retrieval
var isStale = false
let resolvedURL = try URL(
    resolvingBookmarkData: bookmark,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
_ = resolvedURL.startAccessingSecurityScopedResource()
```

---

## 7. QuickLook Thumbnail Generator & Disk Caching

Generating thumbnails on the fly can degrade scroll performance in the sidebar. `QuickLookThumbnailService` offloads rendering to Apple's `QLThumbnailGenerator` and caches the resulting PNG images to disk:

```swift
public func generateThumbnail(for fileURL: URL, targetSize: CGSize) async throws -> String {
    let cacheKey = "\(fileURL.path.hashValue)_\(Int(targetSize.width))x\(Int(targetSize.height)).png"
    let cacheURL = thumbnailCacheDirectory.appendingPathComponent(cacheKey)

    // Return cached thumbnail if present on disk
    if FileManager.default.fileExists(atPath: cacheURL.path) {
        return cacheURL.path
    }

    // Generate asynchronous native preview
    let request = QLThumbnailGenerator.Request(
        fileAt: fileURL,
        size: targetSize,
        scale: NSScreen.main?.backingScaleFactor ?? 2.0,
        representationTypes: .thumbnail
    )

    let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
    let nsImage = representation.nsImage

    // Save PNG representation to disk cache
    if let tiffData = nsImage.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try pngData.write(to: cacheURL, options: .atomic)
        return cacheURL.path
    }

    throw ThumbnailError.generationFailed
}
```

---

Continue to [**Module 05: User Interface & Design System**](05-User-Interface-and-Design-System.md) to explore the visual styling and SwiftUI component hierarchy.
