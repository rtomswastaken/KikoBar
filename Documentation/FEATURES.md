# Kikobar Feature Specification

> **Notice**: Kikobar is in **Beta**. This document clearly differentiates implemented capabilities verified by automated test suites from planned features on the roadmap.

---

## Implemented Features (Verified in Beta)

### 1. Zero-Permission Drag Detection
- **Edge Trigger Mechanism**: Invisible, borderless, non-activating `NSPanel` trigger windows positioned along the top-right screen quadrant.
- **Multi-Monitor Support**: Automatically instantiates trigger windows for all attached screens via `NSScreen.screens` and dynamically repositions them upon `NSApplication.didChangeScreenParametersNotification`.
- **Non-Activating Interaction**: Operates as an `.accessory` application policy, ensuring active foreground applications retain keyboard focus while dragging.

### 2. Multi-Type Content Ingestion
- **Finder Files & Directories**: Ingests files and folders from Finder, resolving paths and storing persistent security-scoped bookmarks.
- **Web Images & Browser Media**: Ingests images dragged directly from Safari, Chrome, and Arc, extracting raw bitmap data (`NSImage`) and saving local copies into the app storage container.
- **URLs & Bookmarks**: Captures web links, automatically extracting URL strings and webpage title metadata.
- **Text Snippets**: Accepts dragged text selections, generating structured snippet files stored within the local app sandbox.
- **Promised Files**: Coordinates with `NSFilePromiseReceiver` to extract drag-promised items asynchronously.

### 3. Collection Drawer Interface
- **Floating Panel**: Non-activating, floating window (`NSPanel`) styled with rounded corners and subtle border strokes.
- **Spring Animations**: Native SwiftUI slide-out transition anchored to the top-right edge.
- **Category Drop Targets**: Responsive drop targets with visual targeting cues when hovering over a destination category.
- **Category List & Rows**: Displaying item counts, category color badges, and expanded item lists.

### 4. Custom Categories & Appearance
- **Custom Accent Colors**: Categories support custom colors configured via 3-digit or 6-digit HEX values (e.g., `#8B7CFF`, `#FF5733`).
- **HEX Validation Engine**: Normalizes and sanitizes user input into valid macOS and SwiftUI color models.
- **Theme Engine**: Complete Dark theme (default charcoal `#161618`) and Light theme (`#F7F7F9`) managed via `ThemeManager`.
- **Collapsible States**: Categories can be independently expanded or collapsed, with state persisted across launches.

### 5. Persistent Local Storage
- **SQLite Engine**: High-performance SQLite database operating in Write-Ahead Logging (WAL) mode with foreign key constraints enabled.
- **Cascading Deletion**: Deleting a category automatically cascades to remove associated items and purges unreferenced local files from disk.
- **Managed Container vs Reference Storage**: Differentiates between self-contained local copies (`.managedCopy`, `.appContainer`) and security-scoped references (`.reference`).

### 6. File Previews & Thumbnails
- **QuickLook Integration**: Native macOS QuickLook thumbnail generation for collected files, images, and documents.

---

## Planned Features (Under Development)

The following capabilities are scheduled for subsequent beta and stable milestones:

1. **Drag-Out Export Provider**: Dragging items directly out of the Kikobar drawer into Finder, Mail, Slack, or web forms.
2. **Global Keyboard Shortcut**: Toggle the drawer on-demand without needing an active drag gesture.
3. **Configurable Trigger Zones**: Allow users to configure the trigger location (top-right, top-left, bottom-right, or side notches).
4. **Item Search & Full-Text Indexing**: Rapid search across snippet content, file names, and URL titles within the drawer.
5. **Menu Bar Status Item**: Optional persistent menu bar icon for quick status, settings, and drawer activation.
6. **Batch Operations**: Multi-selection, batch categorization, and one-click zip archiving.
7. **Customizable Hot Corners & Sensitivity**: Adjustable corner threshold dimensions and entry delay timers to avoid accidental triggers.
8. **Automated DMG & Homebrew Cask Packaging**: Signed and notarized distribution pipelines for seamless installation.
