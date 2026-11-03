import AppKit
import Foundation

// MARK: - Notifications

extension Notification.Name {
    /// Dispatched when a drag enters a Kikobar screen-edge trigger zone.
    public static let kikobarDragEnteredTriggerZone = Notification.Name("kikobar.dragEnteredTriggerZone")
    /// Dispatched when a drag leaves a Kikobar screen-edge trigger zone without a drop.
    public static let kikobarDragExitedTriggerZone = Notification.Name("kikobar.dragExitedTriggerZone")
}

// MARK: - TriggerZoneWindow

/// Borderless edge target window placed in the top-right screen quadrant to detect drags across monitors.
public final class TriggerZoneWindow: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
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
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }

    /// Factory method creating trigger windows positioned for all provided screens.
    @MainActor
    public static func createWindows(
        for screens: [NSScreen],
        onDragEntered: @escaping (NSScreen) -> Void,
        onDragCancelled: (() -> Void)? = nil
    ) -> [TriggerZoneWindow] {
        var windows: [TriggerZoneWindow] = []
        for screen in screens {
            let frame = ScreenGeometry.triggerFrame(for: screen)
            let win = TriggerZoneWindow(contentRect: frame)
            let destView = TriggerZoneDestinationView(frame: NSRect(origin: .zero, size: frame.size))
            destView.autoresizingMask = [.width, .height]
            destView.onDragEntered = onDragEntered
            destView.onDragCancelled = onDragCancelled
            win.contentView = destView
            win.orderFrontRegardless()
            windows.append(win)
        }
        return windows
    }
}

// MARK: - TriggerZoneDestinationView

/// AppKit view conforming to NSDraggingDestination to intercept drag entrance, track proximity,
/// and handle drag cancellation with auto-dismiss delays.
public final class TriggerZoneDestinationView: NSView {
    /// Callback triggered when a drag session enters the trigger zone on a specific screen.
    public var onDragEntered: ((_ screen: NSScreen) -> Void)?

    /// Callback triggered as the drag moves within the trigger zone, reporting position and edge proximity (0.0 to 1.0).
    public var onDragUpdated: ((_ screen: NSScreen, _ location: NSPoint, _ proximity: CGFloat) -> Void)?

    /// Callback triggered when drag leaves the trigger zone.
    public var onDragExited: (() -> Void)?

    /// Callback triggered when drag leaves and the debounce timer expires without a drop.
    public var onDragCancelled: (() -> Void)?

    /// Callback triggered when drag ends.
    public var onDragEnded: (() -> Void)?

    /// Optional handler if drop occurs directly on the trigger edge.
    public var onPerformDrop: ((_ pasteboard: NSPasteboard, _ screen: NSScreen) -> Bool)?

    /// Debounce delay before canceling trigger activation when drag exits (default: 400ms).
    public var exitDelay: TimeInterval = 0.40

    /// Tracks if drag is currently inside this destination view.
    public private(set) var isDragActive: Bool = false

    /// Proximity factor from 0.0 (far side of zone) to 1.0 (screen edge).
    public private(set) var currentProximity: CGFloat = 0.0

    private var exitTimer: Timer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(DragIngestionService.defaultSupportedPasteboardTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(DragIngestionService.defaultSupportedPasteboardTypes)
    }

    deinit {
        exitTimer?.invalidate()
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Pass regular mouse clicks directly through to underlying windows so the edge zone
        // never interferes with normal user clicks on scrollbars or desktop windows.
        // NSDraggingDestination continues to receive drag events via AppKit WindowServer.
        return nil
    }

    // MARK: - NSDraggingDestination Overrides

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        exitTimer?.invalidate()
        exitTimer = nil
        isDragActive = true

        let screen = targetScreen()
        AppLogger.drag.debug("Drag entered trigger zone on screen \(screen.localizedName)")

        NotificationCenter.default.post(
            name: .kikobarDragEnteredTriggerZone,
            object: self,
            userInfo: ["screen": screen]
        )

        onDragEntered?(screen)
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let screen = targetScreen()
        let location = sender.draggingLocation

        // Calculate proximity ratio towards rightmost edge (0.0 to 1.0)
        let proximity: CGFloat
        if bounds.width > 0 {
            proximity = max(0.0, min(1.0, location.x / bounds.width))
        } else {
            proximity = 1.0
        }
        self.currentProximity = proximity

        onDragUpdated?(screen, location, proximity)
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        AppLogger.drag.debug("Drag exited trigger zone; starting cancellation timer (\(self.exitDelay)s)...")
        exitTimer?.invalidate()

        exitTimer = Timer.scheduledTimer(withTimeInterval: exitDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.isDragActive = false
            self.currentProximity = 0.0
            AppLogger.drag.debug("Trigger zone drag cancelled after debounce.")
            NotificationCenter.default.post(name: .kikobarDragExitedTriggerZone, object: self)
            self.onDragCancelled?()
            self.onDragExited?()
        }
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
        exitTimer?.invalidate()
        exitTimer = nil
        isDragActive = false
        currentProximity = 0.0
        onDragEnded?()
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        exitTimer?.invalidate()
        exitTimer = nil
        isDragActive = false
        currentProximity = 0.0

        let screen = targetScreen()
        AppLogger.drag.info("Direct drop performed on trigger zone of screen \(screen.localizedName)")
        return onPerformDrop?(sender.draggingPasteboard, screen) ?? true
    }

    // MARK: - Helpers

    private func targetScreen() -> NSScreen {
        if let windowScreen = self.window?.screen {
            return windowScreen
        }
        return ScreenGeometry.screen(containing: NSEvent.mouseLocation)
    }
}
