import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Thumbnail card rendering collected user files, images, documents, URLs, and snippets.
/// Supports two-way drag-and-drop to Finder/Desktop, multi-selection, context menus, and native previews.
public struct BoardMediaCardView: View {
    public let item: CollectionItem
    public let style: CardStyle
    public var isSelected: Bool
    public var onSelect: ((Bool) -> Void)?
    public var onOpen: (() -> Void)?
    public var onQuickLook: (() -> Void)?
    public var onCopy: (() -> Void)?
    public var onCopyFile: (() -> Void)?
    public var onRevealInFinder: (() -> Void)?
    public var onDelete: (() -> Void)?

    @State private var isHovered: Bool = false

    public enum CardStyle {
        case fullWidth
        case gridItem

        var height: CGFloat {
            switch self {
            case .fullWidth: return 100
            case .gridItem: return 80
            }
        }
    }

    public init(
        item: CollectionItem,
        style: CardStyle,
        isSelected: Bool = false,
        onSelect: ((Bool) -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onQuickLook: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil,
        onCopyFile: (() -> Void)? = nil,
        onRevealInFinder: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.style = style
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onOpen = onOpen
        self.onQuickLook = onQuickLook
        self.onCopy = onCopy
        self.onCopyFile = onCopyFile
        self.onRevealInFinder = onRevealInFinder
        self.onDelete = onDelete
    }

    public var body: some View {
        Group {
            if item.contentType == .image, let image = loadItemImage() {
                // Real Image Preview
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: style.height)
                    .clipped()
            } else {
                // Document / URL / Text Snippet / File representation
                genericFileCard
            }
        }
        .frame(height: style.height)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white : (isHovered ? Color.white.opacity(0.4) : Color.black.opacity(0.12)), lineWidth: isSelected ? 2 : (isHovered ? 1 : 0.5))
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverFeedback) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen?()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                let isToggle = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
                onSelect?(isToggle)
            }
        )
        // Two-way Drag Out to Finder, Desktop, or other apps
        .onDrag {
            DragSessionManager.shared.cancelDismissal()
            return ItemExportService.shared.createItemProvider(for: item)
        } preview: {
            dragPreviewView
        }
        // Native macOS Context Menu
        .contextMenu {
            Button(action: { onOpen?() }) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }

            Button(action: { onQuickLook?() }) {
                Label("Quick Look", systemImage: "eye")
            }

            Divider()

            Button(action: { onCopy?() }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button(action: { onCopyFile?() }) {
                Label("Copy File", systemImage: "doc.badge.arrow.up")
            }

            if item.localPath != nil || item.bookmarkData != nil || (item.sourceURL?.isFileURL ?? false) {
                Button(action: { onRevealInFinder?() }) {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }

            Divider()

            Button(role: .destructive, action: { onDelete?() }) {
                Label("Remove from Board", systemImage: "trash")
            }
        }
        .help("\(item.name)\nDouble-click to open • Space for Quick Look • Drag to export")
    }

    private func loadItemImage() -> NSImage? {
        if let fileURL = ItemExportService.shared.resolveFileURL(for: item) {
            return NSImage(contentsOfFile: fileURL.path)
        }
        return nil
    }

    @ViewBuilder
    private var dragPreviewView: some View {
        HStack(spacing: 8) {
            Image(systemName: item.contentType.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(item.name)
                .font(KikobarFont.medium(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
        .shadow(radius: 4)
    }

    @ViewBuilder
    private var genericFileCard: some View {
        ZStack {
            Color.white.opacity(0.92)

            VStack(spacing: 4) {
                Image(systemName: item.contentType.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(white: 0.25))

                Text(item.name)
                    .font(KikobarFont.medium(size: 10))
                    .foregroundColor(Color(white: 0.2))
                    .lineLimit(style == .fullWidth ? 2 : 1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                if item.contentType == .url, let url = item.sourceURL {
                    Text(url.host ?? url.absoluteString)
                        .font(KikobarFont.regular(size: 8))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(1)
                }
            }
            .padding(4)
        }
    }
}

/// Compact grid layout inside an expanded board rendering actual user-added content without placeholders.
public struct BoardMediaGridView: View {
    public let items: [CollectionItem]
    public let coordinator: AppCoordinator
    public var onOpenItem: ((CollectionItem) -> Void)?

    public init(
        items: [CollectionItem],
        coordinator: AppCoordinator,
        onOpenItem: ((CollectionItem) -> Void)? = nil
    ) {
        self.items = items
        self.coordinator = coordinator
        self.onOpenItem = onOpenItem
    }

    public var body: some View {
        VStack(spacing: 6) {
            if items.isEmpty {
                // Clean empty drop state for new or empty boards
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(Color.white.opacity(0.65))
                    Text("Drop files here")
                        .font(KikobarFont.medium(size: 11))
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.black.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            } else {
                // Adaptively lay out actual user-added content
                if items.count == 1 {
                    cardView(for: items[0], style: .fullWidth)
                        .padding(.horizontal, 6)
                } else {
                    // First item full-width
                    cardView(for: items[0], style: .fullWidth)
                        .padding(.horizontal, 6)

                    // Remaining items in 2-column grid
                    let remaining = Array(items.dropFirst())
                    let chunks = stride(from: 0, to: remaining.count, by: 2).map {
                        Array(remaining[$0..<min($0 + 2, remaining.count)])
                    }

                    ForEach(0..<chunks.count, id: \.self) { chunkIndex in
                        let pair = chunks[chunkIndex]
                        HStack(spacing: 6) {
                            cardView(for: pair[0], style: .gridItem)
                            if pair.count == 2 {
                                cardView(for: pair[1], style: .gridItem)
                            } else {
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
        }
        .animation(DesignSystem.Animation.itemInsertion, value: items.count)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func cardView(for item: CollectionItem, style: BoardMediaCardView.CardStyle) -> some View {
        BoardMediaCardView(
            item: item,
            style: style,
            isSelected: coordinator.selectedItemIDs.contains(item.id),
            onSelect: { toggle in
                coordinator.selectItem(item.id, toggle: toggle)
            },
            onOpen: {
                if let onOpenItem = onOpenItem {
                    onOpenItem(item)
                } else {
                    coordinator.openItem(item)
                }
            },
            onQuickLook: {
                coordinator.quickLookItem(item)
            },
            onCopy: {
                coordinator.copyItem(item)
            },
            onCopyFile: {
                coordinator.copyItemFile(item)
            },
            onRevealInFinder: {
                coordinator.revealInFinder(item)
            },
            onDelete: {
                Task {
                    await coordinator.deleteItem(id: item.id, categoryID: item.categoryID)
                }
            }
        )
    }
}
