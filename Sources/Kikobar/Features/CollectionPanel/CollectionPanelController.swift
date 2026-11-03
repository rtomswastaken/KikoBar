import AppKit
import SwiftUI

/// Manages the floating collection drawer window presentation and animations.
@MainActor
public final class CollectionPanelController {
    public let panelWindow: CollectionPanelWindow
    private let coordinator: AppCoordinator
    public private(set) var isAnimating: Bool = false

    public var isVisible: Bool {
        panelWindow.isVisible
    }

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator

        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let initialFrame = ScreenGeometry.panelRetractedFrame(for: screen)

        self.panelWindow = CollectionPanelWindow(contentRect: initialFrame)

        let rootView = PanelContainerView(coordinator: coordinator, themeManager: themeManager)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingController.view.autoresizingMask = [.width, .height]

        self.panelWindow.contentViewController = hostingController
        self.panelWindow.onEscapePressed = { [weak coordinator] in
            coordinator?.hidePanel()
        }
    }

    /// Animates the collection panel smoothly onto the screen from the right edge with a spring-like easeOut.
    public func show(on targetScreen: NSScreen? = nil) {
        let screen = targetScreen ?? panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let endFrame = ScreenGeometry.panelExpandedFrame(for: screen)
        let startFrame = ScreenGeometry.panelRetractedFrame(for: screen)

        if !panelWindow.isVisible {
            panelWindow.setFrame(startFrame, display: false)
            panelWindow.orderFrontRegardless()
        }

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.30
            // macOS spring-like fluid deceleration curve
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
            self.panelWindow.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.isAnimating = false
            }
        })
    }

    /// Animates the collection panel sliding off the screen to the right.
    public func hide() {
        guard panelWindow.isVisible else { return }

        let screen = panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let endFrame = ScreenGeometry.panelRetractedFrame(for: screen)

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            // Smooth ease-in retraction
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            self.panelWindow.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.panelWindow.orderOut(nil)
                self.isAnimating = false
            }
        })
    }
}
