<p align="center">
  <img src="Assets/Logo/kikobar-logo.png" alt="Kikobar Logo" width="140" />
</p>

<h1 align="center">Kikobar</h1>

<p align="center">
  <strong>Your digital collection drawer.</strong><br>
  A simple way to collect anything from anywhere on your Mac.
</p>

<p align="center">
  <code>BETA</code> &nbsp;•&nbsp; <code>macOS 14+</code> &nbsp;•&nbsp; <code>Swift</code> &nbsp;•&nbsp; <code>Native</code>
</p>

---

## What is Kikobar?

Kikobar is a native macOS drag-and-drop collection utility. It allows you to collect files, images, documents, URLs, text snippets, and other content from anywhere on your Mac without interrupting your current workflow.

Instead of keeping messy piles of temporary files on your desktop or switching back and forth between Finder windows, Kikobar provides an on-demand floating collection drawer that stays tucked away until you need it.

> **Current Status: Beta**  
> Kikobar is currently in active beta development. Core drag ingestion, trigger mechanics, category organization, and local persistence are functional and verified by tests. User interface details and features are continuing to evolve.

---

## How It Works

1. **Drag anything from your screen** — Select files from Finder, an image or link from your browser, or text from any editor.
2. **Move it towards the top-right corner** — Move the dragged item toward the top-right corner of your screen.
3. **Kikobar reveals its collection drawer** — The trigger zone detects proximity and smoothly slides out the floating collection drawer.
4. **Drop the item into a category** — Hover over any color-coded category drop target and release the item.
5. **Access your collection whenever you need it** — Retrieve saved items, view QuickLook previews, or inspect your organized content at any time.

---

## Features

### Currently Implemented (Beta)

- **Zero-Permission Edge Detection**: Lightweight, borderless `NSPanel` trigger zones positioned at the top-right screen quadrant, with automatic multi-monitor recalculation.
- **Universal Drag Ingestion Engine**:
  - Finder files and folders with security-scoped bookmark persistence.
  - Browser images with direct bitmap extraction (`NSImage`) stored safely in the application container.
  - Web links with automatic title and URL metadata extraction.
  - Plain text snippets persisted into isolated container text files.
  - Promised file drag support via `NSFilePromiseReceiver`.
- **Floating Collection Drawer**: Non-activating, floating window architecture powered by AppKit and SwiftUI with fluid slide-in transitions.
- **Custom Categories**: Create, rename, delete, and reorder categories.
- **Custom Accent Colors**: Color categories with custom HEX values, featuring built-in HEX sanitization, normalization, and palette validation.
- **Collapsible Categories**: Expand and collapse individual categories with persisted state.
- **Dark and Light Themes**: Native theme system with a dark charcoal default (`#161618`) and clean light mode (`#F7F7F9`).
- **Persistent Local Storage**: Thread-safe SQLite database running with Write-Ahead Logging (WAL) and foreign-key cascading deletes.
- **File Previews & Thumbnails**: Integrated macOS QuickLook thumbnail generation for images, documents, and files.

### Planned Features

- **Drag-Out Export**: Dragging collected items directly from the Kikobar drawer into external applications, emails, or Finder folders.
- **Global Hotkey Toggle**: Open or close the collection drawer with a customizable keyboard shortcut without requiring an active drag gesture.
- **Configurable Trigger Zones**: Support for alternative trigger positions (top-left, bottom-right, or notch integration).
- **Search and Filtering**: In-drawer search across snippet text, document titles, and URLs.
- **Menu Bar Companion**: Optional menu bar status item for fast access and configuration.
- **Batch Exporting**: Select multiple items and export or compress them into an archive in one click.

---

## Technology

Kikobar is built with zero third-party dependencies, relying entirely on native Apple frameworks:

- **Swift 5.9+ / Swift 6** — Modern concurrency with `@MainActor` isolation and asynchronous task handling.
- **SwiftUI** — Declarative views for collection drawers, category lists, color pickers, and theme controls.
- **AppKit** — Low-level window management, non-activating floating panels, screen geometry tracking, and pasteboard extraction.
- **SQLite (libsqlite3)** — Fast, lightweight local database with WAL mode and foreign-key constraints.
- **QuickLookThumbnailing** — High-fidelity asynchronous preview generation.
- **UniformTypeIdentifiers** — Strict content type classification.

---

## Roadmap

| Milestone | Status |
| :--- | :---: |
| Initial architecture and project foundation | Completed |
| Global drag detection | Completed |
| File ingestion engine | Completed |
| Collection drawer UI | Completed |
| Category management | Completed |
| Persistent storage | Completed |
| Application integration | Completed |
| Beta testing | In Progress |
| Drag-out export system | Planned |
| Global hotkey and menu bar companion | Planned |
| Stable 1.0 release | Planned |

---

## Development Status

Kikobar is currently in active beta. Features, layout, and internal APIs may change as we refine the user experience and incorporate feedback. 

If you encounter unexpected behavior, edge cases with specific file types, or have suggestions for improvements, please report them through the issue tracker.

---

## Screenshots

Screenshots and interface captures will be added here as the beta user interface finalizes.

---

## Building and Testing

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ or Swift 5.9+ Command Line Tools

### Build

```bash
# Clone the repository
git clone https://github.com/rtomswastaken/KikoBar.git
cd KikoBar

# Build debug executable
swift build

# Build optimized release executable
swift build -c release
```

### Run Tests

Kikobar has an automated test suite covering models, drag extraction, persistence, and UI controllers:

```bash
swift test
```

---

## Feedback and Contributions

Contributions, bug reports, and suggestions are welcome:

- **Report Bugs**: If you find an issue, submit a report using the [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.md).
- **Request Features**: Share your ideas using the [Feature Request Template](.github/ISSUE_TEMPLATE/feature_request.md).
- **Code Contributions**: Review [CONTRIBUTING.md](CONTRIBUTING.md) for architectural guidelines, code standards, and the pull request workflow.
- **Code of Conduct**: All participants must follow our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Documentation

For in-depth details on design and architecture, consult the documentation directory:

- [Product Overview](Documentation/PRODUCT_OVERVIEW.md)
- [Feature Specification](Documentation/FEATURES.md)
- [Architecture & Technical Design](Documentation/ARCHITECTURE.md)
- [Project Roadmap](Documentation/ROADMAP.md)
- [Development Guide](Documentation/DEVELOPMENT.md)

---

## License

This project is licensed under the [MIT License](LICENSE).
