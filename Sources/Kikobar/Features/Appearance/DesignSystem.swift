import AppKit
import SwiftUI

/// Shared typography, spacing, corner radii, and centralized animation configuration.
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

    /// Centralized animation constants, timing curves, and accessibility Reduce Motion support.
    public enum Animation {
        // MARK: - Timing Durations (Seconds)

        /// Edge activation delay: wait exactly 100ms before starting opening animation (cancels on exit).
        public static let edgeActivationDelay: TimeInterval = 0.10

        /// Sidebar opening duration: 350–450ms (380ms for fluid, natural expansion).
        public static let sidebarOpeningDuration: TimeInterval = 0.38

        /// Sidebar closing duration: 250–300ms (280ms for a swift, smooth exit).
        public static let sidebarClosingDuration: TimeInterval = 0.28

        /// Automatic dismissal delay: exactly 1,000ms (1.0 second).
        public static let autoDismissalDelay: TimeInterval = 1.0

        /// Edge handle fade durations
        public static let edgeHandleFadeInDuration: TimeInterval = 0.18
        public static let edgeHandleFadeOutDuration: TimeInterval = 0.22

        // MARK: - Accessibility Support

        /// Whether macOS Reduce Motion setting is enabled in System Settings.
        public static var shouldReduceMotion: Bool {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }

        // MARK: - AppKit / CoreAnimation Curves (No Overshooting / No Bouncing)

        /// Carefully tuned ease-out curve for sidebar opening (smooth, native feel without bounce).
        public static var sidebarOpeningTiming: CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        }

        /// Slightly quicker ease curve for sidebar closing (smooth exit without abrupt cut).
        public static var sidebarClosingTiming: CAMediaTimingFunction {
            CAMediaTimingFunction(controlPoints: 0.36, 0.0, 0.2, 1.0)
        }

        // MARK: - SwiftUI Animations

        /// Sidebar opening animation
        public static var sidebarOpening: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeOut(duration: sidebarOpeningDuration)
        }

        /// Sidebar closing animation
        public static var sidebarClosing: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeIn(duration: sidebarClosingDuration)
        }

        /// Board expansion and collapse animation (smooth accordion transition)
        public static var boardExpansion: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .spring(response: 0.32, dampingFraction: 0.88)
        }

        /// Board creation animation (smooth insertion into stack)
        public static var boardCreation: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .spring(response: 0.35, dampingFraction: 0.85)
        }

        /// Edge handle appearance animation
        public static var edgeHandleFadeIn: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeOut(duration: edgeHandleFadeInDuration)
        }
        public static var edgeHandleFadeOut: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeIn(duration: edgeHandleFadeOutDuration)
        }

        /// Board hover feedback animation
        public static var hoverFeedback: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.15)
        }

        /// Theme switching animation (dark <-> light mode transition)
        public static var themeSwitch: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.25)
        }

        /// Item insertion after dropping animation
        public static var itemInsertion: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .spring(response: 0.35, dampingFraction: 0.82)
        }

        /// Board colour changes animation
        public static var colorChange: SwiftUI.Animation {
            shouldReduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.22)
        }

        // MARK: - Backward Compatibility Aliases

        public static var slideIn: SwiftUI.Animation { sidebarOpening }
        public static var slideOut: SwiftUI.Animation { sidebarClosing }
        public static var hoverHighlight: SwiftUI.Animation { hoverFeedback }
        public static var expansion: SwiftUI.Animation { boardExpansion }
    }
}
