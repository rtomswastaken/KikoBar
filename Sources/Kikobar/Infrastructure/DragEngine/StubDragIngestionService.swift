import AppKit
import Foundation

/// Stub implementation of DragIngestionServiceProtocol for early integration and testing.
public final class StubDragIngestionService: DragIngestionServiceProtocol, @unchecked Sendable {
    public var supportedPasteboardTypes: [NSPasteboard.PasteboardType] {
        return [
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.data"),
            NSPasteboard.PasteboardType("public.item")
        ]
    }

    public init() {}

    public func canHandle(pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        let supported = Set(supportedPasteboardTypes)
        return !supported.isDisjoint(with: Set(types))
    }

    public func extractPayloads(from pasteboard: NSPasteboard) async throws -> [IngestionPayload] {
        var payloads: [IngestionPayload] = []

        // 1. Check for file URLs (Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                let payload = IngestionPayload(
                    suggestedName: url.lastPathComponent,
                    contentType: ContentType.from(url: url),
                    storageType: .reference,
                    sourceURL: url,
                    localFileURL: url
                )
                payloads.append(payload)
            }
            return payloads
        }

        // 2. Check for plain URLs (Web links)
        if let string = pasteboard.string(forType: .URL), let url = URL(string: string) {
            let payload = IngestionPayload(
                suggestedName: url.host ?? "Web Link",
                contentType: .url,
                storageType: .link,
                sourceURL: url
            )
            payloads.append(payload)
            return payloads
        }

        // 3. Check for text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let snippet = text.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
            let payload = IngestionPayload(
                suggestedName: snippet.isEmpty ? "Snippet" : String(snippet),
                contentType: .text,
                storageType: .text,
                textContent: text
            )
            payloads.append(payload)
            return payloads
        }

        return payloads
    }

    public func ingest(payload: IngestionPayload, into categoryID: UUID) async throws -> CollectionItem {
        return CollectionItem(
            id: UUID(),
            name: payload.suggestedName,
            categoryID: categoryID,
            contentType: payload.contentType,
            storageType: payload.storageType,
            sourceURL: payload.sourceURL,
            localPath: payload.localFileURL?.path,
            bookmarkData: payload.bookmarkData,
            textContent: payload.textContent,
            thumbnailPath: nil,
            fileSize: nil,
            uniformTypeIdentifier: payload.uniformTypeIdentifier,
            dateAdded: Date(),
            isSourceAvailable: true
        )
    }
}
