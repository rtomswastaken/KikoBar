import SwiftUI

/// Defines the appearance mode (Dark or Light).
public enum AppThemeMode: String, Codable, CaseIterable, Sendable {
    case dark
    case light
}

/// Defines the interface for application-wide theme and color styling.
@MainActor
public protocol ThemeManagerProtocol: AnyObject {
    /// Active theme mode (defaults to dark).
    var currentTheme: AppThemeMode { get set }

    /// Toggles between dark and light appearance.
    func toggleTheme()

    /// Background color for the collection panel.
    var panelBackground: Color { get }

    /// Surface color for category containers.
    var cardBackground: Color { get }

    /// Subtle border color for separators and outlines.
    var borderColor: Color { get }

    /// Primary foreground text color.
    var primaryTextColor: Color { get }

    /// Secondary foreground text color.
    var secondaryTextColor: Color { get }

    /// Accent highlight color.
    var accentColor: Color { get }
}
