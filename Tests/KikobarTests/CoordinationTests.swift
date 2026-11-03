import Foundation
import Testing
@testable import Kikobar

@Suite("App Coordination and Ingestion Integration Tests")
struct CoordinationTests {
    @Test("Verifies Coordinator lifecycle, category CRUD, and item ingestion")
    @MainActor
    func coordinatorLifecycleAndCategoryCRUD() async throws {
        let env = AppEnvironment(
            dragIngestionService: StubDragIngestionService(),
            categoryRepository: InMemoryCategoryRepository(),
            collectionRepository: InMemoryCollectionRepository(),
            fileStorageService: InMemoryFileStorageService(),
            thumbnailService: QuickLookThumbnailService(),
            themeManager: ThemeManager()
        )

        let coordinator = AppCoordinator(environment: env)
        await coordinator.start()

        // Should seed default categories
        #expect(coordinator.categories.count == 3)

        // Create new category
        let newCat = try await coordinator.createCategory(name: "TestCategory", hexColor: "#00B4D8")
        #expect(coordinator.categories.count == 4)
        #expect(newCat.name == "TestCategory")

        // Ingest dummy item
        let payload = IngestionPayload(
            suggestedName: "Note.txt",
            contentType: .text,
            storageType: .text,
            textContent: "Sample text"
        )
        let item = try await env.dragIngestionService.ingest(payload: payload, into: newCat.id)
        try await env.collectionRepository.saveItem(item)

        let items = try await env.collectionRepository.fetchItems(categoryID: newCat.id)
        #expect(items.count == 1)
        #expect(items.first?.name == "Note.txt")

        // Delete category
        try await coordinator.deleteCategory(id: newCat.id)
        #expect(coordinator.categories.count == 3)
    }
}
