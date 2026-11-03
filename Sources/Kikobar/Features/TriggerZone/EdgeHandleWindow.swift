import AppKit
import Foundation
import SwiftUI

/// Borderless edge handle window positioned at the vertical center of the right screen edge.
/// Appears as a subtle grey vertical line only when the mouse approaches, and opens the sidebar on click.
public final class EdgeHandleWindow: NSPanel {
    public let handleView: EdgeHandleView

    public init(screen: NSScreen, onOpenSidebar: @escaping () -> Void) {
        let frame = ScreenGeometry.edgeHandleFrame(for: screen)
        self.handleView = EdgeHandleView(frame: NSRect(origin: .zero, size: frame.size), onOpenSidebar: onOpenSidebar)

        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isReleasedWhenClosed = false

        self.contentView = handleView
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public func reposition(on screen: NSScreen) {
        let frame = ScreenGeometry.edgeHandleFrame(for: screen)
        self.setFrame(frame, display: true)
    }
}

/// AppKit view managing the subtle grey indicator line, proximity fade-in/out, click to open, and drag detection.
public final class EdgeHandleView: NSView {
    public var onOpenSidebar: () -> Void
    private let indicatorLayer = CALayer()
    public private(set) var isIndicatorVisible: Bool = false

    public init(frame frameRect: NSRect, onOpenSidebar: @escaping () -> Void) {
        self.onOpenSidebar = onOpenSidebar
        super.init(frame: frameRect)
        self.wantsLayer = true
        setupIndicator()
        registerForDraggedTypes(DragIngestionService.defaultSupportedPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupIndicator() {
        guard let layer = self.layer else { return }

        let indicatorWidth: CGFloat = 3.5
        let indicatorHeight: CGFloat = 48.0
        let indicatorX = bounds.width - indicatorWidth - 2.0
        let indicatorY = (bounds.height - indicatorHeight) / 2.0

        indicatorLayer.frame = CGRect(x: indicatorX, y: indicatorY, width: indicatorWidth, height: indicatorHeight)
        indicatorLayer.cornerRadius = indicatorWidth / 2.0
        indicatorLayer.backgroundColor = NSColor(white: 0.65, alpha: 0.85).cgColor
        indicatorLayer.opacity = 0.0 // Hidden by default

        layer.addSublayer(indicatorLayer)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept clicks if the point is within the indicator bounds and it is visible
        if isIndicatorVisible {
            let indicatorRect = indicatorLayer.frame.insetBy(dx: -8, dy: -8)
            if indicatorRect.contains(point) {
                return self
            }
        }
        return nil
    }

    // MARK: - Proximity Tracking

    public override func mouseEntered(with event: NSEvent) {
        showIndicator()
    }

    public override func mouseExited(with event: NSEvent) {
        hideIndicator()
    }

    public override func mouseDown(with event: NSEvent) {
        onOpenSidebar()
        hideIndicator()
    }

    public func showIndicator(animated: Bool = true) {
        guard !isIndicatorVisible else { return }
        isIndicatorVisible = true

        if animated && !DesignSystem.Animation.shouldReduceMotion {
            CATransaction.begin()
            CATransaction.setAnimationDuration(DesignSystem.Animation.edgeHandleFadeInDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            indicatorLayer.opacity = 1.0
            CATransaction.commit()
        } else {
            indicatorLayer.opacity = 1.0
        }
    }

    public func hideIndicator(animated: Bool = true) {
        guard isIndicatorVisible else { return }
        isIndicatorVisible = false

        if animated && !DesignSystem.Animation.shouldReduceMotion {
            CATransaction.begin()
            CATransaction.setAnimationDuration(DesignSystem.Animation.edgeHandleFadeOutDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
            indicatorLayer.opacity = 0.0
            CATransaction.commit()
        } else {
            indicatorLayer.opacity = 0.0
        }
    }

    // MARK: - Dragging Destination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onOpenSidebar()
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
}
