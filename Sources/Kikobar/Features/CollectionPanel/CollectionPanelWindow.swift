import AppKit
import SwiftUI

/// AppKit view conforming to NSDraggingDestination to intercept drag events for the collection drawer.
public final class CollectionDrawerRootView: NSView {
    public var onDragEntered: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDragUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    public var onDragExited: ((NSDraggingInfo?) -> Void)?
    public var onPerformDrop: ((NSDraggingInfo) -> Bool)?
    public var onDragEnded: ((NSDraggingInfo) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(DragIngestionService.defaultSupportedPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DragIngestionService.defaultSupportedPasteboardTypes)
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        DragSessionManager.shared.pointerEnteredSidebar()
    }

    public override func mouseMoved(with event: NSEvent) {
        DragSessionManager.shared.pointerMovedInSidebar()
    }

    public override func mouseExited(with event: NSEvent) {
        DragSessionManager.shared.pointerExitedSidebar(at: NSEvent.mouseLocation)
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return onDragEntered?(sender) ?? .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return onDragUpdated?(sender) ?? .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?(sender)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return onPerformDrop?(sender) ?? true
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragEnded?(sender)
    }
}

/// AppKit view controller managing the root drawer view and SwiftUI hosting hierarchy.
public final class CollectionDrawerViewController: NSViewController {
    public let drawerView: CollectionDrawerRootView
    public let hostingController: NSHostingController<PanelContainerView>

    public init(rootView: PanelContainerView) {
        self.drawerView = CollectionDrawerRootView(frame: .zero)
        self.hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)

        self.addChild(hostingController)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = drawerView
        hostingController.view.frame = drawerView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        drawerView.addSubview(hostingController.view)
    }
}

/// Floating AppKit NSPanel hosting the full-height black vertical collection drawer.
public final class CollectionPanelWindow: NSPanel {
    public var onEscapePressed: (() -> Void)?
    public var drawerViewController: CollectionDrawerViewController?

    public var drawerView: CollectionDrawerRootView {
        drawerViewController?.drawerView ?? CollectionDrawerRootView(frame: .zero)
    }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: ScreenGeometry.minPanelWidth, height: 300)
        self.maxSize = NSSize(width: ScreenGeometry.maxPanelWidth, height: 4000)
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func cancelOperation(_ sender: Any?) {
        if let onEscapePressed = onEscapePressed {
            onEscapePressed()
        } else {
            super.cancelOperation(sender)
        }
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            if let onEscapePressed = onEscapePressed {
                onEscapePressed()
                return
            }
        }
        super.keyDown(with: event)
    }
}
