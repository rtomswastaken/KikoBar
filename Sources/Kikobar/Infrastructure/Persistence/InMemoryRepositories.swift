import Foundation

/// Thread-safe in-memory category repository for tests, previews, and parallel agent workflows.
public actor InMemoryCategoryRepository: CategoryRepositoryProtocol {
    private var categories: [CollectionCategory] = []

    public init(initialCategories: [CollectionCategory] = []) {
        self.categories = initialCategories
    }

    public func fetchCategories() async throws -> [CollectionCategory] {
        return categories.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    public func fetchCategory(id: UUID) async throws -> CollectionCategory? {
        return categories.first(where: { $0.id == id })
    }

    public func createCategory(name: String, hexColor: String) async throws -> CollectionCategory {
        let newCategory = CollectionCategory(
            id: UUID(),
            name: name,
            hexColor: hexColor,
            isExpanded: true,
            sortOrder: categories.count,
            itemCount: 0
        )
        categories.append(newCategory)
        return newCategory
    }

    public func updateCategory(_ category: CollectionCategory) async throws {
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
        }
    }

    public func deleteCategory(id: UUID) async throws {
        categories.removeAll { $0.id == id }
    }

    public func reorderCategories(ids: [UUID]) async throws {
        for (index, id) in ids.enumerated() {
            if let idx = categories.firstIndex(where: { $0.id == id }) {
                categories[idx].sortOrder = index
            }
        }
    }

    public func toggleExpansion(id: UUID, isExpanded: Bool) async throws {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].isExpanded = isExpanded
        }
    }
}

/// Thread-safe in-memory collection item repository.
public actor InMemoryCollectionRepository: CollectionRepositoryProtocol {
    private var items: [CollectionItem] = []

    public init(initialItems: [CollectionItem] = []) {
        self.items = initialItems
    }

    public func fetchItems(categoryID: UUID) async throws -> [CollectionItem] {
        return items.filter { $0.categoryID == categoryID }
            .sorted(by: { $0.dateAdded > $1.dateAdded })
    }

    public func fetchItem(id: UUID) async throws -> CollectionItem? {
        return items.first(where: { $0.id == id })
    }

    public func saveItem(_ item: CollectionItem) async throws {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
    }

    public func updateItem(_ item: CollectionItem) async throws {
        try await saveItem(item)
    }

    public func deleteItem(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    public func moveItem(id: UUID, toCategoryID: UUID) async throws {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].categoryID = toCategoryID
        }
    }

    public func countItems(categoryID: UUID) async throws -> Int {
        return items.filter { $0.categoryID == categoryID }.count
    }

    public func searchItems(query: String) async throws -> [CollectionItem] {
        let lower = query.lowercased()
        return items.filter { $0.name.lowercased().contains(lower) }
    }
}
