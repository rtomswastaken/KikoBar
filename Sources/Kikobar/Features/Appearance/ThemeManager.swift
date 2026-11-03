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
            return HexColor.toColor(hex: "#161618")
        case .light:
            return HexColor.toColor(hex: "#F5F5F7")
        }
    }

    public var cardBackground: Color {
        switch currentTheme {
        case .dark:
            return HexColor.toColor(hex: "#202024")
        case .light:
            return Color.white
        }
    }

    public var borderColor: Color {
        switch currentTheme {
        case .dark:
            return HexColor.toColor(hex: "#2E2E34")
        case .light:
            return HexColor.toColor(hex: "#E0E0E6")
        }
    }

    public var primaryTextColor: Color {
        switch currentTheme {
        case .dark:
            return HexColor.toColor(hex: "#EEEEF0")
        case .light:
            return HexColor.toColor(hex: "#1C1C1E")
        }
    }

    public var secondaryTextColor: Color {
        switch currentTheme {
        case .dark:
            return HexColor.toColor(hex: "#98989F")
        case .light:
            return HexColor.toColor(hex: "#6C6C72")
        }
    }

    public var accentColor: Color {
        return HexColor.toColor(hex: "#8B7CFF")
    }
}
