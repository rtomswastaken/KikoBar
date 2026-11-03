import SwiftUI

/// Floating vertical collection side panel containing stacked Boards with full Dark/Light theme support.
public struct RightSidebarView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager
    @State private var isSidebarDropTargeted: Bool = false

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator
        self.themeManager = themeManager
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left-edge draggable resize divider handle
            ResizeHandleView(coordinator: coordinator, themeManager: themeManager)

            // Main Collection Drawer Content
            ZStack {
                VStack(spacing: 0) {
                    if coordinator.boards.isEmpty {
                    // Empty state when there are no user boards yet
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 26, weight: .light))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("No Boards")
                            .font(KikobarFont.bold(size: 13))
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("Click + below to create a board")
                            .font(KikobarFont.regular(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                } else {
                    // Scrollable Stack of Boards
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 7) {
                            ForEach(coordinator.boards) { board in
                                BoardCardView(
                                    board: board,
                                    items: coordinator.itemsByBoard[board.id] ?? [],
                                    coordinator: coordinator
                                )
                            }
                        }
                        .animation(DesignSystem.Animation.boardCreation, value: coordinator.boards)
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom Controls Bar
                BottomControlsBar(coordinator: coordinator, themeManager: themeManager)
            }

            // In-app board deletion confirmation prompt
            if let boardToDelete = coordinator.boardPendingDeletion {
                Color.black.opacity(themeManager.currentTheme == .dark ? 0.6 : 0.35)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            coordinator.boardPendingDeletion = nil
                        }
                    }

                BoardDeletionDialogView(
                    board: boardToDelete,
                    itemCount: (coordinator.itemsByBoard[boardToDelete.id] ?? []).count,
                    themeManager: themeManager,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            coordinator.boardPendingDeletion = nil
                        }
                    },
                    onConfirm: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            let id = boardToDelete.id
                            coordinator.boardPendingDeletion = nil
                            Task {
                                try? await coordinator.deleteBoard(id: id)
                            }
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(100)
            }
            }
        }
        .frame(width: coordinator.panelWidth)
        .frame(maxHeight: .infinity)
        .background(themeManager.panelBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .stroke(themeManager.borderColor, lineWidth: 1)
        )
        .onHover { isHovering in
            if isHovering {
                coordinator.cancelDismissalCountdown()
            } else {
                coordinator.startDismissalCountdown()
            }
        }
        .onDrop(of: [.item, .fileURL, .url, .utf8PlainText], isTargeted: $isSidebarDropTargeted) { _ in
            let dragPasteboard = NSPasteboard(name: .drag)
            let pasteboardToUse = (dragPasteboard.types?.isEmpty ?? true) ? NSPasteboard.general : dragPasteboard

            if let targetBoardID = DragSessionManager.shared.activeBoardID ?? coordinator.activeHoverCategoryID {
                DragSessionManager.shared.itemDropped(onBoardID: targetBoardID, pasteboard: pasteboardToUse)
                return true
            } else {
                DragSessionManager.shared.itemDroppedWithoutTarget(pasteboard: pasteboardToUse)
                return true
            }
        }
        .onChange(of: isSidebarDropTargeted) { _, targeted in
            if targeted {
                DragSessionManager.shared.cancelDismissal()
            }
        }
        .onKeyPress(.space) {
            coordinator.quickLookSelectedItems()
            return .handled
        }
        .onKeyPress(.return) {
            if let firstID = coordinator.selectedItemIDs.first,
               let item = coordinator.itemsByBoard.values.flatMap({ $0 }).first(where: { $0.id == firstID }) {
                coordinator.openItem(item)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            Task {
                await coordinator.deleteSelectedItems()
            }
            return .handled
        }
        .animation(DesignSystem.Animation.themeSwitch, value: themeManager.currentTheme)
    }
}
