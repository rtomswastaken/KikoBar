# Kikobar Architecture & Technical Design

Kikobar is structured as a decoupled, layered native macOS system using **Swift 5.9 / Swift 6**, **AppKit**, **SwiftUI**, and **SQLite**.

The architecture prioritizes testability, clean boundaries, non-blocking asynchronous I/O, and zero intrusive system permissions.

---

## Architectural Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         App Layer                           │
│                (AppDelegate, main.swift)                    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Coordination Layer                      │
│             AppCoordinator  ◄───►  AppEnvironment           │
└───────────────┬───────────────────────────────┬─────────────┘
                │                               │
        ┌───────▼──────────────┐        ┌───────▼─────────────┐
        │  UI & Presentation   │        │     Drag Engine     │
        │ - TriggerZoneWindow  │        │ - DragIngestionSvc  │
        │ - PanelController    │        │ - PasteboardExtract │
        │ - SwiftUI Views      │        │ - FilePromiseCoord  │
        └───────┬──────────────┘        └───────┬─────────────┘
                │                               │
                └───────────────┬───────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                 Storage & Persistence Layer                 │
│  SQLiteDatabase  │  SQLiteRepositories  │  LocalFileStorage │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                         Core Models                         │
│  CollectionItem │ CollectionCategory │ ContentType │ Types  │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Layers and Components

### 1. App & Coordination Layer (`Sources/Kikobar/App`, `Coordination`)
- **`AppDelegate`**: Configures the application as `.accessory` policy (no dock icon, lightweight presence), initializes the dependency container (`AppEnvironment`), monitors display resolution/layout changes, and boots the coordinator.
- **`AppCoordinator`**: Acts as the central state machine and coordinator. Dispatches ingestion requests, updates UI state publishers (`$categories`, `$isPanelVisible`, `$activeHoverCategoryID`), and coordinates dismissal timers.
- **`AppEnvironment`**: Inversion of Control container aggregating service protocols (`DragIngestionServiceProtocol`, `CategoryRepositoryProtocol`, `CollectionRepositoryProtocol`, `FileStorageServiceProtocol`, `ThumbnailServiceProtocol`, `ThemeManagerProtocol`). Allows 100% in-memory mock injection for unit testing.

### 2. Trigger Zone (`Sources/Kikobar/Features/TriggerZone`)
- **`TriggerZoneWindow`**: An invisible, non-activating `NSPanel` (`.nonactivatingPanel`, borderless, transparent, level `.floating`).
- **`TriggerZoneDestinationView`**: Registers for system drag types (`.fileURL`, `.URL`, `.string`, `.tiff`, `.png`). Monitors cursor proximity on drag entry and notifies the coordinator to reveal the collection drawer.
- **`ScreenGeometry`**: Calculates top-right corner coordinates per screen, adapting to menu bar heights and multi-display configurations.

### 3. Collection Panel (`Sources/Kikobar/Features/CollectionPanel`)
- **`CollectionPanelWindow`**: Borderless floating panel configured to display without taking keyboard focus away from underlying windows.
- **`CollectionPanelController`**: Bridges AppKit window management with the root SwiftUI hierarchy.
- **SwiftUI Views**:
  - `PanelContainerView`: Root drawer layout with corner radii, padding, and subtle borders.
  - `CategoryListView` & `CategoryRowView`: Renders categories, counts, and items with accordion expansion.
  - `CategoryDropTargetView`: Provides hover highlight cues and receives the drop payload.
  - `ThemeToggleView` & `ColorPickerHexView`: In-drawer controls for theme switching and color customization.

### 4. Drag & Ingestion Engine (`Sources/Kikobar/Infrastructure/DragEngine`)
- **`DragIngestionService`**: Orchestrates pasteboard inspection and translates raw pasteboard data into typed `IngestionPayload` models.
- **`PasteboardExtractor`**: Detects data types in order of specificity:
  1. Finder files/folders -> Security-scoped bookmarks
  2. Browser bitmaps -> Decoded `NSImage` data
  3. Web links -> URL + Title pair
  4. Plain text -> UTF-8 snippet payload
- **`FilePromiseCoordinator`**: Manages asynchronous `NSFilePromiseReceiver` transactions for dragged items that are created on drop.

### 5. Persistence & Storage (`Sources/Kikobar/Infrastructure/Persistence`, `Storage`)
- **`SQLiteDatabase`**: C-API wrapper for SQLite with foreign keys enabled, WAL journal mode for concurrent read/write safety, and transaction rollback mechanics.
- **`SQLiteCategoryRepository`**: Handles category creation, update, deletion, sorting, and expansion persistence.
- **`SQLiteCollectionRepository`**: Handles item insertion, search queries, categorization, and item relocation.
- **`LocalFileStorageService`**: Persists imported images and snippets into the application support container, preventing disk leaks on item/category deletion.
- **`SecurityScopedBookmarkManager`**: Resolves stale Finder paths and flags missing files gracefully without crashing.

---

## Concurrency and Thread Safety

- **MainActor Boundary**: All AppKit windows, views, and SwiftUI `@Published` states are strictly isolated to `@MainActor`.
- **Background I/O**: File copying, SQLite writes, and QuickLook thumbnail generation occur in asynchronous tasks, ensuring drag interactions remain fluid at 60/120fps.
