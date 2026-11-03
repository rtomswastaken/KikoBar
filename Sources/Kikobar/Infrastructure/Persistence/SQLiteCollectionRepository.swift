import Foundation

/// SQLite implementation of CollectionRepositoryProtocol.
public final class SQLiteCollectionRepository: CollectionRepositoryProtocol, @unchecked Sendable {
    private let database: SQLiteDatabase
    private let fileStorageService: FileStorageServiceProtocol?

    public init(
        database: SQLiteDatabase,
        fileStorageService: FileStorageServiceProtocol? = nil
    ) {
        self.database = database
        self.fileStorageService = fileStorageService
    }

    private func mapItem(from stmt: SQLiteStatement) throws -> CollectionItem {
        guard let id = stmt.columnUUID(index: 0) else {
            throw SQLiteError.stepFailed("Invalid item UUID")
        }
        let name = stmt.columnString(index: 1) ?? ""
        guard let categoryID = stmt.columnUUID(index: 2) else {
            throw SQLiteError.stepFailed("Invalid category UUID for item \(id)")
        }

        let contentTypeRaw = stmt.columnString(index: 3) ?? "file"
        let contentType = ContentType(rawValue: contentTypeRaw) ?? .file

        let storageTypeRaw = stmt.columnString(index: 4) ?? "reference"
        let storageType = StorageType(rawValue: storageTypeRaw) ?? .reference

        let sourceURLString = stmt.columnString(index: 5)
        let sourceURL = sourceURLString.flatMap { URL(string: $0) }

        let localPath = stmt.columnString(index: 6)
        let bookmarkData = stmt.columnData(index: 7)
        let textContent = stmt.columnString(index: 8)
        let thumbnailPath = stmt.columnString(index: 9)
        let fileSize = stmt.columnInt64(index: 10)
        let uti = stmt.columnString(index: 11)
        let dateAdded = stmt.columnDate(index: 12)
        let isSourceAvailable = stmt.columnBool(index: 13)

        return CollectionItem(
            id: id,
            name: name,
            categoryID: categoryID,
            contentType: contentType,
            storageType: storageType,
            sourceURL: sourceURL,
            localPath: localPath,
            bookmarkData: bookmarkData,
            textContent: textContent,
            thumbnailPath: thumbnailPath,
            fileSize: fileSize,
            uniformTypeIdentifier: uti,
            dateAdded: dateAdded,
            isSourceAvailable: isSourceAvailable
        )
    }

    public func fetchItems(categoryID: UUID) async throws -> [CollectionItem] {
        let sql = """
        SELECT id, name, category_id, content_type, storage_type,
               source_url, local_path, bookmark_data, text_content,
               thumbnail_path, file_size, uti, date_added, is_source_available
        FROM items
        WHERE category_id = ?
        ORDER BY date_added DESC;
        """

        return try database.query(sql, binder: { stmt in
            try stmt.bind(index: 1, categoryID)
        }, mapper: { stmt in
            try self.mapItem(from: stmt)
        })
    }

    public func fetchItem(id: UUID) async throws -> CollectionItem? {
        let sql = """
        SELECT id, name, category_id, content_type, storage_type,
               source_url, local_path, bookmark_data, text_content,
               thumbnail_path, file_size, uti, date_added, is_source_available
        FROM items
        WHERE id = ?;
        """

        let results = try database.query(sql, binder: { stmt in
            try stmt.bind(index: 1, id)
        }, mapper: { stmt in
            try self.mapItem(from: stmt)
        })

        return results.first
    }

    public func saveItem(_ item: CollectionItem) async throws {
        let sql = """
        INSERT INTO items (
            id, name, category_id, content_type, storage_type,
            source_url, local_path, bookmark_data, text_content,
            thumbnail_path, file_size, uti, date_added, is_source_available
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            category_id = excluded.category_id,
            content_type = excluded.content_type,
            storage_type = excluded.storage_type,
            source_url = excluded.source_url,
            local_path = excluded.local_path,
            bookmark_data = excluded.bookmark_data,
            text_content = excluded.text_content,
            thumbnail_path = excluded.thumbnail_path,
            file_size = excluded.file_size,
            uti = excluded.uti,
            date_added = excluded.date_added,
            is_source_available = excluded.is_source_available;
        """

        try database.execute(sql) { stmt in
            try stmt.bind(index: 1, item.id)
            try stmt.bind(index: 2, item.name)
            try stmt.bind(index: 3, item.categoryID)
            try stmt.bind(index: 4, item.contentType.rawValue)
            try stmt.bind(index: 5, item.storageType.rawValue)
            try stmt.bind(index: 6, item.sourceURL?.absoluteString)
            try stmt.bind(index: 7, item.localPath)
            try stmt.bind(index: 8, item.bookmarkData)
            try stmt.bind(index: 9, item.textContent)
            try stmt.bind(index: 10, item.thumbnailPath)
            try stmt.bind(index: 11, item.fileSize)
            try stmt.bind(index: 12, item.uniformTypeIdentifier)
            try stmt.bind(index: 13, item.dateAdded)
            try stmt.bind(index: 14, item.isSourceAvailable)
        }
    }

    public func updateItem(_ item: CollectionItem) async throws {
        try await saveItem(item)
    }

    public func deleteItem(id: UUID) async throws {
        // Clean up managed filesystem storage if service is provided
        if let storage = fileStorageService, let item = try await fetchItem(id: id) {
            if item.storageType == .imported, let localPath = item.localPath {
                try? storage.deleteStoredItem(at: localPath)
            }
        }

        let sql = "DELETE FROM items WHERE id = ?;"
        try database.execute(sql) { stmt in
            try stmt.bind(index: 1, id)
        }
    }

    public func moveItem(id: UUID, toCategoryID: UUID) async throws {
        let sql = "UPDATE items SET category_id = ? WHERE id = ?;"
        try database.execute(sql) { stmt in
            try stmt.bind(index: 1, toCategoryID)
            try stmt.bind(index: 2, id)
        }
    }

    public func countItems(categoryID: UUID) async throws -> Int {
        let sql = "SELECT COUNT(*) FROM items WHERE category_id = ?;"
        let counts = try database.query(sql, binder: { stmt in
            try stmt.bind(index: 1, categoryID)
        }, mapper: { stmt in
            stmt.columnInt(index: 0)
        })
        return counts.first ?? 0
    }

    public func searchItems(query: String) async throws -> [CollectionItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let sql = """
        SELECT id, name, category_id, content_type, storage_type,
               source_url, local_path, bookmark_data, text_content,
               thumbnail_path, file_size, uti, date_added, is_source_available
        FROM items
        WHERE LOWER(name) LIKE ? OR LOWER(text_content) LIKE ?
        ORDER BY date_added DESC;
        """

        let searchPattern = "%\(trimmed.lowercased())%"
        return try database.query(sql, binder: { stmt in
            try stmt.bind(index: 1, searchPattern)
            try stmt.bind(index: 2, searchPattern)
        }, mapper: { stmt in
            try self.mapItem(from: stmt)
        })
    }

    // MARK: - Source Availability & Missing File Detection

    /// Verifies whether a referenced item still exists on disk.
    /// If missing or deleted, updates `isSourceAvailable = false` in the database.
    @discardableResult
    public func verifyAvailability(
        for itemID: UUID,
        storageService: FileStorageServiceProtocol
    ) async throws -> Bool {
        guard let item = try await fetchItem(id: itemID) else { return false }
        var isAvailable = false

        if let localPath = item.localPath {
            isAvailable = storageService.verifySourceAvailability(at: localPath)
        } else if let bookmarkData = item.bookmarkData {
            if let resolved = try? storageService.resolveSecurityScopedBookmark(data: bookmarkData) {
                isAvailable = storageService.verifySourceAvailability(at: resolved.url.path)
            }
        } else {
            isAvailable = true
        }

        if item.isSourceAvailable != isAvailable {
            var updatedItem = item
            updatedItem.isSourceAvailable = isAvailable
            try await updateItem(updatedItem)
        }

        return isAvailable
    }

    /// Verifies availability for all items (optionally restricted to a categoryID).
    /// Returns the number of items whose availability state was changed.
    @discardableResult
    public func verifyAllItemsAvailability(
        categoryID: UUID? = nil,
        storageService: FileStorageServiceProtocol
    ) async throws -> Int {
        let items: [CollectionItem]
        if let catID = categoryID {
            items = try await fetchItems(categoryID: catID)
        } else {
            let sql = """
            SELECT id, name, category_id, content_type, storage_type,
                   source_url, local_path, bookmark_data, text_content,
                   thumbnail_path, file_size, uti, date_added, is_source_available
            FROM items;
            """
            items = try database.query(sql, mapper: { stmt in
                try self.mapItem(from: stmt)
            })
        }

        var changedCount = 0
        for item in items {
            var isAvailable = false
            if let localPath = item.localPath {
                isAvailable = storageService.verifySourceAvailability(at: localPath)
            } else if let bookmarkData = item.bookmarkData {
                if let resolved = try? storageService.resolveSecurityScopedBookmark(data: bookmarkData) {
                    isAvailable = storageService.verifySourceAvailability(at: resolved.url.path)
                } else {
                    isAvailable = false
                }
            } else {
                isAvailable = true
            }

            if item.isSourceAvailable != isAvailable {
                var updated = item
                updated.isSourceAvailable = isAvailable
                try await updateItem(updated)
                changedCount += 1
            }
        }

        return changedCount
    }
}
