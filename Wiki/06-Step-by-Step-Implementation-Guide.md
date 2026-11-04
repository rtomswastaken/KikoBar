# Module 06: Step-by-Step Implementation Guide

This module provides the chronological, step-by-step engineering recipe to construct Kikobar completely from scratch. By following this blueprint, any developer can rebuild the entire application without needing external templates.

---

## 📋 Build Sequence Overview

```
Phase 1: SPM Package & Configuration
   │
   ▼
Phase 2: Domain Layer & Storage Protocols
   │
   ▼
Phase 3: SQLite Engine & Repositories (libsqlite3)
   │
   ▼
Phase 4: Filesystem Storage & QuickLook Thumbnails
   │
   ▼
Phase 5: Pasteboard Ingestion & DragSessionManager
   │
   ▼
Phase 6: AppKit Floating Windowing & Screen Geometry
   │
   ▼
Phase 7: SwiftUI Sidebar, Boards & Interaction Flows
   │
   ▼
Phase 8: Release Packaging & Ad-hoc Code Signing
```

---

## Phase 1: SPM Package & Configuration

Initialize a clean Swift Package Manager executable project:

```bash
mkdir Kikobar && cd Kikobar
swift package init --type executable --name Kikobar
```

### `Package.swift` Configuration

Configure the manifest to target **macOS 14 (Sonoma)** or later, linking system frameworks and the SQLite C library:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kikobar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Kikobar", targets: ["Kikobar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Kikobar",
            dependencies: [],
            path: "Sources/Kikobar",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuickLook"),
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
```

---

## Phase 2: Domain Models & Protocols

Create domain data structures in `Sources/Kikobar/Core/`:

1. **`CollectionCategory.swift`**: Defines boards with `id: UUID`, `name: String`, `hexColor: String`, `isExpanded: Bool`, and `sortOrder: Int`.
2. **`CollectionItem.swift`**: Defines collected assets with `id: UUID`, `name: String`, `categoryID: UUID`, `contentType: ContentType`, `storageType: StorageType`, `localPath: String?`, and `bookmarkData: Data?`.
3. **`ContentType.swift`**: `.image`, `.document`, `.url`, `.text`, `.genericFile`.
4. **`StorageType.swift`**: `.managedCopy` (self-contained files) vs `.reference` (security-scoped external files).
5. **`IngestionPayload.swift`**: `.file(url, isBookmarkable)`, `.image(data, suggestedName)`, `.url(url, title)`, `.text(content, title)`, `.filePromise(receiver)`.
6. **Core Protocols**: Define `CategoryRepositoryProtocol`, `CollectionRepositoryProtocol`, `FileStorageServiceProtocol`, and `DragIngestionServiceProtocol`.

---

## Phase 3: SQLite Persistence Engine (`libsqlite3`)

Implement `SQLiteDatabase.swift` using direct C API pointers:

```swift
import SQLite3

public final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.kikobar.database", qos: .userInitiated)
    private static let queueSpecificKey = DispatchSpecificKey<Void>()

    public init(databaseURL: URL? = nil) throws {
        queue.setSpecific(key: Self.queueSpecificKey, value: ())
        let path = (databaseURL ?? defaultURL).path
        
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard rc == SQLITE_OK, let handle = handle else {
            throw SQLiteError.connectionFailed("Could not open SQLite database")
        }
        self.db = handle

        // Enable Write-Ahead Logging & Foreign Keys
        try executeRaw("PRAGMA foreign_keys = ON;")
        try executeRaw("PRAGMA journal_mode = WAL;")
        try executeRaw("PRAGMA busy_timeout = 5000;")
        try createTables()
    }
}
```

Implement `SQLiteCategoryRepository.swift` and `SQLiteCollectionRepository.swift` to execute parameterized `INSERT`, `SELECT`, `UPDATE`, and `DELETE` statements.

---

## Phase 4: Local Storage & Thumbnail Generation

1. **`LocalFileStorageService.swift`**:
   - Creates sandboxed directories inside `~/Library/Application Support/Kikobar/Storage/`.
   - Implements `storeFile()`, `storeData()`, and `deleteFile()`.
2. **`QuickLookThumbnailService.swift`**:
   - Wraps `QLThumbnailGenerator.shared.generateBestRepresentation`.
   - Caches rendered PNG thumbnails in `Storage/Thumbnails/` to maintain instant 60 FPS scrolling in the sidebar.

---

## Phase 5: Pasteboard Extraction & Drag Session Management

1. **`PasteboardExtractor.swift`**:
   - Inspects `NSPasteboard` instances for `.filePromise`, `.fileURL`, `.tiff`/`.png`, `.URL`, and `.string`.
   - Extracts and normalizes data into `IngestionPayload`.
2. **`DragIngestionService.swift`**:
   - Takes an `IngestionPayload` and target `boardID`.
   - Stores raw bytes/files via `FileStorageService`.
   - Generates QuickLook thumbnails.
   - Instantiates and returns a complete `CollectionItem`.
3. **`DragSessionManager.swift`**:
   - Manages global drag state (`idle`, `dragDetected`, `sidebarOpen`, `hoveringOverBoard`, `itemDropped`, `dismissalPending`).
   - Implements the debounced **1.0-second auto-dismissal countdown**.

---

## Phase 6: AppKit Windowing & Screen Geometry

1. **`ScreenGeometry.swift`**:
   - Calculates display coordinate frames for any `NSScreen`.
   - Computes expanded frames docked to the right edge (`visible.maxX - width`).
   - Computes invisible trigger frames docked to the top-right corner (`visible.maxX - 20`, height 40%).
2. **`TriggerZoneWindow.swift`**:
   - An invisible, borderless `NSPanel` registering for drag types via `registerForDraggedTypes`.
   - Notifies `DragSessionManager` on `draggingEntered`.
3. **`CollectionPanelWindow.swift`**:
   - Borderless `NSPanel` configured with `[.nonactivatingPanel]`, `.floating` level, and `[.canJoinAllSpaces, .fullScreenAuxiliary]`.
4. **`CollectionPanelController.swift`**:
   - Houses the SwiftUI `NSHostingView`.
   - Animates sliding panel expansion and collapse via `NSAnimationContext`.

---

## Phase 7: SwiftUI Sidebar, Boards & Interaction Flows

1. **`AppCoordinator.swift`**:
   - Central `@MainActor` state publisher (`@Published var categories`, `@Published var itemsByCategory`).
   - Coordinates `showPanel()`, `hidePanel()`, `handleDrop()`, and `handleDropWithoutTarget()`.
2. **`RightSidebarView.swift`**:
   - Scrollable board card list with drag-and-drop targeting.
   - Intercepts empty space drops to trigger the **Automatic Board Creation** workflow.
   - Binds keyboard events: `Space` (QuickLook), `Return` (Open Item), `Delete` (Remove Item).
3. **`BoardCardView.swift` & `BoardMediaGridView.swift`**:
   - Expandable board cards with color swatches, item counts, and media grids.
   - Attaches `.onDrag { ItemExportService.itemProvider(for: item) }` to enable drag-out export.
4. **`BoardColorPickerPopover.swift` & `BoardDeletionDialogView.swift`**:
   - Circular 10-shade color selector.
   - Themed modal confirmation for safe board deletion.

---

## Phase 8: Packaging, Code Signing & Distribution

A standalone macOS application bundle (`.app`) requires an internal directory hierarchy:

```
Kikobar.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo
    ├── MacOS/
    │   └── Kikobar (Compiled Mach-O binary)
    └── Resources/
        ├── AppIcon.icns
        └── Fonts/
            ├── Poppins-Regular.ttf
            ├── Poppins-Medium.ttf
            ├── Poppins-SemiBold.ttf
            └── Poppins-Bold.ttf
```

### Automation Script (`scripts/package_app.sh`)

Automate bundle creation, font embedding, and ad-hoc code signing:

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Building Release Executable..."
cd "${PROJECT_ROOT}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Kikobar"
APP_DIR="${PROJECT_ROOT}/build/Kikobar.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/Kikobar"
chmod +x "${MACOS_DIR}/Kikobar"
cp "${PROJECT_ROOT}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
cp -R "${PROJECT_ROOT}/Resources/Fonts" "${RESOURCES_DIR}/"
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Ad-hoc signing bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Creating distribution archive..."
mkdir -p "${PROJECT_ROOT}/Releases"
(cd "${PROJECT_ROOT}/build" && zip -r -q -y "${PROJECT_ROOT}/Releases/Kikobar-v0.1.0-alpha.zip" "Kikobar.app")
echo "==> Successfully packaged: Releases/Kikobar-v0.1.0-alpha.zip"
```

---

## ⚠️ Common macOS Pitfalls & Engineering Solutions

### 1. Dock Icon Appearing Unexpectedly
- **Cause**: By default, macOS treats all Cocoa binaries as foreground apps.
- **Solution**: Set `LSUIElement = true` in `Info.plist` AND invoke `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`.

### 2. Panel Steals Focus While User is Typing in Another App
- **Cause**: Using standard `NSWindow` or missing style masks.
- **Solution**: Subclass `NSPanel` with style mask `[.borderless, .nonactivatingPanel]`, set `canBecomeKey = true`, and override `canBecomeMain = false`.

### 3. Drag Coordinates Misalignment on Multi-Monitor Setups
- **Cause**: Secondary monitors can have negative coordinate origins relative to the primary display.
- **Solution**: Always query `screen.visibleFrame` directly and compute relative coordinates rather than assuming `(0, 0)` origin.

### 4. Broken File Access for External Finder Files
- **Cause**: Sandboxed apps lose access to dragged file paths once the drag session terminates.
- **Solution**: Immediately create a **Security-Scoped Bookmark** (`URL.bookmarkData(options: .withSecurityScope, ...)`) and store the resulting `Data` blob in SQLite.

---

## 🏁 Verification Checklist

- [x] Application compiles cleanly in Release mode (`swift build -c release`).
- [x] Panel slides out smoothly when dragging items to the top-right screen quadrant.
- [x] Dropping on a board card immediately inserts the item and updates the count badge.
- [x] Dropping into empty sidebar space triggers inline board creation and preserves dropped items.
- [x] Items can be previewed by pressing `Spacebar` (QuickLook).
- [x] Items can be dragged out of Kikobar directly into external apps (`ItemExportService`).
- [x] Boards and items persist across application reboots via SQLite.
- [x] Packaged `.app` runs as a background accessory with the custom `AppIcon.icns`.
