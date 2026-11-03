import AppKit
import SwiftUI

/// Board container with individual color customization, title editing, and deletion controls.
public struct BoardCardView: View {
    public let board: Board
    public let items: [CollectionItem]
    @ObservedObject var coordinator: AppCoordinator

    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var isHeaderHovered: Bool = false
    @State private var showColorPicker: Bool = false
    @State private var showCreationColorPicker: Bool = false
    @FocusState private var isTitleFocused: Bool

    public init(
        board: Board,
        items: [CollectionItem],
        coordinator: AppCoordinator
    ) {
        self.board = board
        self.items = items
        self.coordinator = coordinator
    }

    private var isCreating: Bool {
        coordinator.creatingBoardID == board.id
    }

    private var boardColor: Color {
        HexColor.toColor(hex: board.hexColor)
    }

    private var isConfirmed: Bool {
        if case .confirmation(let id) = coordinator.dragState, id == board.id {
            return true
        }
        return false
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Row: [ Board Name ] [ Colour Indicator ] [ Expand/Collapse Arrow ]
            headerView

            // Content Area when expanded
            if board.isExpanded {
                VStack(spacing: 0) {
                    BoardMediaGridView(items: items, coordinator: coordinator) { item in
                        coordinator.openItem(item)
                    }

                    // Board Controls: Paint Button & Delete Board Button
                    HStack(spacing: 6) {
                        Spacer()

                        // Color / Paint Button (specific to this board)
                        Button(action: {
                            coordinator.cancelDismissalCountdown()
                            showColorPicker.toggle()
                        }) {
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.black.opacity(0.18))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showColorPicker, arrowEdge: .trailing) {
                            BoardColorPickerPopover(currentHex: board.hexColor) { newHex in
                                updateBoardColor(newHex: newHex)
                                showColorPicker = false
                            }
                        }
                        .help("Change Board Color")

                        // Delete Board Button (immediately beside paint button, visually distinct)
                        Button(action: {
                            coordinator.cancelDismissalCountdown()
                            withAnimation(.easeInOut(duration: 0.18)) {
                                coordinator.boardPendingDeletion = board
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.9))
                                .frame(width: 22, height: 22)
                                .background(Color.red.opacity(0.35))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Board")
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(boardColor)
        .cornerRadius(11)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(isDropTargeted ? Color.white : Color.clear, lineWidth: 2)
        )
        .animation(DesignSystem.Animation.boardExpansion, value: board.isExpanded)
        .animation(DesignSystem.Animation.colorChange, value: board.hexColor)
        .animation(DesignSystem.Animation.hoverFeedback, value: isDropTargeted)
        // Auto-expand on drag enter and accept drops
        .onDrop(of: [.item, .fileURL, .url, .utf8PlainText], isTargeted: $isDropTargeted) { _ in
            let dragPasteboard = NSPasteboard(name: .drag)
            let pasteboardToUse = (dragPasteboard.types?.isEmpty ?? true) ? NSPasteboard.general : dragPasteboard
            DragSessionManager.shared.itemDropped(onBoardID: board.id, pasteboard: pasteboardToUse)
            return true
        }
        .onChange(of: isDropTargeted) { _, targeted in
            if targeted {
                DragSessionManager.shared.dragEnteredBoard(id: board.id)
                coordinator.dragHoverBoard(id: board.id)
                if !board.isExpanded {
                    Task {
                        await coordinator.expandBoard(id: board.id)
                    }
                }
            } else if DragSessionManager.shared.isDragSessionActive && DragSessionManager.shared.activeBoardID == board.id {
                DragSessionManager.shared.dragExitedBoard()
            }
        }
        .onAppear {
            if coordinator.editingBoardID == board.id {
                beginTitleEdit()
            }
        }
        .onChange(of: coordinator.editingBoardID) { _, newID in
            if newID == board.id && !isEditingTitle {
                beginTitleEdit()
            }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused && isEditingTitle && !showCreationColorPicker {
                commitTitleEdit()
            }
        }
    }

    // MARK: - Header View: [ Board Name ] [ Optional Creation Colour Selector ] [ Expand/Collapse Arrow ]

    private var headerView: some View {
        HStack(spacing: 8) {
            // [ Board Name / Title Editing ]
            if isEditingTitle {
                TextField("Board Name", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(KikobarFont.bold(size: 13))
                    .foregroundColor(.white)
                    .focused($isTitleFocused)
                    .onSubmit {
                        commitTitleEdit()
                    }
                    .onExitCommand {
                        cancelTitleEdit()
                    }

                if isCreating {
                    // Circular colour selector displayed ONLY during board creation next to board title
                    Button(action: {
                        coordinator.cancelDismissalCountdown()
                        showCreationColorPicker.toggle()
                    }) {
                        Circle()
                            .fill(boardColor)
                            .frame(width: 13, height: 13)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Select Board Color")
                    .popover(isPresented: $showCreationColorPicker, arrowEdge: .trailing) {
                        BoardColorPickerPopover(currentHex: board.hexColor) { newHex in
                            updateBoardColor(newHex: newHex)
                            showCreationColorPicker = false
                        }
                    }
                }
            } else {
                Text(board.name.lowercased())
                    .font(KikobarFont.bold(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        beginTitleEdit()
                    }
            }

            Spacer()

            if isCreating {
                HStack(spacing: 6) {
                    // Create / Confirm action
                    Button(action: {
                        commitTitleEdit()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Create Board")

                    // Cancel action
                    Button(action: {
                        cancelTitleEdit()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                }
            } else if isConfirmed {
                Text("✓")
                    .font(KikobarFont.bold(size: 13))
                    .foregroundColor(.white)
                    .transition(.opacity)
            } else {
                // [ Expand/Collapse Arrow only — NO persistent colour selector ]
                Button(action: {
                    coordinator.cancelDismissalCountdown()
                    Task {
                        await coordinator.toggleBoardExpansion(id: board.id)
                    }
                }) {
                    Image(systemName: board.isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(isHeaderHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverFeedback) {
                isHeaderHovered = hovering
            }
        }
        .onTapGesture {
            guard !isEditingTitle else { return }
            coordinator.cancelDismissalCountdown()
            Task {
                await coordinator.toggleBoardExpansion(id: board.id)
            }
        }
    }

    // MARK: - Actions

    private func beginTitleEdit() {
        editedTitle = board.name
        isEditingTitle = true
        coordinator.isEditingBoard = true
        coordinator.cancelDismissalCountdown()
        // Focus title field on next tick
        DispatchQueue.main.async {
            isTitleFocused = true
        }
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingTitle = false
        showCreationColorPicker = false

        let finalName = trimmed.isEmpty ? "new board" : trimmed
        let boardID = board.id

        Task {
            await coordinator.commitBoardCreation(id: boardID, name: finalName)
        }
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        showCreationColorPicker = false

        let boardID = board.id
        Task {
            await coordinator.cancelBoardCreation(id: boardID)
        }
    }

    private func updateBoardColor(newHex: String) {
        var updated = board
        updated.hexColor = newHex
        updated.updatedAt = Date()
        Task {
            try? await coordinator.updateBoard(updated)
        }
    }
}
