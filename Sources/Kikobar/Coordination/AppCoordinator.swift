import AppKit
import Combine
import Foundation
import SwiftUI

/// Central coordinator managing application state, inter-domain event dispatching, and UI panel visibility.
@MainActor
public final class AppCoordinator: ObservableObject {
    public let environment: AppEnvironment

    @Published public private(set) var categories: [CollectionCategory] = []
    @Published public private(set) var itemsByCategory: [UUID: [CollectionItem]] = [:]
    @Published public var isPanelVisible: Bool = false
    @Published public var isDragActive: Bool = false
    @Published public var activeHoverCategoryID: UUID? = nil
    @Published public var errorMessage: String? = nil

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Initializes repositories and loads default state or existing categories.
    public func start() async {
        do {
            try await loadCategories()
            if categories.isEmpty {
                // Seed sensible initial categories if database is fresh
                _ = try await createCategory(name: "Inbox", hexColor: "#8B7CFF")
                _ = try await createCategory(name: "Images", hexColor: "#FF5E7E")
                _ = try await createCategory(name: "References", hexColor: "#38EF7D")
            }
        } catch {
            AppLogger.general.error("Failed to bootstrap categories: \(error.localizedDescription)")
            self.errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    // MARK: - Panel Control

    public func showPanel() {
        guard !isPanelVisible else { return }
        isPanelVisible = true
        AppLogger.ui.debug("Collection panel requested to show.")
    }

    public func hidePanel() {
        guard isPanelVisible else { return }
        isPanelVisible = false
        activeHoverCategoryID = nil
        AppLogger.ui.debug("Collection panel requested to hide.")
    }

    public func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Category Management

    public func loadCategories() async throws {
        let loaded = try await environment.categoryRepository.fetchCategories()
        self.categories = loaded

        for cat in loaded {
            let items = try await environment.collectionRepository.fetchItems(categoryID: cat.id)
            self.itemsByCategory[cat.id] = items
        }
    }

    public func createCategory(name: String, hexColor: String) async throws -> CollectionCategory {
        let created = try await environment.categoryRepository.createCategory(name: name, hexColor: hexColor)
        self.categories.append(created)
        self.itemsByCategory[created.id] = []
        return created
    }

    public func updateCategory(_ category: CollectionCategory) async throws {
        try await environment.categoryRepository.updateCategory(category)
        if let idx = categories.firstIndex(where: { $0.id == category.id }) {
            categories[idx] = category
        }
    }

    public func deleteCategory(id: UUID) async throws {
        try await environment.categoryRepository.deleteCategory(id: id)
        categories.removeAll { $0.id == id }
        itemsByCategory.removeValue(forKey: id)
    }

    public func toggleCategoryExpansion(id: UUID) async {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isExpanded.toggle()
        let newState = categories[idx].isExpanded
        Task {
            try? await self.environment.categoryRepository.toggleExpansion(id: id, isExpanded: newState)
        }
    }

    // MARK: - Drop & Ingestion Handling

    public func handleDrop(pasteboard: NSPasteboard, into categoryID: UUID) async {
        AppLogger.drag.info("Handling drop on category \(categoryID.uuidString)")
        do {
            let payloads = try await environment.dragIngestionService.extractPayloads(from: pasteboard)
            for payload in payloads {
                let item = try await environment.dragIngestionService.ingest(payload: payload, into: categoryID)
                try await environment.collectionRepository.saveItem(item)

                if var list = itemsByCategory[categoryID] {
                    list.insert(item, at: 0)
                    itemsByCategory[categoryID] = list
                } else {
                    itemsByCategory[categoryID] = [item]
                }

                // Update category count
                if let idx = categories.firstIndex(where: { $0.id == categoryID }) {
                    categories[idx].itemCount += 1
                }
            }
        } catch {
            AppLogger.drag.error("Failed to ingest dropped items: \(error.localizedDescription)")
            self.errorMessage = "Failed to ingest drop: \(error.localizedDescription)"
        }
    }

    // MARK: - Item Interactions

    public func openItem(_ item: CollectionItem) {
        if let localPath = item.localPath, FileManager.default.fileExists(atPath: localPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: localPath))
        } else if let sourceURL = item.sourceURL {
            NSWorkspace.shared.open(sourceURL)
        } else if let bookmarkData = item.bookmarkData {
            do {
                let resolved = try environment.fileStorageService.resolveSecurityScopedBookmark(data: bookmarkData)
                NSWorkspace.shared.open(resolved.url)
            } catch {
                AppLogger.storage.error("Unable to open bookmarked file: \(error.localizedDescription)")
            }
        }
    }

    public func deleteItem(id: UUID, categoryID: UUID) async {
        do {
            try await environment.collectionRepository.deleteItem(id: id)
            if var list = itemsByCategory[categoryID] {
                list.removeAll { $0.id == id }
                itemsByCategory[categoryID] = list
            }
            if let idx = categories.firstIndex(where: { $0.id == categoryID }) {
                categories[idx].itemCount = max(0, categories[idx].itemCount - 1)
            }
        } catch {
            AppLogger.persistence.error("Failed to delete item \(id): \(error.localizedDescription)")
        }
    }
}
