# Kikobar Development Guide

This guide provides instructions for building, running, testing, and debugging Kikobar locally.

---

## Prerequisites

- **macOS**: Sonoma (14.0) or newer
- **Xcode**: 15.0 or newer (or Command Line Tools with Swift 5.9+)
- **Architecture**: Apple Silicon (arm64) or Intel (x86_64)

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/rtomswastaken/KikoBar.git
cd KikoBar
```

### 2. Build the Application

Build the debug executable using Swift Package Manager:

```bash
swift build
```

To build an optimized release binary:

```bash
swift build -c release
```

### 3. Run the Automated Test Suite

Kikobar relies on automated unit and integration tests across data persistence, coordinate tracking, drag extraction, and UI controllers:

```bash
swift test
```

To run a specific test suite or test filter:

```bash
# Run only drag engine tests
swift test --filter "Drag Engine & Ingestion Service Tests"

# Run persistence tests
swift test --filter "SQLite Persistence & Storage Management Tests"
```

---

## Directory Organization

```
Sources/Kikobar/
├── App/                # Main entry point and NSApplicationDelegate
├── Coordination/       # AppCoordinator and AppEnvironment dependency container
├── Core/
│   ├── Models/         # CollectionItem, CollectionCategory, ContentType, etc.
│   ├── Protocols/      # Domain service contracts
│   └── Utilities/      # ScreenGeometry, HexColor, AppLogger
├── Features/
│   ├── Appearance/     # DesignSystem, ThemeManager
│   ├── CollectionPanel/# AppKit window controller and SwiftUI drawer views
│   └── TriggerZone/    # Edge trigger window and proximity view
└── Infrastructure/
    ├── DragEngine/     # Pasteboard extraction and file promise receiver
    ├── Persistence/    # SQLite engine and repository implementations
    ├── Preview/        # QuickLook thumbnail generator
    └── Storage/        # Container file manager and security-scoped bookmarks
```

---

## Engineering Guidelines

### 1. Concurrency and Thread Safety
- Any code interfacing with `AppKit` or `SwiftUI` must be bound to `@MainActor`.
- Storage file writes, SQLite transactions, and QuickLook thumbnail rendering should execute asynchronously on background tasks.

### 2. Dependency Management
- Kikobar strictly maintains zero external package dependencies. All functionality is built on native macOS APIs (`AppKit`, `SwiftUI`, `QuickLookThumbnailing`, `UniformTypeIdentifiers`, `libsqlite3`).

### 3. Unified Logging
- Use `AppLogger` subsystem categories instead of raw `print` statements:
  - `AppLogger.general`
  - `AppLogger.drag`
  - `AppLogger.ui`
  - `AppLogger.persistence`
  - `AppLogger.theme`

Inspect live application logs using macOS Console or the `log` command:

```bash
log stream --predicate 'subsystem == "com.kikobar.app"' --level debug
```

### 4. Memory and Window Management
- Kikobar windows are configured as floating non-activating panels (`.nonactivatingPanel`).
- Never retain views or controllers directly within closure blocks; always use `[weak self]` when binding event streams or notification publishers.
