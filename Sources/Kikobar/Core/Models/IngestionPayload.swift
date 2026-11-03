import Foundation

/// Transient representation of dragged content extracted from an NSPasteboard session.
public struct IngestionPayload: Sendable {
    public let suggestedName: String
    public let contentType: ContentType
    public let storageType: StorageType
    public let sourceURL: URL?
    public let localFileURL: URL?
    public let rawData: Data?
    public let textContent: String?
    public let uniformTypeIdentifier: String?
    public let bookmarkData: Data?

    public init(
        suggestedName: String,
        contentType: ContentType,
        storageType: StorageType,
        sourceURL: URL? = nil,
        localFileURL: URL? = nil,
        rawData: Data? = nil,
        textContent: String? = nil,
        uniformTypeIdentifier: String? = nil,
        bookmarkData: Data? = nil
    ) {
        self.suggestedName = suggestedName
        self.contentType = contentType
        self.storageType = storageType
        self.sourceURL = sourceURL
        self.localFileURL = localFileURL
        self.rawData = rawData
        self.textContent = textContent
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.bookmarkData = bookmarkData
    }
}
