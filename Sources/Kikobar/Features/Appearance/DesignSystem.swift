import SwiftUI

/// Shared typography, spacing, corner radii, and animation constants.
public enum DesignSystem {
    public enum CornerRadius {
        public static let small: CGFloat = 6.0
        public static let medium: CGFloat = 10.0
        public static let large: CGFloat = 14.0
        public static let panel: CGFloat = 18.0
    }

    public enum Spacing {
        public static let xxs: CGFloat = 2.0
        public static let xs: CGFloat = 4.0
        public static let small: CGFloat = 8.0
        public static let medium: CGFloat = 12.0
        public static let large: CGFloat = 16.0
        public static let xl: CGFloat = 24.0
    }

    public enum Animation {
        public static let slideIn: SwiftUI.Animation = .spring(response: 0.30, dampingFraction: 0.82)
        public static let slideOut: SwiftUI.Animation = .easeInOut(duration: 0.22)
        public static let hoverHighlight: SwiftUI.Animation = .easeInOut(duration: 0.15)
        public static let expansion: SwiftUI.Animation = .easeInOut(duration: 0.22)
    }
}
