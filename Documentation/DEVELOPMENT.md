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

### 3. Package the macOS Application (.app)

To assemble the complete native `Kikobar.app` bundle and generate the distribution archive:

```bash
./scripts/package_app.sh
```

This compiles an optimized release binary, embeds the official application icon (`AppIcon.icns`) and custom fonts (`Poppins`), applies ad-hoc code signing, and outputs the installable application to `build/Kikobar.app` as well as `Releases/Kikobar-v0.1.0-alpha.zip`.

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
