import AppKit
import Foundation

/// Geometry helper for positioning floating panels and edge trigger zones across multi-monitor setups.
public struct ScreenGeometry: Sendable {
    /// Width constants for the unified vertical drawer
    public static let collapsedWidth: CGFloat = 0.0
    public static let defaultExpandedWidth: CGFloat = 240.0
    public static let minPanelWidth: CGFloat = 180.0
    public static let maxPanelWidth: CGFloat = 700.0

    /// Returns the current user-configured panel width, persisting across sessions in UserDefaults.
    public static var userPanelWidth: CGFloat {
        get {
            let val = UserDefaults.standard.double(forKey: "kikobar.panelWidth")
            if val >= Double(minPanelWidth) && val <= Double(maxPanelWidth) {
                return CGFloat(val)
            }
            return defaultExpandedWidth
        }
        set {
            let clamped = min(max(newValue, minPanelWidth), maxPanelWidth)
            UserDefaults.standard.set(Double(clamped), forKey: "kikobar.panelWidth")
        }
    }

    /// Dynamic expanded width reflecting the user's custom resized width.
    public static var expandedWidth: CGFloat {
        userPanelWidth
    }

    /// Legacy widths for backwards compatibility
    public static let triggerWidth: CGFloat = 20.0
    public static let defaultPanelWidth: CGFloat = 240.0

    /// Returns the screen that contains the given point in global Cocoa screen coordinates.
    public static func screen(containing point: CGPoint) -> NSScreen {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    // MARK: - Full-Height Edge Drawer Geometry

    /// Calculates the full-height collapsed offscreen frame on the right edge of a screen.
    public static func drawerCollapsedFrame(for screen: NSScreen) -> CGRect {
        return drawerCollapsedFrame(forVisibleFrame: screen.visibleFrame)
    }

    /// Calculates the full-height collapsed offscreen frame given a visible screen rectangle.
    public static func drawerCollapsedFrame(forVisibleFrame visible: CGRect) -> CGRect {
        return CGRect(
            x: visible.maxX - collapsedWidth,
            y: visible.minY,
            width: collapsedWidth,
            height: visible.height
        )
    }

    /// Calculates the full-height expanded drawer frame on the right edge of a screen.
    public static func drawerExpandedFrame(for screen: NSScreen, width: CGFloat = userPanelWidth) -> CGRect {
        return drawerExpandedFrame(forVisibleFrame: screen.visibleFrame, width: width)
    }

    /// Calculates the full-height expanded drawer frame given a visible screen rectangle.
    public static func drawerExpandedFrame(forVisibleFrame visible: CGRect, width: CGFloat = userPanelWidth) -> CGRect {
        return CGRect(
            x: visible.maxX - width,
            y: visible.minY,
            width: width,
            height: visible.height
        )
    }

    /// Calculates the edge activation indicator frame vertically centered along the right edge of a screen.
    public static func edgeHandleFrame(for screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let width: CGFloat = 18.0
        let height: CGFloat = 120.0
        return CGRect(
            x: visible.maxX - width,
            y: visible.midY - (height / 2),
            width: width,
            height: height
        )
    }

    // MARK: - Legacy Compatibility Methods

    /// Calculates the trigger zone frame on a specific screen (top-right quadrant).
    public static func triggerFrame(for screen: NSScreen, heightRatio: CGFloat = 0.40) -> CGRect {
        return triggerFrame(forVisibleFrame: screen.visibleFrame, heightRatio: heightRatio)
    }

    /// Calculates the trigger zone frame given a visible screen rectangle.
    public static func triggerFrame(forVisibleFrame visible: CGRect, heightRatio: CGFloat = 0.40) -> CGRect {
        let height = max(240.0, visible.height * heightRatio)
        let x = visible.maxX - triggerWidth
        let y = visible.maxY - height
        return CGRect(x: x, y: y, width: triggerWidth, height: height)
    }

    /// Calculates the visible frame of the collection panel when extended.
    public static func panelExpandedFrame(for screen: NSScreen, width: CGFloat = defaultPanelWidth) -> CGRect {
        return drawerExpandedFrame(for: screen)
    }

    /// Calculates the visible frame of the collection panel given a visible screen rectangle.
    public static func panelExpandedFrame(forVisibleFrame visible: CGRect, width: CGFloat = defaultPanelWidth) -> CGRect {
        return drawerExpandedFrame(forVisibleFrame: visible)
    }

    /// Calculates the hidden/retracted frame of the collection panel.
    public static func panelRetractedFrame(for screen: NSScreen, width: CGFloat = defaultPanelWidth) -> CGRect {
        return drawerCollapsedFrame(for: screen)
    }

    // MARK: - Mouse Corner Activation Zone Detection

    /// Determines if a global screen point falls within the top-right activation corner zone of a screen.
    public static func isPointInActivationCorner(
        _ point: CGPoint,
        for screen: NSScreen,
        cornerWidth: CGFloat = 28.0,
        heightRatio: CGFloat = 0.40
    ) -> Bool {
        return isPointInActivationCorner(
            point,
            forVisibleFrame: screen.visibleFrame,
            cornerWidth: cornerWidth,
            heightRatio: heightRatio
        )
    }

    /// Determines if a point falls within the top-right activation corner zone for a given visible frame.
    public static func isPointInActivationCorner(
        _ point: CGPoint,
        forVisibleFrame visible: CGRect,
        cornerWidth: CGFloat = 28.0,
        heightRatio: CGFloat = 0.40
    ) -> Bool {
        let height = max(240.0, visible.height * heightRatio)
        let zone = CGRect(
            x: visible.maxX - cornerWidth,
            y: visible.maxY - height,
            width: cornerWidth,
            height: height
        )
        return zone.contains(point)
    }
}
