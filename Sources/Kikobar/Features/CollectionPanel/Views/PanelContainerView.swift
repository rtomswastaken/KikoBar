import SwiftUI

/// Root SwiftUI container view rendered inside the floating collection panel.
public struct PanelContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator
        self.themeManager = themeManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 10) {
                // Brand pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeManager.accentColor)
                        .frame(width: 8, height: 8)
                    Text("Kikobar")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.primaryTextColor)
                }

                Spacer()

                // Theme Switcher Button
                ThemeToggleView(themeManager: themeManager)

                // Close Button
                Button(action: {
                    coordinator.hidePanel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Close drawer (Esc)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(themeManager.cardBackground)

            Divider()
                .background(themeManager.borderColor)

            // Optional Error Banner
            if let error = coordinator.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Dismiss") {
                        coordinator.errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                }
                .padding(8)
                .background(Color.yellow.opacity(0.15))
            }

            // Scrollable Category List
            CategoryListView(coordinator: coordinator, themeManager: themeManager)
                .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 320, maxWidth: 380, minHeight: 480, maxHeight: 720)
        .background(themeManager.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: -4, y: 4)
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
    }
}
