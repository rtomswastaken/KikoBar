import Foundation

/// Represents a user-defined category bucket for organizing dragged items.
public struct CollectionCategory: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var hexColor: String
    public var isExpanded: Bool
    public var sortOrder: Int
    public var itemCount: Int
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        hexColor: String = "#8B7CFF",
        isExpanded: Bool = true,
        sortOrder: Int = 0,
        itemCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.isExpanded = isExpanded
        self.sortOrder = sortOrder
        self.itemCount = itemCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
