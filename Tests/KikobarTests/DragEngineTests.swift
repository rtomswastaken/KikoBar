import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Kikobar

@Suite("Drag Engine & Ingestion Service Tests")
struct DragEngineTests {

    private func createTestService() -> (DragIngestionService, InMemoryFileStorageService) {
        let storage = InMemoryFileStorageService()
        let service = DragIngestionService(fileStorageService: storage)
        return (service, storage)
    }

    // MARK: - 1. Finder Files & Folders

    @Test("Extracts and ingests local files from Finder as reference items")
    func finderFileIngestion() async throws {
        let (service, _) = createTestService()

        // Create temporary test file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("contract.pdf")
        let dummyData = "Mock PDF Content for Testing".data(using: .utf8)!
        try dummyData.write(to: sampleFile)

        // Populate pasteboard
        let pboard = NSPasteboard.withUniqueName()
        pboard.writeObjects([sampleFile as NSURL])

        // Verify canHandle
        #expect(service.canHandle(pasteboard: pboard) == true)

        // Extract payloads
        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 1)

        let payload = try #require(payloads.first)
        #expect(payload.suggestedName == "contract.pdf")
        #expect(payload.contentType == .document)
        #expect(payload.storageType == .reference)
        #expect(payload.localFileURL?.path == sampleFile.path)
        #expect(payload.bookmarkData != nil)
        #expect(payload.uniformTypeIdentifier == UTType.pdf.identifier)

        // Ingest into category
        let categoryID = UUID()
        let item = try await service.ingest(payload: payload, into: categoryID)
        #expect(item.name == "contract.pdf")
        #expect(item.categoryID == categoryID)
        #expect(item.contentType == .document)
        #expect(item.storageType == .reference)
        #expect(item.localPath == sampleFile.path)
        #expect(item.bookmarkData != nil)
        #expect(item.fileSize == Int64(dummyData.count))
        #expect(item.isSourceAvailable == true)
    }

    @Test("Extracts and ingests Finder folders accurately")
    func finderFolderIngestion() async throws {
        let (service, _) = createTestService()

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectAssets_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let pboard = NSPasteboard.withUniqueName()
        pboard.writeObjects([folder as NSURL])

        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 1)

        let payload = try #require(payloads.first)
        #expect(payload.contentType == .folder)
        #expect(payload.storageType == .reference)

        let item = try await service.ingest(payload: payload, into: UUID())
        #expect(item.contentType == .folder)
        #expect(item.storageType == .reference)
        #expect(item.localPath == folder.path)
    }

    @Test("Extracts multiple Finder files dropped together")
    func multiFileIngestion() async throws {
        let (service, _) = createTestService()

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileA = tempDir.appendingPathComponent("imageA.png")
        let fileB = tempDir.appendingPathComponent("songB.mp3")
        try "dummy1".data(using: .utf8)!.write(to: fileA)
        try "dummy2".data(using: .utf8)!.write(to: fileB)

        let pboard = NSPasteboard.withUniqueName()
        pboard.writeObjects([fileA as NSURL, fileB as NSURL])

        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 2)

        let names = payloads.map { $0.suggestedName }
        #expect(names.contains("imageA.png"))
        #expect(names.contains("songB.mp3"))

        let categoryID = UUID()
        let items = try await withThrowingTaskGroup(of: CollectionItem.self) { group in
            for payload in payloads {
                group.addTask { try await service.ingest(payload: payload, into: categoryID) }
            }
            var results: [CollectionItem] = []
            for try await item in group {
                results.append(item)
            }
            return results
        }
        #expect(items.count == 2)
    }

    // MARK: - 2. Web Browser Images

    @Test("Extracts browser raw image data and ingests as imported item")
    func browserRawImageDataIngestion() async throws {
        let (service, _) = createTestService()

        // Create 1x1 PNG image data
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )
        let pngData = try #require(bitmap?.representation(using: .png, properties: [:]))

        let pboard = NSPasteboard.withUniqueName()
        pboard.declareTypes([.png, .URL], owner: nil)
        pboard.setData(pngData, forType: .png)
        pboard.setString("https://example.com/assets/banner.png", forType: .URL)

        #expect(service.canHandle(pasteboard: pboard) == true)

        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 1)

        let payload = try #require(payloads.first)
        #expect(payload.contentType == .image)
        #expect(payload.storageType == .imported)
        #expect(payload.rawData == pngData)
        #expect(payload.suggestedName == "banner.png")
        #expect(payload.uniformTypeIdentifier == UTType.png.identifier)

        let categoryID = UUID()
        let item = try await service.ingest(payload: payload, into: categoryID)
        #expect(item.name == "banner.png")
        #expect(item.contentType == .image)
        #expect(item.storageType == .imported)
        #expect(item.localPath != nil)
        #expect(item.fileSize == Int64(pngData.count))
    }

    // MARK: - 3. Web URLs & Links

    @Test("Extracts and ingests web links with title metadata")
    func webLinkIngestion() async throws {
        let (service, _) = createTestService()

        let pboard = NSPasteboard.withUniqueName()
        pboard.declareTypes([.URL, NSPasteboard.PasteboardType("public.url-name")], owner: nil)
        pboard.setString("https://developer.apple.com/documentation", forType: .URL)
        pboard.setString("Apple Developer Documentation", forType: NSPasteboard.PasteboardType("public.url-name"))

        #expect(service.canHandle(pasteboard: pboard) == true)

        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 1)

        let payload = try #require(payloads.first)
        #expect(payload.suggestedName == "Apple Developer Documentation")
        #expect(payload.contentType == .url)
        #expect(payload.storageType == .link)
        #expect(payload.sourceURL?.absoluteString == "https://developer.apple.com/documentation")

        let categoryID = UUID()
        let item = try await service.ingest(payload: payload, into: categoryID)
        #expect(item.name == "Apple Developer Documentation")
        #expect(item.contentType == .url)
        #expect(item.storageType == .link)
        #expect(item.sourceURL?.absoluteString == "https://developer.apple.com/documentation")
        #expect(item.localPath == nil)
    }

    // MARK: - 4. Text Snippets & Clippings

    @Test("Extracts and ingests plain text snippets into storage")
    func textSnippetIngestion() async throws {
        let (service, _) = createTestService()

        let rawSnippet = """
        let greeting = "Hello, Kikobar!"
        print(greeting)
        """

        let pboard = NSPasteboard.withUniqueName()
        pboard.declareTypes([.string], owner: nil)
        pboard.setString(rawSnippet, forType: .string)

        #expect(service.canHandle(pasteboard: pboard) == true)

        let payloads = try await service.extractPayloads(from: pboard)
        #expect(payloads.count == 1)

        let payload = try #require(payloads.first)
        #expect(payload.contentType == .text)
        #expect(payload.storageType == .text)
        #expect(payload.suggestedName == "let greeting = \"Hello, Kikobar!\"")
        #expect(payload.textContent == rawSnippet)

        let categoryID = UUID()
        let item = try await service.ingest(payload: payload, into: categoryID)
        #expect(item.contentType == .text)
        #expect(item.storageType == .text)
        #expect(item.textContent == rawSnippet)
        #expect(item.localPath != nil)
        #expect(item.fileSize == Int64(rawSnippet.utf8.count))
    }

    // MARK: - 5. File Promise Coordinator

    @Test("FilePromiseCoordinator detects promised file types accurately")
    func filePromiseCoordinatorDetection() {
        let coordinator = FilePromiseCoordinator()

        let pboard = NSPasteboard.withUniqueName()
        #expect(coordinator.containsFilePromises(in: pboard) == false)

        pboard.declareTypes([NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")], owner: nil)
        #expect(coordinator.containsFilePromises(in: pboard) == true)
    }

    // MARK: - 6. TriggerZone Window & DestinationView

    @Test("TriggerZoneWindow initializes with correct styles and non-activating masks")
    @MainActor
    func triggerZoneWindowSetup() {
        let frame = NSRect(x: 100, y: 100, width: 20, height: 300)
        let window = TriggerZoneWindow(contentRect: frame)

        #expect(window.level == .floating)
        #expect(window.isOpaque == false)
        #expect(window.backgroundColor == .clear)
        #expect(window.hasShadow == false)
        #expect(window.canBecomeKey == false)
        #expect(window.canBecomeMain == false)
    }

    @Test("TriggerZoneWindow factory creates windows for all active screens")
    @MainActor
    func triggerZoneWindowMultiMonitorFactory() {
        var enteredCount = 0
        let windows = TriggerZoneWindow.createWindows(
            for: NSScreen.screens,
            onDragEntered: { _ in enteredCount += 1 }
        )

        #expect(windows.count == NSScreen.screens.count)
        for win in windows {
            #expect(win.contentView is TriggerZoneDestinationView)
            win.close()
        }
    }

    @Test("TriggerZoneDestinationView updates proximity and dispatches lifecycle events")
    @MainActor
    func triggerZoneDestinationViewEvents() {
        let frame = NSRect(x: 0, y: 0, width: 20, height: 300)
        let view = TriggerZoneDestinationView(frame: frame)

        var enteredScreenName: String? = nil
        var updatedProximity: CGFloat? = nil

        view.onDragEntered = { screen in
            enteredScreenName = screen.localizedName
        }
        view.onDragUpdated = { _, _, proximity in
            updatedProximity = proximity
        }

        #expect(view.isDragActive == false)
        #expect(view.currentProximity == 0.0)

        // Mock dragging info
        final class MockDraggingInfo: NSObject, NSDraggingInfo {
            var draggingPasteboard: NSPasteboard = NSPasteboard.withUniqueName()
            var draggingLocation: NSPoint = NSPoint(x: 15, y: 150)
            var draggingDestinationWindow: NSWindow? = nil
            var draggingSourceOperationMask: NSDragOperation = .copy
            var draggedImageLocation: NSPoint = .zero
            var draggedImage: NSImage? = nil
            var draggingSource: Any? = nil
            var draggingSequenceNumber: Int = 1
            var numberOfValidItemsForDrop: Int = 1
            var animatesToDestination: Bool = false
            var draggingFormation: NSDraggingFormation = .default
            var springLoadingHighlight: NSSpringLoadingHighlight = .none
            func slideDraggedImage(to screenPoint: NSPoint) {}
            func resetSpringLoading() {}
            func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
        }

        let mockInfo = MockDraggingInfo()

        // 1. Drag entered
        let op = view.draggingEntered(mockInfo)
        #expect(op == .copy)
        #expect(view.isDragActive == true)
        #expect(enteredScreenName != nil)

        // 2. Drag updated (proximity calculation: 15 / 20 = 0.75)
        _ = view.draggingUpdated(mockInfo)
        #expect(view.currentProximity == 0.75)
        #expect(updatedProximity == 0.75)

        // 3. Drag ended
        view.draggingEnded(mockInfo)
        #expect(view.isDragActive == false)
        #expect(view.currentProximity == 0.0)
    }

    // MARK: - 7. Empty & Unsupported Pasteboard

    @Test("Gracefully handles empty or unsupported pasteboards")
    func emptyPasteboardHandling() async throws {
        let (service, _) = createTestService()

        let emptyPboard = NSPasteboard.withUniqueName()
        #expect(service.canHandle(pasteboard: emptyPboard) == false)

        let payloads = try await service.extractPayloads(from: emptyPboard)
        #expect(payloads.isEmpty)
    }
}
