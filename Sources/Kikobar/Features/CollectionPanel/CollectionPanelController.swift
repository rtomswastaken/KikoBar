import AppKit
import SwiftUI

/// Manages the full-height black collection drawer window presentation, horizontal animations, and drag lifecycle.
@MainActor
public final class CollectionPanelController {
    public let panelWindow: CollectionPanelWindow
    private let coordinator: AppCoordinator
    public private(set) var isAnimating: Bool = false
    private var exitTimer: Timer?

    public var isVisible: Bool {
        panelWindow.isVisible
    }

    public var isExpanded: Bool {
        guard let screen = panelWindow.screen ?? NSScreen.main else { return false }
        return panelWindow.isVisible && panelWindow.frame.minX < screen.visibleFrame.maxX
    }

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator

        let screen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let initialFrame = ScreenGeometry.drawerCollapsedFrame(for: screen)

        self.panelWindow = CollectionPanelWindow(contentRect: initialFrame)

        let rootView = PanelContainerView(coordinator: coordinator, themeManager: themeManager)
        let drawerVC = CollectionDrawerViewController(rootView: rootView)
        self.panelWindow.drawerViewController = drawerVC
        self.panelWindow.contentViewController = drawerVC

        self.panelWindow.onEscapePressed = { [weak coordinator] in
            if coordinator?.boardPendingDeletion != nil {
                Task { @MainActor in
                    coordinator?.boardPendingDeletion = nil
                }
            } else if let creatingID = coordinator?.creatingBoardID {
                Task { @MainActor in
                    await coordinator?.cancelBoardCreation(id: creatingID)
                }
            } else {
                DragSessionManager.shared.forceCollapse()
                coordinator?.hidePanel()
            }
        }

        DragSessionManager.shared.panelController = self
        setupDragHandlers()

        // Position collapsed off-screen by default
        self.panelWindow.setFrame(initialFrame, display: true)
    }

    private func setupDragHandlers() {
        panelWindow.drawerView.onDragEntered = { [weak self] sender in
            guard let self = self else { return .copy }
            let screen = self.panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
            self.expand(on: screen)
            DragSessionManager.shared.dragEnteredCollectionPanel(sender: sender)
            return .copy
        }

        panelWindow.drawerView.onDragUpdated = { sender in
            DragSessionManager.shared.cancelDismissal()
            return .copy
        }

        panelWindow.drawerView.onDragExited = { sender in
            DragSessionManager.shared.dragExitedCollectionPanel(at: NSEvent.mouseLocation)
        }

        panelWindow.drawerView.onPerformDrop = { [weak self] sender in
            guard let self = self else { return false }
            let dragPasteboard = sender.draggingPasteboard

            if let targetCategoryID = DragSessionManager.shared.activeBoardID
                ?? self.coordinator.activeHoverCategoryID {
                // File dropped directly onto an existing board
                DragSessionManager.shared.itemDropped(onBoardID: targetCategoryID, pasteboard: dragPasteboard)
                return true
            } else {
                // File dropped into an empty area of the sidebar without targeting an existing board
                DragSessionManager.shared.itemDroppedWithoutTarget(pasteboard: dragPasteboard)
                return true
            }
        }

        panelWindow.drawerView.onDragEnded = { sender in
            DragSessionManager.shared.dragCancelledOrEnded()
        }
    }

    /// Repositions the panel to adapt to screen geometry, display resolution, or multi-monitor changes.
    public func reposition(on targetScreen: NSScreen? = nil) {
        let screen = targetScreen ?? panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let targetFrame = isExpanded ? ScreenGeometry.drawerExpandedFrame(for: screen) : ScreenGeometry.drawerCollapsedFrame(for: screen)
        panelWindow.setFrame(targetFrame, display: true)
    }

    /// Smooth horizontal expansion animation from the right screen edge.
    public func expand(on targetScreen: NSScreen? = nil, animated: Bool = true) {
        let screen = targetScreen ?? panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let width = ScreenGeometry.userPanelWidth
        let endFrame = ScreenGeometry.drawerExpandedFrame(for: screen, width: width)

        DragSessionManager.shared.cancelDismissal()
        coordinator.showPanel()

        // If window is currently hidden/ordered out or off-screen, ensure it starts positioned just off the right edge
        if !panelWindow.isVisible || panelWindow.frame.minX >= screen.visibleFrame.maxX {
            let startFrame = CGRect(
                x: screen.visibleFrame.maxX,
                y: screen.visibleFrame.minY,
                width: width,
                height: screen.visibleFrame.height
            )
            panelWindow.setFrame(startFrame, display: false)
        }

        panelWindow.orderFrontRegardless()

        guard panelWindow.frame != endFrame else { return }

        if !animated || DesignSystem.Animation.shouldReduceMotion {
            panelWindow.setFrame(endFrame, display: true)
            return
        }

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = DesignSystem.Animation.sidebarOpeningDuration
            context.timingFunction = DesignSystem.Animation.sidebarOpeningTiming
            self.panelWindow.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.isAnimating = false
            }
        })
    }

    /// Smooth horizontal retraction animation back off the right screen edge.
    public func collapse(animated: Bool = true) {
        let screen = panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let currentWidth = panelWindow.frame.width > 0 ? panelWindow.frame.width : ScreenGeometry.userPanelWidth
        // Smooth slide out: x translates to screen.visibleFrame.maxX while retaining full width
        let endFrame = CGRect(
            x: screen.visibleFrame.maxX,
            y: screen.visibleFrame.minY,
            width: currentWidth,
            height: screen.visibleFrame.height
        )

        DragSessionManager.shared.cancelDismissal()

        guard panelWindow.frame != endFrame else {
            panelWindow.orderOut(nil)
            coordinator.hidePanel()
            return
        }

        if !animated || DesignSystem.Animation.shouldReduceMotion {
            panelWindow.setFrame(endFrame, display: true)
            panelWindow.orderOut(nil)
            coordinator.hidePanel()
            return
        }

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = DesignSystem.Animation.sidebarClosingDuration
            context.timingFunction = DesignSystem.Animation.sidebarClosingTiming
            self.panelWindow.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.isAnimating = false
                self.panelWindow.orderOut(nil)
                self.coordinator.hidePanel()
            }
        })
    }

    /// Dynamically resizes the panel width while keeping it attached to the right screen edge.
    public func updatePanelWidth(_ width: CGFloat) {
        let screen = panelWindow.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let maxAllowed = min(ScreenGeometry.maxPanelWidth, screen.visibleFrame.width * 0.7)
        let clamped = min(max(width, ScreenGeometry.minPanelWidth), maxAllowed)

        ScreenGeometry.userPanelWidth = clamped

        if isExpanded {
            let newFrame = CGRect(
                x: screen.visibleFrame.maxX - clamped,
                y: screen.visibleFrame.minY,
                width: clamped,
                height: screen.visibleFrame.height
            )
            panelWindow.setFrame(newFrame, display: true)
        }
    }

    /// Compatibility wrapper for show.
    public func show(on targetScreen: NSScreen? = nil) {
        expand(on: targetScreen)
    }

    /// Compatibility wrapper for hide.
    public func hide() {
        collapse()
    }
}
