import Foundation

/// Defines persistent storage and query operations for collection categories.
public protocol CategoryRepositoryProtocol: AnyObject, Sendable {
    /// Fetches all categories ordered by sortOrder.
    func fetchCategories() async throws -> [CollectionCategory]

    /// Fetches a specific category by its identifier.
    func fetchCategory(id: UUID) async throws -> CollectionCategory?

    /// Creates a new category.
    func createCategory(name: String, hexColor: String) async throws -> CollectionCategory

    /// Updates an existing category.
    func updateCategory(_ category: CollectionCategory) async throws

    /// Deletes a category and optionally all associated items.
    func deleteCategory(id: UUID) async throws

    /// Updates the sort order for a batch of category identifiers.
    func reorderCategories(ids: [UUID]) async throws

    /// Toggles the expansion state of a category.
    func toggleExpansion(id: UUID, isExpanded: Bool) async throws
}
