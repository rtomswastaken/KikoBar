# Kikobar Master Technical Wiki & Implementation Blueprint

Welcome to the definitive technical wiki and architecture manual for **Kikobar**, the native macOS drag-and-drop collection utility. 

This multi-part wiki is designed as a standalone engineering manual. Anyone reading this documentation—from independent macOS developers to systems engineers—will understand every layer of Kikobar and be fully equipped to implement, extend, or rebuild the entire application from scratch without guessing.

---

## 📚 Wiki Contents & Navigation

The documentation is organized into six deep-dive technical modules:

| Module | Title | Primary Focus |
| :--- | :--- | :--- |
| [**Module 01**](01-System-Architecture-and-Design-Philosophy.md) | **System Architecture & Design Philosophy** | Zero-permission philosophy, layered architecture, concurrency model (`@MainActor` vs background threads), dependency injection (`AppEnvironment`), and application lifecycle. |
| [**Module 02**](02-Window-Management-and-Trigger-Mechanics.md) | **Window Management & Trigger Mechanics** | Low-level AppKit windowing, non-activating floating `NSPanel`s, screen geometry math across multi-monitor setups, borderless trigger zones, and hover/dismissal state machines. |
| [**Module 03**](03-Drag-and-Drop-Ingestion-and-Export-Engine.md) | **Drag-and-Drop Ingestion & Export Engine** | macOS `NSPasteboard` architecture, multi-type payload decoding (Finder files, web media, text, URLs, promised files), `DragSessionManager` state engine, automatic board creation, and the drag-out export provider. |
| [**Module 04**](04-Data-Persistence-and-Storage-Architecture.md) | **Data Persistence & Storage Architecture** | Direct SQLite C API implementation (`libsqlite3`), WAL journal mode, cascading foreign keys, local file container storage, security-scoped bookmarks, and asynchronous QuickLook thumbnail caching. |
| [**Module 05**](05-User-Interface-and-Design-System.md) | **User Interface & Design System** | Modern macOS design tokens (charcoal & daylight palettes), dynamic Poppins font registration, SwiftUI component hierarchy (`RightSidebarView`, `BoardCardView`, `BoardMediaGridView`), and modal interaction flows. |
| [**Module 06**](06-Step-by-Step-Implementation-Guide.md) | **Step-by-Step Implementation Guide** | The chronological build recipe: project initialization, SPM setup, core protocols, database engine, window controllers, SwiftUI hosting, release packaging (`package_app.sh`), and macOS-specific pitfalls. |

---

## 🎯 Executive Overview of Kikobar

Kikobar solves a fundamental desktop friction problem on macOS: **temporary asset collection and staging**. 

During daily productivity workflows, users constantly gather disparate content—images from Safari, code snippets from Slack, documents from Finder, or links from notes. Traditionally, this results in:
1. Cluttered desktop screens.
2. Disruptive window switching (switching back and forth between full-screen apps and Finder).
3. Lost context and accidental deletions.

Kikobar introduces an **on-demand, edge-anchored collection drawer**:
- **Invisible Proximity Trigger**: Moving any dragged asset towards the screen edge reveals the collection panel without stealing focus from the source app.
- **Dynamic Board Organization**: Assets can be dropped into customized color-coded boards or dropped directly into empty space to generate new boards on the fly.
- **Native macOS Fidelity**: Built with 100% native Apple frameworks (`SwiftUI`, `AppKit`, `QuickLookThumbnailing`, `UniformTypeIdentifiers`, `libsqlite3`) with zero third-party dependencies.
- **Bi-directional Flow**: Items are not just stored; they can be QuickLook-previewed instantly or dragged straight out into any macOS target application.

```
 ┌──────────────────────┐
 │ 1. Drag Any Content  │  (Finder files, browser images, text, links)
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 2. Move to Screen Edge│ (Zero-permission edge trigger detects cursor proximity)
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 3. Drawer Reveals    │  (Floating non-activating NSPanel slides in smoothly)
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 4. Drop into Board   │  (Drop on existing board or empty space to create new)
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 5. Retrieve Anytime  │  (QuickLook preview, drag-out to external apps, copy)
 └──────────────────────┘
```

---

## 🛠 Tech Stack at a Glance

* **Language**: Swift 5.9+ / Swift 6.0
* **UI Framework**: SwiftUI + AppKit (`NSHostingView` bridging)
* **Window Subsystem**: Custom `NSPanel` floating windows (`.nonactivatingPanel`, `.floating` level)
* **Storage Engine**: SQLite 3 with Write-Ahead Logging (WAL) and pure C API bindings
* **File & Preview APIs**: `QuickLook`, `QuickLookThumbnailing`, `UniformTypeIdentifiers`
* **Concurrency**: Swift Structured Concurrency (`async`/`await`, `@MainActor`, `Sendable`)
* **Distribution**: Ad-hoc code-signed standalone application bundle (`Kikobar.app`)

Begin with [**Module 01: System Architecture & Design Philosophy**](01-System-Architecture-and-Design-Philosophy.md) to explore the core architectural foundations.
