import SwiftUI

/// Thumbnail and metadata preview for an individual collection item.
public struct ItemThumbnailView: View {
    public let item: CollectionItem
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    @State private var isHovered: Bool = false

    public init(item: CollectionItem, coordinator: AppCoordinator, themeManager: ThemeManager? = nil) {
        self.item = item
        self.coordinator = coordinator
        self.themeManager = themeManager ?? (coordinator.environment.themeManager as? ThemeManager) ?? ThemeManager()
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Icon / Preview representation
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: item.contentType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(themeManager.primaryTextColor)

                HStack(spacing: 4) {
                    Text(item.contentType.rawValue.capitalized)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.secondaryTextColor)

                    if !item.isSourceAvailable {
                        Text("• Missing source")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Open Button
            Button(action: {
                coordinator.openItem(item)
            }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? themeManager.primaryTextColor : themeManager.secondaryTextColor)
            }
            .buttonStyle(.plain)
            .help("Open in default application")

            // Delete item button
            Button(action: {
                Task {
                    await coordinator.deleteItem(id: item.id, categoryID: item.categoryID)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Remove from collection")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? themeManager.cardBackground : themeManager.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? themeManager.accentColor.opacity(0.4) : themeManager.borderColor.opacity(0.5), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverHighlight) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            coordinator.openItem(item)
        }
    }
}
