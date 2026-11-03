import Foundation

/// Dependency injection container providing core services throughout the application.
public final class AppEnvironment: @unchecked Sendable {
    public let dragIngestionService: DragIngestionServiceProtocol
    public let categoryRepository: CategoryRepositoryProtocol
    public let collectionRepository: CollectionRepositoryProtocol
    public let fileStorageService: FileStorageServiceProtocol
    public let thumbnailService: ThumbnailServiceProtocol
    public let themeManager: ThemeManagerProtocol

    public init(
        dragIngestionService: DragIngestionServiceProtocol,
        categoryRepository: CategoryRepositoryProtocol,
        collectionRepository: CollectionRepositoryProtocol,
        fileStorageService: FileStorageServiceProtocol,
        thumbnailService: ThumbnailServiceProtocol,
        themeManager: ThemeManagerProtocol
    ) {
        self.dragIngestionService = dragIngestionService
        self.categoryRepository = categoryRepository
        self.collectionRepository = collectionRepository
        self.fileStorageService = fileStorageService
        self.thumbnailService = thumbnailService
        self.themeManager = themeManager
    }
}
