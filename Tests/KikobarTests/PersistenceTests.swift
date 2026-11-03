import Foundation
import Testing
@testable import Kikobar

@Suite("SQLite Persistence & Storage Management Tests")
struct PersistenceTests {

    private func makeTemporaryDirectory() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KikobarTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        return tempURL
    }

    // MARK: - SQLite Database & PRAGMA Verification

    @Test("Initializes database with foreign keys enabled and WAL journal mode")
    func databaseInitializationAndPragmas() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_pragmas.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)

        // Verify foreign_keys PRAGMA is ON (1)
        let fkResults = try database.query("PRAGMA foreign_keys;") { stmt in
            stmt.columnInt(index: 0)
        }
        #expect(fkResults.first == 1)

        // Verify journal_mode PRAGMA is WAL
        let journalResults = try database.query("PRAGMA journal_mode;") { stmt in
            stmt.columnString(index: 0)?.lowercased()
        }
        #expect(journalResults.first == "wal")
    }

    @Test("Database transactions commit on success and rollback on failure")
    func databaseTransactions() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_tx.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database)

        // Successful transaction
        let cat1 = try await categoryRepo.createCategory(name: "Cat1", hexColor: "#111111")
        let cat2 = try await categoryRepo.createCategory(name: "Cat2", hexColor: "#222222")

        try database.transaction {
            try database.execute("UPDATE categories SET name = 'Updated1' WHERE id = ?;") { stmt in
                try stmt.bind(index: 1, cat1.id)
            }
            try database.execute("UPDATE categories SET name = 'Updated2' WHERE id = ?;") { stmt in
                try stmt.bind(index: 1, cat2.id)
            }
        }

        let fetchedCat1 = try await categoryRepo.fetchCategory(id: cat1.id)
        #expect(fetchedCat1?.name == "Updated1")

        // Failed transaction should rollback all changes
        do {
            try database.transaction {
                try database.execute("UPDATE categories SET name = 'ShouldRollback' WHERE id = ?;") { stmt in
                    try stmt.bind(index: 1, cat1.id)
                }
                throw SQLiteError.executionFailed("Forced transaction failure")
            }
        } catch {
            // Expected error
        }

        let rollbackCat1 = try await categoryRepo.fetchCategory(id: cat1.id)
        #expect(rollbackCat1?.name == "Updated1")
    }

    // MARK: - Category Repository CRUD & Reordering

    @Test("Performs full category CRUD, sorting, and expansion toggling")
    func categoryCRUDAndReordering() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_categories.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database)

        // 1. Create categories
        let catA = try await categoryRepo.createCategory(name: "Design", hexColor: "#FF5E7E")
        let catB = try await categoryRepo.createCategory(name: "Code", hexColor: "#38EF7D")
        let catC = try await categoryRepo.createCategory(name: "Articles", hexColor: "#8B7CFF")

        #expect(catA.sortOrder == 0)
        #expect(catB.sortOrder == 1)
        #expect(catC.sortOrder == 2)

        // 2. Fetch all
        var all = try await categoryRepo.fetchCategories()
        #expect(all.count == 3)
        #expect(all.map(\.name) == ["Design", "Code", "Articles"])

        // 3. Update category
        var updatedA = catA
        updatedA.name = "UI Design"
        updatedA.hexColor = "#FF0000"
        try await categoryRepo.updateCategory(updatedA)

        let fetchedA = try await categoryRepo.fetchCategory(id: catA.id)
        #expect(fetchedA?.name == "UI Design")
        #expect(fetchedA?.hexColor == "#FF0000")

        // 4. Toggle expansion
        try await categoryRepo.toggleExpansion(id: catA.id, isExpanded: false)
        let collapsedA = try await categoryRepo.fetchCategory(id: catA.id)
        #expect(collapsedA?.isExpanded == false)

        // 5. Reorder categories: C (0), A (1), B (2)
        try await categoryRepo.reorderCategories(ids: [catC.id, catA.id, catB.id])
        all = try await categoryRepo.fetchCategories()
        #expect(all.map(\.name) == ["Articles", "UI Design", "Code"])

        // 6. Delete category
        try await categoryRepo.deleteCategory(id: catB.id)
        all = try await categoryRepo.fetchCategories()
        #expect(all.count == 2)
        #expect(try await categoryRepo.fetchCategory(id: catB.id) == nil)
    }

    // MARK: - Collection Item CRUD, Move, Search & Counts

    @Test("Performs collection item CRUD, moving, item counts, and search")
    func itemCRUDMoveAndSearch() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_items.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database)
        let collectionRepo = SQLiteCollectionRepository(database: database)

        let cat1 = try await categoryRepo.createCategory(name: "Work", hexColor: "#8B7CFF")
        let cat2 = try await categoryRepo.createCategory(name: "Archive", hexColor: "#A0A0A0")

        // 1. Save items
        let item1 = CollectionItem(
            name: "ProjectPlan.pdf",
            categoryID: cat1.id,
            contentType: .document,
            storageType: .imported,
            textContent: "Confidential kickoff meeting notes",
            fileSize: 1024,
            uniformTypeIdentifier: "com.adobe.pdf"
        )
        let item2 = CollectionItem(
            name: "Screenshot.png",
            categoryID: cat1.id,
            contentType: .image,
            storageType: .reference,
            fileSize: 2048,
            uniformTypeIdentifier: "public.png"
        )
        try await collectionRepo.saveItem(item1)
        try await collectionRepo.saveItem(item2)

        // 2. Fetch and count
        let items = try await collectionRepo.fetchItems(categoryID: cat1.id)
        #expect(items.count == 2)
        #expect(try await collectionRepo.countItems(categoryID: cat1.id) == 2)
        #expect(try await collectionRepo.countItems(categoryID: cat2.id) == 0)

        // Category fetchCategories should reflect item count via dynamic COUNT aggregation
        let cats = try await categoryRepo.fetchCategories()
        let fetchedCat1 = cats.first { $0.id == cat1.id }
        #expect(fetchedCat1?.itemCount == 2)

        // 3. Move item
        try await collectionRepo.moveItem(id: item1.id, toCategoryID: cat2.id)
        #expect(try await collectionRepo.countItems(categoryID: cat1.id) == 1)
        #expect(try await collectionRepo.countItems(categoryID: cat2.id) == 1)

        let movedItem = try await collectionRepo.fetchItem(id: item1.id)
        #expect(movedItem?.categoryID == cat2.id)

        // 4. Search items by name and text content
        let searchNameResults = try await collectionRepo.searchItems(query: "screenshot")
        #expect(searchNameResults.count == 1)
        #expect(searchNameResults.first?.id == item2.id)

        let searchContentResults = try await collectionRepo.searchItems(query: "kickoff")
        #expect(searchContentResults.count == 1)
        #expect(searchContentResults.first?.id == item1.id)

        let emptySearch = try await collectionRepo.searchItems(query: "nonexistent")
        #expect(emptySearch.isEmpty)

        // 5. Update item
        var updatedItem2 = item2
        updatedItem2.name = "FinalScreenshot.png"
        try await collectionRepo.updateItem(updatedItem2)
        let fetchedItem2 = try await collectionRepo.fetchItem(id: item2.id)
        #expect(fetchedItem2?.name == "FinalScreenshot.png")

        // 6. Delete item
        try await collectionRepo.deleteItem(id: item2.id)
        #expect(try await collectionRepo.countItems(categoryID: cat1.id) == 0)
        #expect(try await collectionRepo.fetchItem(id: item2.id) == nil)
    }

    // MARK: - Foreign Key Cascade Deletion

    @Test("Foreign key cascade removes all child items when category is deleted")
    func foreignKeyCascadeDeletion() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("test_cascade.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database)
        let collectionRepo = SQLiteCollectionRepository(database: database)

        let category = try await categoryRepo.createCategory(name: "TempCategory", hexColor: "#FF5E7E")

        let item1 = CollectionItem(name: "Item1.txt", categoryID: category.id, contentType: .text, storageType: .text)
        let item2 = CollectionItem(name: "Item2.txt", categoryID: category.id, contentType: .text, storageType: .text)
        let item3 = CollectionItem(name: "Item3.txt", categoryID: category.id, contentType: .text, storageType: .text)

        try await collectionRepo.saveItem(item1)
        try await collectionRepo.saveItem(item2)
        try await collectionRepo.saveItem(item3)

        #expect(try await collectionRepo.countItems(categoryID: category.id) == 3)

        // Delete parent category
        try await categoryRepo.deleteCategory(id: category.id)

        // Check category is gone
        #expect(try await categoryRepo.fetchCategory(id: category.id) == nil)

        // Check all 3 items were cascaded and completely removed from database
        #expect(try await collectionRepo.fetchItem(id: item1.id) == nil)
        #expect(try await collectionRepo.fetchItem(id: item2.id) == nil)
        #expect(try await collectionRepo.fetchItem(id: item3.id) == nil)
        #expect(try await collectionRepo.countItems(categoryID: category.id) == 0)
    }

    // MARK: - Persistence Across App / Database Reopens

    @Test("Data persists reliably across database instances reopening the same file")
    func persistenceAcrossDatabaseReopens() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("persistent_store.sqlite")
        let categoryID: UUID
        let itemID: UUID

        // Scope 1: Initial instance writing data
        do {
            let database = try SQLiteDatabase(databaseURL: dbURL)
            let categoryRepo = SQLiteCategoryRepository(database: database)
            let collectionRepo = SQLiteCollectionRepository(database: database)

            let cat = try await categoryRepo.createCategory(name: "PersistentCat", hexColor: "#38EF7D")
            categoryID = cat.id

            let item = CollectionItem(
                name: "PersistentDoc.pdf",
                categoryID: cat.id,
                contentType: .document,
                storageType: .imported,
                textContent: "Important persisted text",
                fileSize: 4096,
                uniformTypeIdentifier: "com.adobe.pdf"
            )
            itemID = item.id
            try await collectionRepo.saveItem(item)
        }

        // Scope 2: Fresh database instance reopening the existing file
        do {
            let database = try SQLiteDatabase(databaseURL: dbURL)
            let categoryRepo = SQLiteCategoryRepository(database: database)
            let collectionRepo = SQLiteCollectionRepository(database: database)

            let categories = try await categoryRepo.fetchCategories()
            #expect(categories.count == 1)
            #expect(categories.first?.id == categoryID)
            #expect(categories.first?.name == "PersistentCat")
            #expect(categories.first?.itemCount == 1)

            let item = try await collectionRepo.fetchItem(id: itemID)
            #expect(item != nil)
            #expect(item?.name == "PersistentDoc.pdf")
            #expect(item?.contentType == .document)
            #expect(item?.storageType == .imported)
            #expect(item?.textContent == "Important persisted text")
            #expect(item?.fileSize == 4096)
        }
    }

    // MARK: - LocalFileStorageService Tests

    @Test("LocalFileStorageService handles raw data, snippets, and file imports")
    func localFileStorageOperations() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageService = LocalFileStorageService(baseStorageDirectory: tempDir)
        let categoryID = UUID()

        // 1. Import raw data
        let sampleData = "Hello Kikobar".data(using: .utf8)!
        let dataURL = try storageService.importData(sampleData, filename: "hello.txt", categoryID: categoryID)
        #expect(storageService.verifySourceAvailability(at: dataURL.path))
        #expect(FileManager.default.fileExists(atPath: dataURL.path))

        // 2. Save snippet
        let snippetURL = try storageService.saveSnippet("Swift snippet code", title: "MyCode", categoryID: categoryID)
        #expect(snippetURL.lastPathComponent == "MyCode.txt")
        #expect(storageService.verifySourceAvailability(at: snippetURL.path))

        // 3. Import existing file
        let sourceFile = tempDir.appendingPathComponent("external_source.jpg")
        try "image binary data".write(to: sourceFile, atomically: true, encoding: .utf8)
        let importedURL = try storageService.importFile(from: sourceFile, categoryID: categoryID)
        #expect(importedURL.lastPathComponent == "external_source.jpg")
        #expect(storageService.verifySourceAvailability(at: importedURL.path))

        // 4. Delete stored item
        try storageService.deleteStoredItem(at: dataURL.path)
        #expect(!storageService.verifySourceAvailability(at: dataURL.path))

        // 5. Delete category storage directory
        try storageService.deleteCategoryStorage(categoryID: categoryID)
        let catDir = tempDir.appendingPathComponent(categoryID.uuidString)
        #expect(!FileManager.default.fileExists(atPath: catDir.path))
    }

    // MARK: - Security-Scoped Bookmarks & Missing File Detection

    @Test("Security-scoped bookmarks preserve references and detect missing files gracefully")
    func securityScopedBookmarksAndMissingFileDetection() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageService = LocalFileStorageService(baseStorageDirectory: tempDir)
        let dbURL = tempDir.appendingPathComponent("test_bookmarks.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database, fileStorageService: storageService)
        let collectionRepo = SQLiteCollectionRepository(database: database, fileStorageService: storageService)

        let category = try await categoryRepo.createCategory(name: "References", hexColor: "#00B4D8")

        // 1. Create a real temporary file on disk
        let referencedFile = tempDir.appendingPathComponent("ImportantDesign.sketch")
        try "design data contents".write(to: referencedFile, atomically: true, encoding: .utf8)

        // 2. Create and resolve bookmark
        let bookmarkData = try storageService.createSecurityScopedBookmark(for: referencedFile)
        #expect(!bookmarkData.isEmpty)

        let resolved = try storageService.resolveSecurityScopedBookmark(data: bookmarkData)
        #expect(resolved.url.standardizedFileURL.path == referencedFile.standardizedFileURL.path)

        // 3. Save as reference item in repository
        let item = CollectionItem(
            name: "ImportantDesign.sketch",
            categoryID: category.id,
            contentType: .file,
            storageType: .reference,
            localPath: referencedFile.path,
            bookmarkData: bookmarkData,
            isSourceAvailable: true
        )
        try await collectionRepo.saveItem(item)

        // Verify initially available
        let initialAvailability = try await collectionRepo.verifyAvailability(for: item.id, storageService: storageService)
        #expect(initialAvailability == true)
        let fetchedItem1 = try await collectionRepo.fetchItem(id: item.id)
        #expect(fetchedItem1?.isSourceAvailable == true)

        // 4. Delete the referenced file from disk
        try FileManager.default.removeItem(at: referencedFile)
        #expect(!FileManager.default.fileExists(atPath: referencedFile.path))

        // 5. Verify availability should detect missing file and update isSourceAvailable = false in DB
        let postDeleteAvailability = try await collectionRepo.verifyAvailability(for: item.id, storageService: storageService)
        #expect(postDeleteAvailability == false)

        let fetchedItem2 = try await collectionRepo.fetchItem(id: item.id)
        #expect(fetchedItem2 != nil)
        #expect(fetchedItem2?.isSourceAvailable == false)
        #expect(fetchedItem2?.bookmarkData != nil) // Bookmark data preserved!

        // Batch verification also works cleanly
        let changed = try await collectionRepo.verifyAllItemsAvailability(categoryID: category.id, storageService: storageService)
        #expect(changed == 0) // Already updated
    }

    // MARK: - Category Deletion Cleans Up Managed Storage Files

    @Test("Deleting a category cleans up its managed imported files on disk")
    func categoryDeletionCleansUpFiles() async throws {
        let tempDir = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storageService = LocalFileStorageService(baseStorageDirectory: tempDir)
        let dbURL = tempDir.appendingPathComponent("test_cleanup.sqlite")
        let database = try SQLiteDatabase(databaseURL: dbURL)
        let categoryRepo = SQLiteCategoryRepository(database: database, fileStorageService: storageService)
        let collectionRepo = SQLiteCollectionRepository(database: database, fileStorageService: storageService)

        let category = try await categoryRepo.createCategory(name: "Assets", hexColor: "#FF5E7E")

        // Import a file into managed storage
        let fileURL = try storageService.importData("asset content".data(using: .utf8)!, filename: "asset.png", categoryID: category.id)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let item = CollectionItem(
            name: "asset.png",
            categoryID: category.id,
            contentType: .image,
            storageType: .imported,
            localPath: fileURL.path
        )
        try await collectionRepo.saveItem(item)

        // Delete category
        try await categoryRepo.deleteCategory(id: category.id)

        // Verify file was cleaned up on disk
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(try await categoryRepo.fetchCategory(id: category.id) == nil)
        #expect(try await collectionRepo.fetchItem(id: item.id) == nil)
    }
}
