import Foundation

/// Defines persistent storage and query operations for collection items.
public protocol CollectionRepositoryProtocol: AnyObject, Sendable {
    /// Fetches all items belonging to a given category.
    func fetchItems(categoryID: UUID) async throws -> [CollectionItem]

    /// Fetches a specific item by its identifier.
    func fetchItem(id: UUID) async throws -> CollectionItem?

    /// Inserts or saves a new item into a category.
    func saveItem(_ item: CollectionItem) async throws

    /// Updates existing item attributes (e.g. name, availability, thumbnail).
    func updateItem(_ item: CollectionItem) async throws

    /// Deletes an item by its identifier.
    func deleteItem(id: UUID) async throws

    /// Moves an item to a different category.
    func moveItem(id: UUID, toCategoryID: UUID) async throws

    /// Returns the total count of items in a category.
    func countItems(categoryID: UUID) async throws -> Int

    /// Searches items across all categories matching a query string.
    func searchItems(query: String) async throws -> [CollectionItem]
}
