# Module 03: Drag-and-Drop Ingestion & Export Engine

This module explores the core ingestion and export pipelines of Kikobar: parsing complex `NSPasteboard` payloads across macOS applications, handling promised files, automatic board creation on drop, and exporting items back into external workflows.

---

## 1. macOS Pasteboard & Drag System Fundamentals

In macOS, drag-and-drop operations exchange data via `NSPasteboard` instances. An active drag session typically operates on `NSPasteboard(name: .drag)`. If the drag pasteboard is empty or deallocated, Kikobar falls back to `NSPasteboard.general`.

### Pasteboard Type Priority

Applications frequently expose multiple representations of a single dragged object (for example, Safari exports an image as raw TIFF data, a public image URL, an HTML tag, and a plain URL string simultaneously).

Kikobar executes a deterministic **type-resolution hierarchy** via `PasteboardExtractor.swift`:

```
 ┌──────────────────────────────────────────────┐
 │             Incoming NSPasteboard            │
 └──────────────────────┬───────────────────────┘
                        │
       1. Check for File Promises (NSFilePromiseReceiver)
                        ├──────────────────────────► .filePromise(receiver)
                        │
       2. Check for File URLs (.fileURL)
                        ├──────────────────────────► .file(url, isBookmarkable: true)
                        │
       3. Check for Raw Bitmap Images (.tiff, .png)
                        ├──────────────────────────► .image(data, suggestedName)
                        │
       4. Check for Web URLs (.URL)
                        ├──────────────────────────► .url(url, title)
                        │
       5. Check for Plain Text (.string)
                        └──────────────────────────► .text(content, suggestedTitle)
```

---

## 2. Ingestion Payloads & Content Types

The extraction process maps heterogeneous system data into a strongly typed domain enum `IngestionPayload`:

```swift
public enum IngestionPayload: Sendable {
    case file(url: URL, isBookmarkable: Bool)
    case image(data: Data, suggestedName: String?, originalURL: URL?)
    case url(url: URL, title: String?)
    case text(content: String, suggestedTitle: String?)
    case filePromise(receiver: NSFilePromiseReceiver)
}
```

### Content Type Classification (`ContentType.swift`)

Once extracted, items are categorized into one of five standard types:

```swift
public enum ContentType: String, Codable, CaseIterable, Sendable {
    case image
    case document
    case url
    case text
    case genericFile
}
```

Classification relies on Apple's `UniformTypeIdentifiers` (`UTType`):
- `UTType.image` → `.image`
- `UTType.pdf`, `UTType.presentation`, `UTType.spreadsheet`, `UTType.text` → `.document`
- `UTType.url` → `.url`
- Default fallback → `.genericFile`

---

## 3. Deep Dive: Handling Diverse Content Payloads

### A. Finder Files & Directories
When files or directories are dragged from Finder:
1. `PasteboardExtractor` extracts the raw file URL using `pasteboard.readObjects(forClasses: [NSURL.self])`.
2. Paths are resolved using `URL.resolvingSymlinksInPath()`.
3. If sandboxed, a **Security-Scoped Bookmark** is created via `URL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)`.
4. The item is saved with `StorageType.reference`, preserving its live link on the user's filesystem without copying gigabytes of redundant data.

### B. Browser Images (Safari, Google Chrome, Arc)
When dragging an image from the web:
1. Browsers typically provide `.tiff` or `.png` data along with a source URL.
2. If raw image data is present, Kikobar loads it into `NSImage` to validate its bitmap headers.
3. The raw data is compressed into a PNG or JPEG and stored permanently inside Kikobar's managed container (`~/Library/Application Support/com.kikobar.app/Storage/Images/`).
4. The item is saved with `StorageType.managedCopy`, ensuring the image remains accessible even if the browser tab is closed or the remote web server deletes the image.

### C. Web Links & Bookmarks
When a URL string is dragged:
1. The URL is validated against `URL(string:)` with `http` or `https` schemes.
2. Web page titles are parsed from pasteboard metadata (e.g. `public.url-name`) or synthesized from the target domain host.
3. Clicking the item in Kikobar launches the URL in the user's default browser via `NSWorkspace.shared.open(url)`.

### D. Plain Text Snippets
When selecting and dragging text:
1. Kikobar extracts the UTF-8 string content.
2. If content exceeds 50 characters, a truncated preview title is generated (e.g., `"func applicationDidLaunch..."`).
3. The full snippet is saved to a clean `.txt` file inside the local container.

### E. Promised Files (`NSFilePromiseReceiver`)
Some applications (such as Apple Photos, Mail attachments, or Figma) do not provide an immediate file path on drag; instead, they provide an `NSFilePromiseReceiver` that generates the file asynchronously only after a drop is confirmed:

```swift
final class FilePromiseCoordinator: NSObject {
    func receivePromises(
        _ receivers: [NSFilePromiseReceiver],
        destinationURL: URL,
        operationQueue: OperationQueue
    ) async throws -> [URL] {
        return try await withThrowingTaskGroup(of: URL.self) { group in
            for receiver in receivers {
                group.addTask {
                    try await withCheckedThrowingContinuation { continuation in
                        receiver.receivePromisedFiles(
                            atDestination: destinationURL,
                            options: [:],
                            operationQueue: operationQueue
                        ) { fileURL, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: fileURL)
                            }
                        }
                    }
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }
}
```

---

## 4. Automatic Board Creation on Untargeted Drops

A premier feature of Kikobar is **instant, context-preserving board creation**:
If a user drags a file into Kikobar and drops it anywhere into the empty space of the sidebar (rather than hovering over an existing board), Kikobar automatically initiates the Board Creation flow **without losing the dropped file**.

### End-to-End Sequence Diagram

```
User               SwiftUI Sidebar          DragSessionManager       AppCoordinator          SQLite Database
 │                       │                          │                      │                         │
 ├─ Drops file in space ─►                          │                      │                         │
 │                       ├─ onDrop triggered ──────►│                      │                         │
 │                       │                          ├─ itemDroppedWithout- │                         │
 │                       │                          │  Target(pasteboard) ─►                         │
 │                       │                          │                      ├─ Extract payloads       │
 │                       │                          │                      ├─ pendingDropPayloads = p│
 │                       │                          │                      ├─ createNewBoard-        │
 │                       │                          │                      │  Interactive()          │
 │                       │                          │                      ├─ isEditingBoard = true  │
 │                       │◄─ Displays Board Editor ─┼──────────────────────┤                         │
 │                       │   (Name input + colors)  │                      │                         │
 ├─ Enters "Design Assets"                          │                      │                         │
 ├─ Selects Purple Color │                          │                      │                         │
 ├─ Presses Return ──────►                          │                      │                         │
 │                       ├─ commitBoardCreation() ──┼─────────────────────►│                         │
 │                       │                          │                      ├─ updateBoard(name,color)► Writes to DB
 │                       │                          │                      ├─ Ingest pendingDrop-    │
 │                       │                          │                      │  Payloads into boardID ─► Saves Items
 │                       │                          │                      ├─ Expand Board           │
 │                       │                          │                      ├─ Flash Confirmation     │
 │                       │◄─ Board Shown with Items ┼──────────────────────┤                         │
```

### Implementation Details in `AppCoordinator.swift`

```swift
public func handleDropWithoutTarget(pasteboard: NSPasteboard) async {
    do {
        let payloads = try await environment.dragIngestionService.extractPayloads(from: pasteboard)
        guard !payloads.isEmpty else { return }

        // Abort any prior incomplete board creation
        if let existingID = creatingBoardID {
            await cancelBoardCreation(id: existingID)
        }

        // 1. Preserve payload in memory
        self.pendingDropPayloads = payloads

        // 2. Spawn temporary board in editing mode
        _ = await createNewBoardInteractive()
    } catch {
        AppLogger.drag.error("Failed to extract payloads: \(error.localizedDescription)")
    }
}

public func commitBoardCreation(id: UUID, name: String) async {
    guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }

    // 1. Commit board metadata
    var updated = categories[idx]
    updated.name = name
    try? await updateBoard(updated)

    // 2. Consume preserved drop payloads
    let payloads = self.pendingDropPayloads ?? []
    self.pendingDropPayloads = nil
    self.creatingBoardID = nil
    self.isEditingBoard = false

    // 3. Batch ingest items into the newly committed board
    for payload in payloads {
        if let item = try? await environment.dragIngestionService.ingest(payload: payload, into: id) {
            try? await environment.collectionRepository.saveItem(item)
            itemsByCategory[id, default: []].insert(item, at: 0)
            categories[idx].itemCount += 1
        }
    }

    // 4. Automatically expand board and display items
    await expandBoard(id: id)
}
```

If the user hits **Escape** or clicks **Cancel**, `cancelBoardCreation(id:)` is invoked:
- The temporary board record is deleted from SQLite.
- `pendingDropPayloads` is cleared from memory.
- No orphan files or corrupted database records are left behind.

---

## 5. Drag-Out Export Engine (`ItemExportService`)

Collecting content is only half the workflow; users must be able to retrieve and drag collected assets back into other applications:

```swift
@MainActor
public struct ItemExportService {
    public static func itemProvider(for item: CollectionItem) -> NSItemProvider {
        // 1. Finder files or local managed copies
        if let localPath = item.localPath {
            let fileURL = URL(fileURLWithPath: localPath)
            if FileManager.default.fileExists(atPath: localPath) {
                return NSItemProvider(contentsOf: fileURL) ?? fallbackProvider(for: item)
            }
        }

        // 2. Web Links
        if item.contentType == .url, let urlStr = item.sourceURL, let url = URL(string: urlStr) {
            return NSItemProvider(object: url as NSURL)
        }

        // 3. Plain Text Snippets
        if item.contentType == .text, let text = item.textContent {
            return NSItemProvider(object: text as NSString)
        }

        return fallbackProvider(for: item)
    }

    private static func fallbackProvider(for item: CollectionItem) -> NSItemProvider {
        return NSItemProvider(object: item.name as NSString)
    }
}
```

In SwiftUI (`BoardMediaGridView.swift`), media cards attach the export provider using `.onDrag`:

```swift
MediaCardView(item: item)
    .onDrag {
        ItemExportService.itemProvider(for: item)
    }
```

This enables native, high-performance drag-out: dragging an image card directly into an email draft, a Slack message box, or a Finder directory automatically drops the underlying physical file.

---

Continue to [**Module 04: Data Persistence & Storage Architecture**](04-Data-Persistence-and-Storage-Architecture.md) to explore the SQLite database engine and file management system.
