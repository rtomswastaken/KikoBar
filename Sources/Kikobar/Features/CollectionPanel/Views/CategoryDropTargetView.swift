import SwiftUI

/// Visual drop target indicator providing hover and drop feedback with a tinted glow matching the category's HEX color.
public struct CategoryDropTargetView: View {
    public let category: CollectionCategory
    public let isTargeted: Bool
    @ObservedObject var themeManager: ThemeManager

    public init(category: CollectionCategory, isTargeted: Bool, themeManager: ThemeManager? = nil) {
        self.category = category
        self.isTargeted = isTargeted
        self.themeManager = themeManager ?? ThemeManager()
    }

    public var body: some View {
        let accentColor = HexColor.toColor(hex: category.hexColor)

        HStack(spacing: 8) {
            Spacer()
            Image(systemName: isTargeted ? "plus.circle.fill" : "arrow.down.circle")
                .foregroundColor(accentColor)
                .font(.system(size: 13, weight: .semibold))
                .scaleEffect(isTargeted ? 1.15 : 1.0)

            Text(isTargeted ? "Drop to add to \(category.name)" : "Drop into \(category.name)")
                .font(.system(size: 12, weight: isTargeted ? .bold : .medium))
                .foregroundColor(isTargeted ? accentColor : themeManager.secondaryTextColor)
            Spacer()
        }
        .padding(.vertical, isTargeted ? 10 : 8)
        .background(accentColor.opacity(isTargeted ? 0.22 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    accentColor.opacity(isTargeted ? 1.0 : 0.45),
                    style: StrokeStyle(lineWidth: isTargeted ? 2.0 : 1.2, dash: isTargeted ? [6, 4] : [4, 4])
                )
        )
        .shadow(color: accentColor.opacity(isTargeted ? 0.55 : 0.0), radius: isTargeted ? 10 : 0, x: 0, y: 0)
        .animation(DesignSystem.Animation.hoverHighlight, value: isTargeted)
    }
}
