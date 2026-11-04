# Module 01: System Architecture & Design Philosophy

This module details the architectural foundations of Kikobar: the core design philosophy, system decomposition, dependency management, concurrency rules, and application lifecycle.

---

## 1. Core Design Philosophy

Building native macOS utilities demands adherence to platform conventions while solving real user pain points. Kikobar was engineered around four non-negotiable principles:

### A. Zero Intrusive Permissions
Many macOS shelf or launcher utilities take the shortcut of requesting **macOS Accessibility Privileges (`AXIsProcessTrusted`)** or **Screen Recording Privileges** to globally track cursor movements across other applications.
- **The Problem**: Accessibility permissions trigger intimidating system permission prompts, create security attack surfaces, and frequently break across macOS updates or sandbox policies.
- **The Kikobar Solution**: Kikobar achieves global edge-detection using lightweight, borderless, non-activating `NSPanel` trigger windows positioned along display borders. macOS naturally routes drag-and-drop events to any window registered for drag types via `NSDraggingDestination`. This delivers flawless edge detection with **zero Accessibility or Screen Recording permissions**.

### B. Non-Activating Windowing Policy
When a user is dragging a paragraph of text from Xcode or an image from Safari, the active application must **never lose keyboard focus or deactivate**:
- Kikobar operates with `NSApplication.ActivationPolicy.accessory`. It does not show a dock icon by default and does not steal focus when its panels slide onto the screen.
- All windows are custom `NSPanel` subclasses configured with `.nonactivatingPanel`.

### C. Zero Third-Party Dependencies
Every subsystem in Kikobar is built directly against native Apple frameworks:
- **UI**: SwiftUI + AppKit
- **Database**: Native SQLite3 C library (`libsqlite3`) wrapped in type-safe Swift bindings
- **Storage & Security**: Security-Scoped Bookmarks & Uniform Type Identifiers (`UTType`)
- **Previews**: macOS QuickLook & QuickLookThumbnailing (`QLThumbnailGenerator`)
- **Benefits**: Instant compilation, zero dependency rot, tiny binary footprint (~4.2 MB total bundle), and 100% binary stability across macOS Sonoma, Sequoia, and future versions.

### D. Data Longevity & Integrity
Temporary scratchpads should never result in lost work. Kikobar stores all metadata in an ACID-compliant local SQLite database operating in Write-Ahead Logging (WAL) mode, guaranteeing durability even during system reboots or unexpected terminations.

---

## 2. Layered Architecture

Kikobar enforces a strict **4-tier layered architecture**. Information flows unidirectionally from presentation down to infrastructure, coordinated by central application state:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  - SwiftUI Views (RightSidebarView, BoardCardView, etc.)     │
│  - AppKit Windows (CollectionPanelWindow, TriggerZoneWindow)│
│  - ThemeManager & DesignSystem                              │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    COORDINATION LAYER                       │
│  - AppCoordinator (@MainActor ObservableObject)             │
│  - DragSessionManager (Global Drag State Machine)           │
│  - AppEnvironment (Dependency Injection Container)          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   INFRASTRUCTURE LAYER                      │
│  - SQLite Database & Repositories (libsqlite3)              │
│  - LocalFileStorageService (Sandboxed filesystem storage)    │
│  - DragIngestionService & PasteboardExtractor               │
│  - QuickLookThumbnailService & ItemExportService            │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     CORE DOMAIN LAYER                       │
│  - Models: Board (CollectionCategory), CollectionItem       │
│  - Value Objects: ContentType, StorageType, IngestionPayload│
│  - Protocols: CategoryRepositoryProtocol, etc.              │
│  - Utilities: ScreenGeometry, HexColor, KikobarFont, Logger │
└─────────────────────────────────────────────────────────────┘
```

### Component Roles

1. **Core Domain Layer** (`Sources/Kikobar/Core/`):
   - Defines domain models (`CollectionCategory`, `CollectionItem`, `ContentType`, `StorageType`).
   - Declares protocol boundaries (`CategoryRepositoryProtocol`, `CollectionRepositoryProtocol`, `FileStorageServiceProtocol`, `DragIngestionServiceProtocol`, `ThumbnailServiceProtocol`).
   - Contains pure utility helpers: `ScreenGeometry` for coordinate math, `HexColor` for color conversions, `KikobarFont` for font typography, and `AppLogger` for unified OS logging.

2. **Infrastructure Layer** (`Sources/Kikobar/Infrastructure/`):
   - Implements domain protocols using concrete macOS subsystems.
   - `SQLiteDatabase`: Manages database connections, pragmas, prepared statements, and transactions.
   - `SQLiteCategoryRepository` & `SQLiteCollectionRepository`: Execute SQL queries and map SQLite rows to domain structs.
   - `LocalFileStorageService`: Safely persists files into `~/Library/Application Support/com.kikobar.app/Storage/`.
   - `DragIngestionService` & `PasteboardExtractor`: Parses `NSPasteboard` items and normalizes them into `IngestionPayload` records.
   - `ItemExportService`: Generates `NSItemProvider` instances allowing items to be dragged out of Kikobar.

3. **Coordination Layer** (`Sources/Kikobar/Coordination/`):
   - `AppEnvironment`: Factory container providing concrete or mock implementations of all infrastructure protocols.
   - `AppCoordinator`: Central `@MainActor` state machine. Publishes category arrays, item mappings, visibility flags, editing states, and drop queues.
   - `DragSessionManager`: High-frequency cursor and drag tracker managing enter/exit transitions and debounced dismissal timers.

4. **Presentation Layer** (`Sources/Kikobar/Features/`):
   - `CollectionPanelWindow` & `CollectionPanelController`: Custom `NSPanel` hosting the SwiftUI drawer view.
   - `TriggerZoneWindow` & `EdgeHandleWindow`: Edge-docked trigger panels capturing drag hover events.
   - SwiftUI Components: `RightSidebarView`, `BoardCardView`, `BoardMediaGridView`, `BoardColorPickerPopover`, `BoardDeletionDialogView`, and `BottomControlsBar`.

---

## 3. Dependency Injection with `AppEnvironment`

To guarantee modularity and enable simple testing or service swapping, Kikobar decouples all dependencies through `AppEnvironment`:

```swift
public struct AppEnvironment: @unchecked Sendable {
    public let database: SQLiteDatabase
    public let categoryRepository: any CategoryRepositoryProtocol
    public let collectionRepository: any CollectionRepositoryProtocol
    public let fileStorageService: any FileStorageServiceProtocol
    public let dragIngestionService: any DragIngestionServiceProtocol
    public let thumbnailService: any ThumbnailServiceProtocol
    public let themeManager: any ThemeManagerProtocol

    public static func standard() throws -> AppEnvironment {
        let db = try SQLiteDatabase()
        let fileStorage = LocalFileStorageService()
        let categoryRepo = SQLiteCategoryRepository(database: db)
        let collectionRepo = SQLiteCollectionRepository(database: db)
        let dragService = DragIngestionService(fileStorageService: fileStorage)
        let thumbnail = QuickLookThumbnailService()
        let theme = ThemeManager.shared

        return AppEnvironment(
            database: db,
            categoryRepository: categoryRepo,
            collectionRepository: collectionRepo,
            fileStorageService: fileStorage,
            dragIngestionService: dragService,
            thumbnailService: thumbnail,
            themeManager: theme
        )
    }
}
```

Every service adheres to an explicit protocol:
- `CategoryRepositoryProtocol`: Asynchronous CRUD methods for categories/boards (`fetchCategories()`, `createCategory()`, `updateCategory()`, `deleteCategory()`, `toggleExpansion()`).
- `CollectionRepositoryProtocol`: Asynchronous CRUD methods for collection items (`fetchItems(for:)`, `saveItem()`, `deleteItem()`, `deleteItems(forCategory:)`).
- `FileStorageServiceProtocol`: Sandboxed filesystem operations (`storeFile(from:)`, `storeData()`, `deleteFile()`).
- `DragIngestionServiceProtocol`: Raw payload parsing and normalization (`extractPayloads(from:)`, `ingest(payload:into:)`).

---

## 4. Concurrency & Threading Model

Kikobar strictly follows modern Swift Structured Concurrency rules:

1. **`@MainActor` Isolation for All UI & Coordination**:
   - `AppCoordinator`, `DragSessionManager`, `CollectionPanelController`, and all SwiftUI Views are bound to `@MainActor`.
   - Window position adjustments, animations, and state publication (`@Published`) always occur on the main run loop.

2. **Dedicated Serial Queue for SQLite Operations**:
   - SQLite statements execute inside a dedicated serial `DispatchQueue(label: "com.kikobar.database", qos: .userInitiated)`.
   - A `DispatchSpecificKey` is configured to prevent re-entrant deadlocks when transaction blocks execute nested database reads.

3. **Asynchronous Background Processing for File I/O & Thumbnails**:
   - Copying multi-megabyte files, extracting file promises, and rendering QuickLook thumbnails execute on detached or unstructured background tasks (`Task.detached(priority: .userInitiated)`).
   - Once generation is complete, execution hops back to `@MainActor` to update published dictionaries (`itemsByCategory[boardID]`).

---

## 5. Application Lifecycle & Multi-Monitor Coordination

The application entry point is managed by `Sources/Kikobar/App/main.swift` and `AppDelegate.swift`:

```
 [OS Launch: main.swift]
           │
           ▼
 [NSApplication.shared.delegate = AppDelegate()]
           │
           ▼
 [applicationDidFinishLaunching]
   ├── 1. Register custom fonts (Poppins TTF family)
   ├── 2. Initialize AppEnvironment.standard()
   ├── 3. Bootstrap AppCoordinator (load categories from SQLite)
   ├── 4. Set NSApp.setActivationPolicy(.accessory)
   ├── 5. Instantiate CollectionPanelController
   ├── 6. Setup TriggerZoneWindows for all active NSScreen displays
   └── 7. Register NSApplication.didChangeScreenParametersNotification
```

### Dynamic Multi-Display Adaptation

macOS users frequently connect external monitors, detach displays, or rearrange screen arrangements. Kikobar listens to `NSApplication.didChangeScreenParametersNotification`:

```swift
@objc private func screenParametersChanged() {
    AppLogger.ui.info("Screen parameters changed. Rebuilding trigger zones...")
    rebuildTriggerZones()
}
```

When triggered:
1. All existing `TriggerZoneWindow` and `EdgeHandleWindow` instances are closed and deallocated.
2. `NSScreen.screens` is iterated.
3. For each physical screen, a dedicated trigger window is calculated using `ScreenGeometry.triggerFrame(for: screen)` and instantiated.
4. The floating drawer window is recalculated against the currently active screen.

---

Continue to [**Module 02: Window Management & Trigger Mechanics**](02-Window-Management-and-Trigger-Mechanics.md) to explore the low-level AppKit windowing implementation.
