import Foundation

/// Represents a single item stored within a Kikobar category.
public struct CollectionItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var categoryID: UUID
    public var contentType: ContentType
    public var storageType: StorageType
    public var sourceURL: URL?
    public var localPath: String?
    public var bookmarkData: Data?
    public var textContent: String?
    public var thumbnailPath: String?
    public var fileSize: Int64?
    public var uniformTypeIdentifier: String?
    public let dateAdded: Date
    public var isSourceAvailable: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        categoryID: UUID,
        contentType: ContentType,
        storageType: StorageType,
        sourceURL: URL? = nil,
        localPath: String? = nil,
        bookmarkData: Data? = nil,
        textContent: String? = nil,
        thumbnailPath: String? = nil,
        fileSize: Int64? = nil,
        uniformTypeIdentifier: String? = nil,
        dateAdded: Date = Date(),
        isSourceAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.contentType = contentType
        self.storageType = storageType
        self.sourceURL = sourceURL
        self.localPath = localPath
        self.bookmarkData = bookmarkData
        self.textContent = textContent
        self.thumbnailPath = thumbnailPath
        self.fileSize = fileSize
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.dateAdded = dateAdded
        self.isSourceAvailable = isSourceAvailable
    }
}
