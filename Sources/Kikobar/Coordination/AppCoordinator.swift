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
    @Published public var isEditingBoard: Bool = false
    @Published public var editingBoardID: UUID? = nil
    @Published public var creatingBoardID: UUID? = nil
    @Published public var boardPendingDeletion: Board? = nil
    @Published public var pendingDropPayloads: [IngestionPayload]? = nil
    @Published public var activeHoverCategoryID: UUID? = nil
    @Published public var dragState: DrawerDragState = .idle
    @Published public var errorMessage: String? = nil

    private var dismissalTimer: Timer?

    // Board Terminology Aliases
    public var boards: [Board] { categories }
    @Published public var selectedItemIDs: Set<UUID> = []
    @Published public var panelWidth: CGFloat = ScreenGeometry.userPanelWidth
    public var itemsByBoard: [UUID: [CollectionItem]] { itemsByCategory }

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Initializes repositories and loads existing user boards without hardcoded placeholders.
    public func start() async {
        do {
            try await loadCategories()
        } catch {
            AppLogger.general.error("Failed to bootstrap categories: \(error.localizedDescription)")
            self.errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
    }

    // MARK: - Panel & Drag Lifecycle State Machine

    public func showPanel() {
        cancelDismissalCountdown()
        guard !isPanelVisible else { return }
        isPanelVisible = true
        if dragState == .idle || dragState == .collapsed {
            dragState = .drawerExpanded
        }
        AppLogger.ui.debug("Collection drawer expanded.")
    }

    public func hidePanel() {
        cancelDismissalCountdown()
        guard isPanelVisible else { return }
        isPanelVisible = false
        activeHoverCategoryID = nil
        editingBoardID = nil
        creatingBoardID = nil
        boardPendingDeletion = nil
        isEditingBoard = false
        dragState = .collapsed
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if self.dragState == .collapsed {
                self.dragState = .idle
            }
        }
        AppLogger.ui.debug("Collection drawer collapsed.")
    }

    // MARK: - Automatic Dismissal (Exactly 1,000ms / 1.0 Second)

    public func startDismissalCountdown() {
        guard isPanelVisible else { return }
        guard !isDragActive else { return }
        guard !isEditingBoard else { return }
        guard boardPendingDeletion == nil else { return }
        if case .confirmation = dragState { return }

        dismissalTimer?.invalidate()
        dismissalTimer = Timer.scheduledTimer(withTimeInterval: DesignSystem.Animation.autoDismissalDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.isPanelVisible, !self.isDragActive, !self.isEditingBoard, self.boardPendingDeletion == nil else { return }
                self.hidePanel()
            }
        }
    }

    public func cancelDismissalCountdown() {
        dismissalTimer?.invalidate()
        dismissalTimer = nil
    }

    /// Creates a new board and immediately activates inline title editing.
    public func createNewBoardInteractive() async -> Board? {
        cancelDismissalCountdown()
        let nextIndex = boards.count + 1
        let palette = BoardColorPickerPopover.palette
        let color = palette[nextIndex % palette.count]
        do {
            let board = try await createBoard(name: "new board", hexColor: color, isExpanded: true)
            self.creatingBoardID = board.id
            self.editingBoardID = board.id
            self.isEditingBoard = true
            return board
        } catch {
            AppLogger.general.error("Failed to create interactive board: \(error.localizedDescription)")
            return nil
        }
    }

    public func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    public func updatePanelWidth(_ width: CGFloat) {
        let maxAllowed = min(ScreenGeometry.maxPanelWidth, (NSScreen.main?.visibleFrame.width ?? 1440) * 0.7)
        let clamped = min(max(width, ScreenGeometry.minPanelWidth), maxAllowed)
        self.panelWidth = clamped
        ScreenGeometry.userPanelWidth = clamped
        DragSessionManager.shared.panelController?.updatePanelWidth(clamped)
    }

    public func resetPanelWidth() {
        updatePanelWidth(ScreenGeometry.defaultExpandedWidth)
    }

    public func dragDetected(on screenName: String) {
        isDragActive = true
        dragState = .dragDetected(screen: screenName)
        showPanel()
    }

    public func dragHoverCategory(id: UUID?) {
        activeHoverCategoryID = id
        if let id = id {
            dragState = .dragOverCategory(categoryID: id)
            // Auto-expand collapsed board on hover
            if let idx = categories.firstIndex(where: { $0.id == id }), !categories[idx].isExpanded {
                categories[idx].isExpanded = true
                Task {
                    try? await self.environment.categoryRepository.toggleExpansion(id: id, isExpanded: true)
                }
            }
        } else if isPanelVisible {
            dragState = .drawerExpanded
        }
    }

    public func dragHoverBoard(id: UUID?) {
        dragHoverCategory(id: id)
    }

    public func dragSessionEnded() {
        isDragActive = false
        activeHoverCategoryID = nil
        if case .confirmation = dragState {
            // Keep confirmation visible briefly
            return
        }
        hidePanel()
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
        return try await createBoard(name: name, hexColor: hexColor, isExpanded: false)
    }

    public func createBoard(name: String, hexColor: String, isExpanded: Bool = false) async throws -> Board {
        let created = try await environment.categoryRepository.createCategory(name: name, hexColor: hexColor)
        var board = created
        if board.isExpanded != isExpanded {
            board.isExpanded = isExpanded
            try? await environment.categoryRepository.toggleExpansion(id: board.id, isExpanded: isExpanded)
        }
        self.categories.append(board)
        self.itemsByCategory[board.id] = []
        return board
    }

    public func updateCategory(_ category: CollectionCategory) async throws {
        try await updateBoard(category)
    }

    public func updateBoard(_ board: Board) async throws {
        try await environment.categoryRepository.updateCategory(board)
        if let idx = categories.firstIndex(where: { $0.id == board.id }) {
            categories[idx] = board
        }
    }

    public func deleteCategory(id: UUID) async throws {
        try await deleteBoard(id: id)
    }

    public func deleteBoard(id: UUID) async throws {
        try await environment.categoryRepository.deleteCategory(id: id)
        categories.removeAll { $0.id == id }
        itemsByCategory.removeValue(forKey: id)
        if creatingBoardID == id {
            creatingBoardID = nil
            pendingDropPayloads = nil
        }
        if editingBoardID == id {
            editingBoardID = nil
        }
        if boardPendingDeletion?.id == id {
            boardPendingDeletion = nil
        }
    }

    public func toggleCategoryExpansion(id: UUID) async {
        await toggleBoardExpansion(id: id)
    }

    public func toggleBoardExpansion(id: UUID) async {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isExpanded.toggle()
        let newState = categories[idx].isExpanded
        Task {
            try? await self.environment.categoryRepository.toggleExpansion(id: id, isExpanded: newState)
        }
    }

    public func expandBoard(id: UUID) async {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        if !categories[idx].isExpanded {
            categories[idx].isExpanded = true
            Task {
                try? await self.environment.categoryRepository.toggleExpansion(id: id, isExpanded: true)
            }
        }
    }

    // MARK: - Drop & Ingestion Handling

    public func handleDrop(pasteboard: NSPasteboard, into categoryID: UUID) async {
        AppLogger.drag.info("Handling drop on category \(categoryID.uuidString)")
        dragState = .itemDropped(categoryID: categoryID)
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

            // Enter confirmation state to give visual success feedback
            dragState = .confirmation(categoryID: categoryID)
            try? await Task.sleep(nanoseconds: 800_000_000) // 800ms confirmation window
            hidePanel()
        } catch {
            AppLogger.drag.error("Failed to ingest dropped items: \(error.localizedDescription)")
            self.errorMessage = "Failed to ingest drop: \(error.localizedDescription)"
            dragState = .drawerExpanded
        }
    }

    /// Handles drop onto an empty sidebar area or without targeting an existing board,
    /// extracting payloads and initiating the interactive board creation flow.
    public func handleDropWithoutTarget(pasteboard: NSPasteboard) async {
        AppLogger.drag.info("Handling drop without targeted board; initiating automatic board creation")
        cancelDismissalCountdown()
        do {
            let payloads = try await environment.dragIngestionService.extractPayloads(from: pasteboard)
            guard !payloads.isEmpty else {
                AppLogger.drag.warning("No payloads extracted from untargeted drop")
                return
            }

            // Cleanly abort any previous in-flight creation
            if let existingID = creatingBoardID {
                await cancelBoardCreation(id: existingID)
            }

            self.pendingDropPayloads = payloads
            _ = await createNewBoardInteractive()
        } catch {
            AppLogger.drag.error("Failed to extract payloads for untargeted drop: \(error.localizedDescription)")
            self.errorMessage = "Failed to extract dropped items: \(error.localizedDescription)"
        }
    }

    /// Commits the newly created board with the specified name and colour,
    /// and ingests any pending dropped payload(s) into this new board.
    public func commitBoardCreation(id: UUID, name: String) async {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else {
            creatingBoardID = nil
            editingBoardID = nil
            isEditingBoard = false
            pendingDropPayloads = nil
            return
        }

        var updated = categories[idx]
        updated.name = name
        updated.updatedAt = Date()
        try? await updateBoard(updated)

        let isCreatingThis = (creatingBoardID == id)
        let payloads = self.pendingDropPayloads ?? []
        self.pendingDropPayloads = nil
        self.creatingBoardID = nil
        self.editingBoardID = nil
        self.isEditingBoard = false

        if isCreatingThis && !payloads.isEmpty {
            AppLogger.drag.info("Ingesting \(payloads.count) pending payload(s) into newly created board '\(name)'")
            for payload in payloads {
                do {
                    let item = try await environment.dragIngestionService.ingest(payload: payload, into: id)
                    try await environment.collectionRepository.saveItem(item)

                    if var list = itemsByCategory[id] {
                        list.insert(item, at: 0)
                        itemsByCategory[id] = list
                    } else {
                        itemsByCategory[id] = [item]
                    }

                    if let bIdx = categories.firstIndex(where: { $0.id == id }) {
                        categories[bIdx].itemCount += 1
                    }
                } catch {
                    AppLogger.drag.error("Failed to ingest payload into new board: \(error.localizedDescription)")
                }
            }

            // Ensure board is expanded to display the new item(s) inside it
            await expandBoard(id: id)

            // Visual confirmation feedback
            dragState = .confirmation(categoryID: id)
            try? await Task.sleep(nanoseconds: 800_000_000)
            if case .confirmation(let cID) = dragState, cID == id {
                dragState = .drawerExpanded
            }
        }
    }

    /// Cancels in-flight board creation, discarding pending payloads and deleting the temporary board.
    public func cancelBoardCreation(id: UUID) async {
        AppLogger.drag.info("Cancelling board creation for board \(id.uuidString)")
        self.pendingDropPayloads = nil
        let isCreatingThis = (creatingBoardID == id)
        self.creatingBoardID = nil
        self.editingBoardID = nil
        self.isEditingBoard = false

        if isCreatingThis {
            try? await deleteBoard(id: id)
        }
    }

    // MARK: - Item Interactions, Export, Quick Look & Selection

    public func selectItem(_ id: UUID, toggle: Bool = false) {
        if toggle {
            selectedItemIDs.formSymmetricDifference([id])
        } else {
            selectedItemIDs = [id]
        }
    }

    public func clearSelection() {
        selectedItemIDs.removeAll()
    }

    public func openItem(_ item: CollectionItem) {
        ItemExportService.shared.openItem(item)
    }

    public func revealInFinder(_ item: CollectionItem) {
        ItemExportService.shared.revealInFinder(item)
    }

    public func copyItem(_ item: CollectionItem) {
        ItemExportService.shared.copyToPasteboard(items: [item])
    }

    public func copyItemFile(_ item: CollectionItem) {
        ItemExportService.shared.copyFileReference(item: item)
    }

    public func copySelectedItems() {
        let allItems = itemsByCategory.values.flatMap { $0 }
        let selected = allItems.filter { selectedItemIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        ItemExportService.shared.copyToPasteboard(items: selected)
    }

    public func quickLookItem(_ item: CollectionItem) {
        if let url = ItemExportService.shared.resolveFileURL(for: item) {
            QuickLookCoordinator.shared.toggleQuickLook(for: [url])
        }
    }

    public func quickLookSelectedItems() {
        let allItems = itemsByCategory.values.flatMap { $0 }
        let selected = allItems.filter { selectedItemIDs.contains($0.id) }
        let urls = selected.compactMap { ItemExportService.shared.resolveFileURL(for: $0) }
        QuickLookCoordinator.shared.toggleQuickLook(for: urls)
    }

    public func pasteFromClipboard(into categoryID: UUID? = nil) async {
        guard let targetID = categoryID ?? activeHoverCategoryID ?? boards.first?.id else { return }
        await handleDrop(pasteboard: NSPasteboard.general, into: targetID)
    }

    public func deleteItem(id: UUID, categoryID: UUID) async {
        do {
            try await environment.collectionRepository.deleteItem(id: id)
            if var list = itemsByCategory[categoryID] {
                list.removeAll { $0.id == id }
                itemsByCategory[categoryID] = list
            }
            selectedItemIDs.remove(id)
            if let idx = categories.firstIndex(where: { $0.id == categoryID }) {
                categories[idx].itemCount = max(0, categories[idx].itemCount - 1)
            }
        } catch {
            AppLogger.persistence.error("Failed to delete item \(id): \(error.localizedDescription)")
        }
    }

    public func deleteSelectedItems() async {
        let idsToDelete = selectedItemIDs
        clearSelection()
        for (catID, items) in itemsByCategory {
            for item in items where idsToDelete.contains(item.id) {
                await deleteItem(id: item.id, categoryID: catID)
            }
        }
    }
}
