import AppKit
import Foundation

/// Geometry helper for positioning floating panels and edge trigger zones across multi-monitor setups.
public struct ScreenGeometry: Sendable {
    /// Default widths and dimensions
    public static let triggerWidth: CGFloat = 20.0
    public static let defaultPanelWidth: CGFloat = 340.0

    /// Returns the screen that contains the given point in global Cocoa screen coordinates.
    public static func screen(containing point: CGPoint) -> NSScreen {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    /// Calculates the trigger zone frame on a specific screen (top-right quadrant).
    public static func triggerFrame(for screen: NSScreen, heightRatio: CGFloat = 0.40) -> CGRect {
        let visible = screen.visibleFrame
        let height = max(240.0, visible.height * heightRatio)
        let x = visible.maxX - triggerWidth
        let y = visible.maxY - height
        return CGRect(x: x, y: y, width: triggerWidth, height: height)
    }

    /// Calculates the visible frame of the collection panel when extended.
    public static func panelExpandedFrame(for screen: NSScreen, width: CGFloat = defaultPanelWidth) -> CGRect {
        let visible = screen.visibleFrame
        let height = min(720.0, visible.height - 40.0)
        let x = visible.maxX - width - 12.0
        let y = visible.maxY - height - 12.0
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Calculates the hidden/retracted frame of the collection panel (tucked just off-screen).
    public static func panelRetractedFrame(for screen: NSScreen, width: CGFloat = defaultPanelWidth) -> CGRect {
        var frame = panelExpandedFrame(for: screen, width: width)
        frame.origin.x = screen.frame.maxX + 10.0
        return frame
    }
}
