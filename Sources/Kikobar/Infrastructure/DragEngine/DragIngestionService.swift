import AppKit
import Foundation
import UniformTypeIdentifiers

/// Production implementation of DragIngestionServiceProtocol.
/// Orchestrates pasteboard inspection, extraction, file promises, and persistent ingestion.
public final class DragIngestionService: DragIngestionServiceProtocol, @unchecked Sendable {
    public let fileStorageService: FileStorageServiceProtocol
    public let extractor: PasteboardExtractor
    public let promiseCoordinator: FilePromiseCoordinator

    public static var defaultSupportedPasteboardTypes: [NSPasteboard.PasteboardType] {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            .string,
            .rtf,
            .html,
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.webp"),
            NSPasteboard.PasteboardType("com.apple.webarchive"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-content-type"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.data"),
            NSPasteboard.PasteboardType("public.item")
        ]
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        types.append(contentsOf: promiseTypes)
        return types
    }

    public var supportedPasteboardTypes: [NSPasteboard.PasteboardType] {
        Self.defaultSupportedPasteboardTypes
    }

    public init(
        fileStorageService: FileStorageServiceProtocol = LocalFileStorageService(),
        promiseCoordinator: FilePromiseCoordinator = FilePromiseCoordinator()
    ) {
        self.fileStorageService = fileStorageService
        self.promiseCoordinator = promiseCoordinator
        self.extractor = PasteboardExtractor(
            fileStorageService: fileStorageService,
            promiseCoordinator: promiseCoordinator
        )
    }

    public func canHandle(pasteboard: NSPasteboard) -> Bool {
        extractor.canHandle(pasteboard: pasteboard, supportedTypes: supportedPasteboardTypes)
    }

    public func extractPayloads(from pasteboard: NSPasteboard) async throws -> [IngestionPayload] {
        AppLogger.drag.debug("Extracting drag payloads from pasteboard...")
        let payloads = try await extractor.extractPayloads(from: pasteboard)
        AppLogger.drag.info("Extracted \(payloads.count) payload(s) from pasteboard.")
        return payloads
    }

    public func ingest(payload: IngestionPayload, into categoryID: UUID) async throws -> CollectionItem {
        AppLogger.drag.info("Ingesting payload '\(payload.suggestedName)' of type \(payload.contentType.rawValue) into category \(categoryID.uuidString)")

        var finalLocalPath: String? = nil
        var finalBookmarkData: Data? = payload.bookmarkData
        var finalFileSize: Int64? = nil
        var isAvailable: Bool = true

        switch payload.storageType {
        case .reference:
            if let fileURL = payload.localFileURL {
                finalLocalPath = fileURL.path
                if finalBookmarkData == nil {
                    finalBookmarkData = try? fileStorageService.createSecurityScopedBookmark(for: fileURL)
                }
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    finalFileSize = size
                }
                isAvailable = fileStorageService.verifySourceAvailability(at: fileURL.path)
            }

        case .imported:
            if let tempURL = payload.localFileURL {
                let importedURL = try fileStorageService.importFile(from: tempURL, categoryID: categoryID)
                finalLocalPath = importedURL.path
                if let attrs = try? FileManager.default.attributesOfItem(atPath: importedURL.path),
                   let size = attrs[.size] as? Int64 {
                    finalFileSize = size
                }
                // Attempt cleanup of temp staged file if distinct from imported path
                if tempURL.path != importedURL.path {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } else if let rawData = payload.rawData {
                let importedURL = try fileStorageService.importData(rawData, filename: payload.suggestedName, categoryID: categoryID)
                finalLocalPath = importedURL.path
                finalFileSize = Int64(rawData.count)
            }

        case .link:
            finalLocalPath = nil
            finalFileSize = nil

        case .text:
            if let text = payload.textContent {
                let snippetURL = try? fileStorageService.saveSnippet(text, title: payload.suggestedName, categoryID: categoryID)
                finalLocalPath = snippetURL?.path
                finalFileSize = Int64(text.utf8.count)
            }
        }

        let item = CollectionItem(
            id: UUID(),
            name: payload.suggestedName,
            categoryID: categoryID,
            contentType: payload.contentType,
            storageType: payload.storageType,
            sourceURL: payload.sourceURL ?? (payload.storageType == .reference ? payload.localFileURL : nil),
            localPath: finalLocalPath,
            bookmarkData: finalBookmarkData,
            textContent: payload.textContent,
            thumbnailPath: nil,
            fileSize: finalFileSize,
            uniformTypeIdentifier: payload.uniformTypeIdentifier,
            dateAdded: Date(),
            isSourceAvailable: isAvailable
        )

        return item
    }
}
