import SwiftUI

/// Right-edge drawer container hosting the collection sidebar.
public struct PanelContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    public init(coordinator: AppCoordinator, themeManager: ThemeManager? = nil) {
        self.coordinator = coordinator
        self.themeManager = themeManager ?? (coordinator.environment.themeManager as? ThemeManager) ?? ThemeManager()
    }

    public var body: some View {
        RightSidebarView(coordinator: coordinator, themeManager: themeManager)
            .frame(maxHeight: .infinity)
            .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
    }
}
