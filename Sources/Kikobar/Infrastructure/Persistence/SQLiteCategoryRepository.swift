import Foundation

/// SQLite implementation of CategoryRepositoryProtocol.
public final class SQLiteCategoryRepository: CategoryRepositoryProtocol, @unchecked Sendable {
    private let database: SQLiteDatabase
    private let fileStorageService: FileStorageServiceProtocol?

    public init(
        database: SQLiteDatabase,
        fileStorageService: FileStorageServiceProtocol? = nil
    ) {
        self.database = database
        self.fileStorageService = fileStorageService
    }

    public func fetchCategories() async throws -> [CollectionCategory] {
        let sql = """
        SELECT c.id, c.name, c.hex_color, c.is_expanded, c.sort_order, c.created_at, c.updated_at,
               COUNT(i.id) AS item_count
        FROM categories c
        LEFT JOIN items i ON c.id = i.category_id
        GROUP BY c.id
        ORDER BY c.sort_order ASC, c.created_at ASC;
        """

        return try database.query(sql) { stmt in
            guard let id = stmt.columnUUID(index: 0) else {
                throw SQLiteError.stepFailed("Invalid or missing category UUID")
            }
            let name = stmt.columnString(index: 1) ?? ""
            let hexColor = stmt.columnString(index: 2) ?? "#8B7CFF"
            let isExpanded = stmt.columnBool(index: 3)
            let sortOrder = stmt.columnInt(index: 4)
            let createdAt = stmt.columnDate(index: 5)
            let updatedAt = stmt.columnDate(index: 6)
            let itemCount = stmt.columnInt(index: 7)

            return CollectionCategory(
                id: id,
                name: name,
                hexColor: hexColor,
                isExpanded: isExpanded,
                sortOrder: sortOrder,
                itemCount: itemCount,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    public func fetchCategory(id: UUID) async throws -> CollectionCategory? {
        let sql = """
        SELECT c.id, c.name, c.hex_color, c.is_expanded, c.sort_order, c.created_at, c.updated_at,
               COUNT(i.id) AS item_count
        FROM categories c
        LEFT JOIN items i ON c.id = i.category_id
        WHERE c.id = ?
        GROUP BY c.id;
        """

        let results = try database.query(sql, binder: { stmt in
            try stmt.bind(index: 1, id)
        }, mapper: { stmt -> CollectionCategory in
            guard let catId = stmt.columnUUID(index: 0) else {
                throw SQLiteError.stepFailed("Invalid or missing category UUID")
            }
            let name = stmt.columnString(index: 1) ?? ""
            let hexColor = stmt.columnString(index: 2) ?? "#8B7CFF"
            let isExpanded = stmt.columnBool(index: 3)
            let sortOrder = stmt.columnInt(index: 4)
            let createdAt = stmt.columnDate(index: 5)
            let updatedAt = stmt.columnDate(index: 6)
            let itemCount = stmt.columnInt(index: 7)

            return CollectionCategory(
                id: catId,
                name: name,
                hexColor: hexColor,
                isExpanded: isExpanded,
                sortOrder: sortOrder,
                itemCount: itemCount,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        })

        return results.first
    }

    public func createCategory(name: String, hexColor: String) async throws -> CollectionCategory {
        let maxSortOrderSql = "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM categories;"
        let sortOrders = try database.query(maxSortOrderSql) { stmt in
            stmt.columnInt(index: 0)
        }
        let nextSortOrder = sortOrders.first ?? 0

        let newID = UUID()
        let now = Date()

        let insertSql = """
        INSERT INTO categories (id, name, hex_color, is_expanded, sort_order, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        try database.execute(insertSql) { stmt in
            try stmt.bind(index: 1, newID)
            try stmt.bind(index: 2, name)
            try stmt.bind(index: 3, hexColor)
            try stmt.bind(index: 4, true)
            try stmt.bind(index: 5, nextSortOrder)
            try stmt.bind(index: 6, now)
            try stmt.bind(index: 7, now)
        }

        return CollectionCategory(
            id: newID,
            name: name,
            hexColor: hexColor,
            isExpanded: true,
            sortOrder: nextSortOrder,
            itemCount: 0,
            createdAt: now,
            updatedAt: now
        )
    }

    public func updateCategory(_ category: CollectionCategory) async throws {
        let sql = """
        UPDATE categories
        SET name = ?, hex_color = ?, is_expanded = ?, sort_order = ?, updated_at = ?
        WHERE id = ?;
        """

        try database.execute(sql) { stmt in
            try stmt.bind(index: 1, category.name)
            try stmt.bind(index: 2, category.hexColor)
            try stmt.bind(index: 3, category.isExpanded)
            try stmt.bind(index: 4, category.sortOrder)
            try stmt.bind(index: 5, Date())
            try stmt.bind(index: 6, category.id)
        }
    }

    public func deleteCategory(id: UUID) async throws {
        // Clean up managed filesystem storage if service is provided
        if let storage = fileStorageService {
            let itemPathsSql = "SELECT local_path, storage_type FROM items WHERE category_id = ?;"
            let filesToClean = try database.query(itemPathsSql, binder: { stmt in
                try stmt.bind(index: 1, id)
            }, mapper: { stmt -> (path: String?, storageType: String?) in
                (stmt.columnString(index: 0), stmt.columnString(index: 1))
            })

            for file in filesToClean {
                if file.storageType == StorageType.imported.rawValue, let path = file.path {
                    try? storage.deleteStoredItem(at: path)
                }
            }

            if let localService = storage as? LocalFileStorageService {
                try? localService.deleteCategoryStorage(categoryID: id)
            }
        }

        // Deleting category triggers ON DELETE CASCADE in SQLite, removing child items
        let deleteSql = "DELETE FROM categories WHERE id = ?;"
        try database.execute(deleteSql) { stmt in
            try stmt.bind(index: 1, id)
        }
    }

    public func reorderCategories(ids: [UUID]) async throws {
        let updateSql = "UPDATE categories SET sort_order = ?, updated_at = ? WHERE id = ?;"
        try database.transaction {
            let now = Date()
            for (index, id) in ids.enumerated() {
                try database.execute(updateSql) { stmt in
                    try stmt.bind(index: 1, index)
                    try stmt.bind(index: 2, now)
                    try stmt.bind(index: 3, id)
                }
            }
        }
    }

    public func toggleExpansion(id: UUID, isExpanded: Bool) async throws {
        let sql = "UPDATE categories SET is_expanded = ?, updated_at = ? WHERE id = ?;"
        try database.execute(sql) { stmt in
            try stmt.bind(index: 1, isExpanded)
            try stmt.bind(index: 2, Date())
            try stmt.bind(index: 3, id)
        }
    }
}
