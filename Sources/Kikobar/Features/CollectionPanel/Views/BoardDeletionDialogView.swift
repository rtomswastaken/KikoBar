import SwiftUI

/// In-app board deletion confirmation dialog matching Kikobar's design system and theme.
public struct BoardDeletionDialogView: View {
    public let board: Board
    public let itemCount: Int
    @ObservedObject var themeManager: ThemeManager
    public let onCancel: () -> Void
    public let onConfirm: () -> Void

    @State private var isDeleteHovered: Bool = false
    @State private var isCancelHovered: Bool = false

    public init(
        board: Board,
        itemCount: Int,
        themeManager: ThemeManager,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.board = board
        self.itemCount = itemCount
        self.themeManager = themeManager
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Trash Icon Badge
            ZStack {
                Circle()
                    .fill(Color.red.opacity(themeManager.currentTheme == .dark ? 0.22 : 0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.red.opacity(0.95))
            }
            .padding(.top, 4)

            // Header Title
            VStack(spacing: 4) {
                Text("Delete '\(board.name)'?")
                    .font(KikobarFont.bold(size: 13))
                    .foregroundColor(themeManager.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(itemCount == 0 ? "This board is empty and will be removed." : "This will remove '\(board.name)' and its \(itemCount) collected item\(itemCount == 1 ? "" : "s").")
                    .font(KikobarFont.regular(size: 11))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)
            }
            .padding(.horizontal, 4)

            // Action Buttons
            VStack(spacing: 7) {
                // Destructive Delete Button
                Button(action: onConfirm) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                        Text("Delete Board")
                            .font(KikobarFont.bold(size: 12))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDeleteHovered ? Color.red : Color.red.opacity(0.88))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isDeleteHovered = $0 }

                // Cancel Button
                Button(action: onCancel) {
                    HStack {
                        Spacer()
                        Text("Cancel")
                            .font(KikobarFont.medium(size: 12))
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                    }
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(isCancelHovered ? (themeManager.currentTheme == .dark ? 0.14 : 0.09) : (themeManager.currentTheme == .dark ? 0.08 : 0.05)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.borderColor, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isCancelHovered = $0 }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 216)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeManager.currentTheme == .dark ? Color(white: 0.14) : Color(white: 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.45 : 0.2), radius: 16, x: 0, y: 6)
    }
}
