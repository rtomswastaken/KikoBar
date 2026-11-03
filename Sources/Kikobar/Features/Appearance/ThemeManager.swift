import SwiftUI

/// Default implementation of ThemeManagerProtocol supporting seamless Dark/Light switching.
@MainActor
public final class ThemeManager: ThemeManagerProtocol, ObservableObject {
    private let userDefaults: UserDefaults
    private static let themeKey = "kikobar.themeMode"

    @Published public var currentTheme: AppThemeMode {
        didSet {
            userDefaults.set(currentTheme.rawValue, forKey: Self.themeKey)
        }
    }

    public init(initialMode: AppThemeMode = .dark, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let saved = userDefaults.string(forKey: Self.themeKey),
           let mode = AppThemeMode(rawValue: saved) {
            self.currentTheme = mode
        } else {
            self.currentTheme = initialMode
        }
    }

    public func toggleTheme() {
        currentTheme = (currentTheme == .dark) ? .light : .dark
    }

    public var panelBackground: Color {
        switch currentTheme {
        case .dark:
            return Color.black
        case .light:
            return Color.white
        }
    }

    public var cardBackground: Color {
        switch currentTheme {
        case .dark:
            return Color.black
        case .light:
            return Color.white
        }
    }

    public var borderColor: Color {
        switch currentTheme {
        case .dark:
            return Color(white: 0.15)
        case .light:
            return Color(white: 0.86)
        }
    }

    public var primaryTextColor: Color {
        switch currentTheme {
        case .dark:
            return Color.white
        case .light:
            return Color.black
        }
    }

    public var secondaryTextColor: Color {
        switch currentTheme {
        case .dark:
            return Color(white: 0.50)
        case .light:
            return Color(white: 0.40)
        }
    }

    public var iconColor: Color {
        switch currentTheme {
        case .dark:
            return Color.white
        case .light:
            return Color.black
        }
    }

    public var accentColor: Color {
        switch currentTheme {
        case .dark:
            return Color.white
        case .light:
            return Color.black
        }
    }
}
