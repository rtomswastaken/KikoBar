import SwiftUI

/// Bottom controls bar: Plus (+), Sun/Moon appearance toggle, and 'kikobar.' logo.
public struct BottomControlsBar: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator
        self.themeManager = themeManager
    }

    private var iconColor: Color {
        themeManager.iconColor
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Plus (+) Button: Creates a new board and focuses inline title editing
            Button(action: createNewBoard) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Create New Board")

            // Sun / Moon Button: Toggles Light and Dark theme
            Button(action: toggleTheme) {
                Image(systemName: themeManager.currentTheme == .dark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(themeManager.currentTheme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode")

            Spacer()

            // "kikobar." logo in lowercase Poppins
            Text("kikobar.")
                .font(KikobarFont.bold(size: 12))
                .foregroundColor(iconColor)
                .tracking(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.panelBackground)
        .animation(DesignSystem.Animation.themeSwitch, value: themeManager.currentTheme)
    }

    private func createNewBoard() {
        coordinator.cancelDismissalCountdown()
        Task {
            _ = await coordinator.createNewBoardInteractive()
        }
    }

    private func toggleTheme() {
        coordinator.cancelDismissalCountdown()
        withAnimation(DesignSystem.Animation.themeSwitch) {
            themeManager.toggleTheme()
        }
    }
}
