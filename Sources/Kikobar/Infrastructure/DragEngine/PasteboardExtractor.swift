import AppKit
import Foundation
import UniformTypeIdentifiers

/// Extracts transient IngestionPayloads from an NSPasteboard session.
public final class PasteboardExtractor: @unchecked Sendable {
    private let fileStorageService: FileStorageServiceProtocol
    private let promiseCoordinator: FilePromiseCoordinator
    private let temporaryDirectory: URL

    public init(
        fileStorageService: FileStorageServiceProtocol,
        promiseCoordinator: FilePromiseCoordinator = FilePromiseCoordinator(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("KikobarPromises", isDirectory: true)
    ) {
        self.fileStorageService = fileStorageService
        self.promiseCoordinator = promiseCoordinator
        self.temporaryDirectory = temporaryDirectory
    }

    /// Evaluates if the pasteboard contains any supported content.
    public func canHandle(pasteboard: NSPasteboard, supportedTypes: [NSPasteboard.PasteboardType]) -> Bool {
        if promiseCoordinator.containsFilePromises(in: pasteboard) {
            return true
        }

        guard let types = pasteboard.types, !types.isEmpty else {
            return false
        }

        let supportedSet = Set(supportedTypes)
        if !supportedSet.isDisjoint(with: Set(types)) {
            return true
        }

        if pasteboard.canReadObject(forClasses: [NSURL.self, NSString.self, NSImage.self], options: nil) {
            return true
        }

        return false
    }

    /// Extracts all payloads from the pasteboard.
    public func extractPayloads(from pasteboard: NSPasteboard) async throws -> [IngestionPayload] {
        // Priority 1: Asynchronous Browser File Promises (NSFilePromiseReceiver)
        let receivers = promiseCoordinator.filePromiseReceivers(from: pasteboard)
        if !receivers.isEmpty {
            let sessionFolder = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let promisedURLs = try await promiseCoordinator.receivePromisedFiles(
                receivers: receivers,
                destinationDirectory: sessionFolder
            )

            var payloads: [IngestionPayload] = []
            for url in promisedURLs {
                let uti = UTType(filenameExtension: url.pathExtension)?.identifier
                let payload = IngestionPayload(
                    suggestedName: url.lastPathComponent,
                    contentType: ContentType.from(url: url),
                    storageType: .imported,
                    sourceURL: nil,
                    localFileURL: url,
                    rawData: nil,
                    textContent: nil,
                    uniformTypeIdentifier: uti,
                    bookmarkData: nil
                )
                payloads.append(payload)
            }
            if !payloads.isEmpty {
                return payloads
            }
        }

        // Check if there are multiple pasteboard items
        if let items = pasteboard.pasteboardItems, items.count > 1 {
            var itemPayloads: [IngestionPayload] = []
            for item in items {
                if let payload = extractPayload(from: item) {
                    itemPayloads.append(payload)
                }
            }
            if !itemPayloads.isEmpty {
                return itemPayloads
            }
        }

        // Priority 2: Finder Files and Directories (file-url)
        let fileURLs = extractFileURLs(from: pasteboard)
        if !fileURLs.isEmpty {
            var payloads: [IngestionPayload] = []
            for url in fileURLs {
                let name = url.lastPathComponent.isEmpty ? "File" : url.lastPathComponent
                let uti: String? = {
                    if let rv = try? url.resourceValues(forKeys: [.contentTypeKey]), let ct = rv.contentType {
                        return ct.identifier
                    }
                    return UTType(filenameExtension: url.pathExtension)?.identifier
                }()
                let bookmark = try? fileStorageService.createSecurityScopedBookmark(for: url)

                let payload = IngestionPayload(
                    suggestedName: name,
                    contentType: ContentType.from(url: url),
                    storageType: .reference,
                    sourceURL: url,
                    localFileURL: url,
                    rawData: nil,
                    textContent: nil,
                    uniformTypeIdentifier: uti,
                    bookmarkData: bookmark
                )
                payloads.append(payload)
            }
            return payloads
        }

        // Priority 3: Web Browser Raw Images (PNG, JPEG, WebP, GIF, TIFF, WebArchive)
        if let imagePayload = extractRawImageData(from: pasteboard) {
            return [imagePayload]
        }

        // Priority 4: Web Links / URLs
        let webURLs = extractWebURLs(from: pasteboard)
        if !webURLs.isEmpty {
            var payloads: [IngestionPayload] = []
            let urlTitle = pasteboard.string(forType: NSPasteboard.PasteboardType("public.url-name"))
            for url in webURLs {
                let suggested = urlTitle ?? url.host ?? (url.lastPathComponent.isEmpty ? "Web Link" : url.lastPathComponent)
                let payload = IngestionPayload(
                    suggestedName: suggested,
                    contentType: .url,
                    storageType: .link,
                    sourceURL: url,
                    localFileURL: nil,
                    rawData: nil,
                    textContent: nil,
                    uniformTypeIdentifier: UTType.url.identifier,
                    bookmarkData: nil
                )
                payloads.append(payload)
            }
            return payloads
        }

        // Priority 5: Text Snippets & Code Clippings
        if let textPayload = extractTextSnippet(from: pasteboard) {
            return [textPayload]
        }

        return []
    }

    // MARK: - Private Extraction Helpers

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var result: [URL] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            result = urls.filter { $0.isFileURL }
        }

        if result.isEmpty, let singleURLString = pasteboard.string(forType: .fileURL), let url = URL(string: singleURLString), url.isFileURL {
            result = [url]
        }

        if result.isEmpty, let fileList = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            result = fileList.map { URL(fileURLWithPath: $0) }
        }

        return result
    }

    private func extractWebURLs(from pasteboard: NSPasteboard) -> [URL] {
        var result: [URL] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            result = urls.filter { !$0.isFileURL && ($0.scheme == "http" || $0.scheme == "https" || $0.scheme == "ftp") }
        }

        if result.isEmpty, let urlString = pasteboard.string(forType: .URL), let url = URL(string: urlString), !url.isFileURL {
            result = [url]
        }

        return result
    }

    private func extractRawImageData(from pasteboard: NSPasteboard) -> IngestionPayload? {
        let imageTypeSpecs: [(type: NSPasteboard.PasteboardType, uti: String, ext: String)] = [
            (.png, UTType.png.identifier, "png"),
            (NSPasteboard.PasteboardType("public.jpeg"), UTType.jpeg.identifier, "jpg"),
            (NSPasteboard.PasteboardType("public.webp"), "org.webmproject.webp", "webp"),
            (NSPasteboard.PasteboardType("com.compuserve.gif"), UTType.gif.identifier, "gif"),
            (.tiff, UTType.tiff.identifier, "tiff"),
            (NSPasteboard.PasteboardType("com.apple.webarchive"), "com.apple.webarchive", "webarchive")
        ]

        var candidateData: Data?
        var matchedUTI: String?
        var matchedExt: String = "png"

        for spec in imageTypeSpecs {
            if let data = pasteboard.data(forType: spec.type), !data.isEmpty {
                candidateData = data
                matchedUTI = spec.uti
                matchedExt = spec.ext
                break
            }
        }

        // If no direct data found, check NSImage reading
        if candidateData == nil, let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            candidateData = tiff
            matchedUTI = UTType.tiff.identifier
            matchedExt = "tiff"
        }

        guard let data = candidateData, let uti = matchedUTI else {
            return nil
        }

        // Determine source URL and suggested name
        var sourceURL: URL?
        if let urlString = pasteboard.string(forType: .URL), let parsed = URL(string: urlString), !parsed.isFileURL {
            sourceURL = parsed
        }

        let name: String
        if let src = sourceURL, !src.lastPathComponent.isEmpty, UTType(filenameExtension: src.pathExtension)?.conforms(to: .image) == true {
            name = src.lastPathComponent
        } else {
            let timestamp = Int(Date().timeIntervalSince1970)
            name = "Dropped-Image-\(timestamp).\(matchedExt)"
        }

        return IngestionPayload(
            suggestedName: name,
            contentType: uti == "com.apple.webarchive" ? .other : .image,
            storageType: .imported,
            sourceURL: sourceURL,
            localFileURL: nil,
            rawData: data,
            textContent: nil,
            uniformTypeIdentifier: uti,
            bookmarkData: nil
        )
    }

    private func extractTextSnippet(from pasteboard: NSPasteboard) -> IngestionPayload? {
        guard let text = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .rtf) else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let firstLine = trimmed.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Snippet"
        let truncated = String(firstLine.prefix(32)).trimmingCharacters(in: .whitespaces)
        let suggestedName = truncated.isEmpty ? "Snippet" : (firstLine.count > 32 ? "\(truncated)..." : truncated)

        return IngestionPayload(
            suggestedName: suggestedName,
            contentType: .text,
            storageType: .text,
            sourceURL: nil,
            localFileURL: nil,
            rawData: nil,
            textContent: text,
            uniformTypeIdentifier: UTType.plainText.identifier,
            bookmarkData: nil
        )
    }

    private func extractPayload(from item: NSPasteboardItem) -> IngestionPayload? {
        // 1. File URL
        if let fileURLString = item.string(forType: .fileURL), let url = URL(string: fileURLString), url.isFileURL {
            let uti = UTType(filenameExtension: url.pathExtension)?.identifier
            let bookmark = try? fileStorageService.createSecurityScopedBookmark(for: url)
            return IngestionPayload(
                suggestedName: url.lastPathComponent,
                contentType: ContentType.from(url: url),
                storageType: .reference,
                sourceURL: url,
                localFileURL: url,
                rawData: nil,
                textContent: nil,
                uniformTypeIdentifier: uti,
                bookmarkData: bookmark
            )
        }

        // 2. Image data
        let imageSpecs: [(NSPasteboard.PasteboardType, String, String)] = [
            (.png, UTType.png.identifier, "png"),
            (NSPasteboard.PasteboardType("public.jpeg"), UTType.jpeg.identifier, "jpg"),
            (.tiff, UTType.tiff.identifier, "tiff")
        ]
        for spec in imageSpecs {
            if let data = item.data(forType: spec.0) {
                let name = "Image-\(Int(Date().timeIntervalSince1970)).\(spec.2)"
                return IngestionPayload(
                    suggestedName: name,
                    contentType: .image,
                    storageType: .imported,
                    sourceURL: nil,
                    localFileURL: nil,
                    rawData: data,
                    textContent: nil,
                    uniformTypeIdentifier: spec.1,
                    bookmarkData: nil
                )
            }
        }

        // 3. Web URL
        if let urlString = item.string(forType: .URL), let url = URL(string: urlString), !url.isFileURL {
            let name = url.host ?? url.lastPathComponent
            return IngestionPayload(
                suggestedName: name.isEmpty ? "Web Link" : name,
                contentType: .url,
                storageType: .link,
                sourceURL: url,
                localFileURL: nil,
                rawData: nil,
                textContent: nil,
                uniformTypeIdentifier: UTType.url.identifier,
                bookmarkData: nil
            )
        }

        // 4. Text
        if let text = item.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let firstLine = trimmed.components(separatedBy: .newlines).first ?? "Snippet"
                let name = String(firstLine.prefix(32))
                return IngestionPayload(
                    suggestedName: name,
                    contentType: .text,
                    storageType: .text,
                    sourceURL: nil,
                    localFileURL: nil,
                    rawData: nil,
                    textContent: text,
                    uniformTypeIdentifier: UTType.plainText.identifier,
                    bookmarkData: nil
                )
            }
        }

        return nil
    }
}
