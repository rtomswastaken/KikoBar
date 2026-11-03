import SwiftUI

/// Direct dark/light theme switch control accessible directly from the collection panel header.
public struct ThemeToggleView: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var isHovered: Bool = false

    public init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.toggleTheme()
            }
        }) {
            Image(systemName: themeManager.currentTheme == .dark ? "sun.max.fill" : "moon.stars.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme == .dark ? Color.yellow : themeManager.accentColor)
                .frame(width: 26, height: 26)
                .background(isHovered ? themeManager.panelBackground : themeManager.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? themeManager.accentColor.opacity(0.5) : themeManager.borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverHighlight) {
                isHovered = hovering
            }
        }
        .help(themeManager.currentTheme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode")
    }
}
