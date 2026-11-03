# Kikobar Project Roadmap

This roadmap tracks the development trajectory of Kikobar from initial architecture to the planned 1.0 stable release.

Status milestones are updated strictly upon verified implementation and automated test coverage.

---

## Milestone Progress

| Milestone | Status | Details |
| :--- | :---: | :--- |
| **1. Initial Architecture & Foundation** | **Completed** | Domain model specifications, service protocols, dependency injection container (`AppEnvironment`), and Swift Package structure. |
| **2. Global Drag Detection** | **Completed** | Top-right edge `TriggerZoneWindow`, non-activating window levels, multi-screen geometry adaptation, and drag proximity tracking. |
| **3. File Ingestion Engine** | **Completed** | Pasteboard extraction for Finder files/folders, web images, web URLs, text snippets, and promised files (`NSFilePromiseReceiver`). |
| **4. Collection Drawer UI** | **Completed** | Non-activating floating `CollectionPanelWindow`, SwiftUI drawer views, drop target highlighting, and spring animation transitions. |
| **5. Category Management** | **Completed** | Category creation, editing, deletion, display ordering, HEX accent color customization, and accordion expand/collapse state. |
| **6. Persistent Storage Engine** | **Completed** | SQLite persistence with WAL mode and foreign key cascades, application container file storage, and security-scoped bookmark management. |
| **7. Application Integration** | **Completed** | End-to-end integration via `AppCoordinator` and `AppDelegate`, verified by 42 automated unit and integration tests. |
| **8. Beta Testing Phase** | **In Progress** | Developer testing, performance tuning, real-world drag-and-drop edge case testing, and UI feedback collection. |
| **9. Drag-Out & Export System** | **Planned** | Dragging items from the Kikobar collection drawer directly into external macOS apps. |
| **10. Global Hotkey & Menu Bar Companion** | **Planned** | Keyboard shortcut drawer toggle and optional status bar menu item. |
| **11. Stable 1.0 Release** | **Planned** | Code signing, Apple Notarization, signed DMG builds, and Homebrew Cask distribution. |

---

## Current Focus: Beta Polish

The current beta phase focuses on:
- Validating drag performance across diverse macOS configurations (Sonoma and Sequoia).
- Verifying edge cases with sandboxed browsers (Safari, Chrome, Arc, Brave) and third-party file managers.
- Refining thumbnail caching performance for large media libraries.
- Gathering early community feedback.
