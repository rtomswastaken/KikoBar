import AppKit
import Combine
import Foundation

/// Centralized state machine managing drag interactions, boundary transitions,
/// mouse corner activation, board hover expansion, and intelligent dismissal debouncing.
@MainActor
public final class DragSessionManager: ObservableObject {
    public static let shared = DragSessionManager()

    // MARK: - State Machine Definition

    public enum State: Equatable, Sendable {
        /// Inactive idle state; sidebar collapsed.
        case idle
        /// Drag detected entering an edge trigger zone.
        case dragDetected(screen: String)
        /// Sidebar is animating open.
        case sidebarOpening(screen: String)
        /// Sidebar is fully open and interactive.
        case sidebarOpen
        /// Drag cursor is hovering over a specific board card / header.
        case hoveringOverBoard(boardID: UUID)
        /// Drag cursor is hovering within a board's content area (media grid).
        case hoveringOverBoardContent(boardID: UUID)
        /// Item was dropped on a board, ingestion in progress.
        case itemDropped(boardID: UUID)
        /// Drag was cancelled or moved away without dropping.
        case dragCancelled
        /// Dismissal is scheduled after a grace period.
        case dismissalPending(reason: String)

        /// Whether the drawer UI is in its expanded state.
        public var isExpanded: Bool {
            switch self {
            case .idle, .dragCancelled:
                return false
            case .dragDetected, .sidebarOpening, .sidebarOpen, .hoveringOverBoard,
                 .hoveringOverBoardContent, .itemDropped, .dismissalPending:
                return true
            }
        }

        /// The currently targeted board identifier, if hovering or dropping.
        public var activeBoardID: UUID? {
            switch self {
            case .hoveringOverBoard(let id), .hoveringOverBoardContent(let id), .itemDropped(let id):
                return id
            default:
                return nil
            }
        }
    }

    // MARK: - Published Properties

    @Published public private(set) var state: State = .idle {
        didSet {
            syncCoordinatorState()
        }
    }
    @Published public private(set) var isDragSessionActive: Bool = false
    @Published public private(set) var isMouseHoverActive: Bool = false
    @Published public private(set) var activeScreen: NSScreen?
    @Published public private(set) var activeBoardID: UUID?
    @Published public private(set) var isUserInteracting: Bool = false

    // MARK: - Configuration

    /// Dismissal grace period (seconds) before auto-collapsing when pointer leaves interactive bounds.
    /// Exactly 1,000ms (1.0 second) as required.
    public var dismissalGracePeriod: TimeInterval = DesignSystem.Animation.autoDismissalDelay

    // MARK: - Dependencies & Windows

    public weak var coordinator: AppCoordinator?
    public weak var panelController: CollectionPanelController?
    public var triggerWindows: [TriggerZoneWindow] = []

    // MARK: - Timers & Monitors

    private var dismissalTimer: Timer?
    private var edgeActivationTimer: Timer?
    private var pendingActivationScreen: NSScreen?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    public init() {}

    // MARK: - State Synchronization

    private func syncCoordinatorState() {
        guard let coord = coordinator else { return }
        switch state {
        case .idle:
            coord.dragState = .idle
        case .dragDetected(let screen):
            coord.dragState = .dragDetected(screen: screen)
        case .sidebarOpening(let screen):
            coord.dragState = .dragDetected(screen: screen)
        case .sidebarOpen:
            coord.dragState = .drawerExpanded
        case .hoveringOverBoard(let id):
            coord.dragState = .dragOverCategory(categoryID: id)
            coord.activeHoverCategoryID = id
        case .hoveringOverBoardContent(let id):
            coord.dragState = .dragOverCategory(categoryID: id)
            coord.activeHoverCategoryID = id
        case .itemDropped(let id):
            coord.dragState = .itemDropped(categoryID: id)
            coord.activeHoverCategoryID = id
        case .dragCancelled:
            coord.dragState = .collapsed
            coord.activeHoverCategoryID = nil
        case .dismissalPending:
            // Preserve expanded visual state while dismissal is pending
            coord.dragState = .drawerExpanded
        }
    }

    // MARK: - Interactive Area Calculation

    /// Tests whether a global Cocoa screen point falls within the interactive region
    /// (the collection panel window, the trigger zones, plus a generous boundary buffer).
    public func isPointInInteractiveArea(_ point: NSPoint) -> Bool {
        let buffer: CGFloat = 18.0

        if let panelWindow = panelController?.panelWindow, panelWindow.isVisible {
            if panelWindow.frame.insetBy(dx: -buffer, dy: -buffer).contains(point) {
                return true
            }
        }

        for win in triggerWindows where win.isVisible {
            if win.frame.insetBy(dx: -buffer, dy: -buffer).contains(point) {
                return true
            }
        }

        return false
    }

    // MARK: - Mouse Hover Monitoring (Corner Activation without Dragging)

    /// Installs system-wide and local mouse monitors to detect corner activation and hover.
    public func startMouseMonitoring() {
        guard globalMouseMonitor == nil else { return }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.handlePointerMoved(at: NSEvent.mouseLocation)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handlePointerMoved(at: NSEvent.mouseLocation)
            return event
        }

        AppLogger.drag.info("Mouse corner and hover monitoring started.")
    }

    /// Removes installed event monitors.
    public func stopMouseMonitoring() {
        cancelEdgeActivation()
        if let gm = globalMouseMonitor {
            NSEvent.removeMonitor(gm)
            globalMouseMonitor = nil
        }
        if let lm = localMouseMonitor {
            NSEvent.removeMonitor(lm)
            localMouseMonitor = nil
        }
    }

    /// Evaluates cursor position relative to activation corners and interactive zones.
    public func handlePointerMoved(at point: NSPoint) {
        // Never interrupt an active drop ingestion or confirmation feedback
        if case .itemDropped = state { return }
        if let coord = coordinator, case .confirmation = coord.dragState { return }

        let isRevealed = (panelController?.isExpanded ?? false) || (coordinator?.isPanelVisible ?? false)

        if !isRevealed {
            // Check if cursor entered activation zone on any display
            let candidateScreens = NSScreen.screens.isEmpty ? ([NSScreen.main].compactMap { $0 }) : NSScreen.screens
            var matchingScreen: NSScreen?
            for screen in candidateScreens {
                if ScreenGeometry.isPointInActivationCorner(point, for: screen)
                    || ScreenGeometry.edgeHandleFrame(for: screen).contains(point) {
                    matchingScreen = screen
                    break
                }
            }

            if let screen = matchingScreen {
                scheduleEdgeActivation(on: screen)
            } else {
                cancelEdgeActivation()
            }
        } else {
            cancelEdgeActivation()
            // Sidebar is currently open
            let inside = isPointInInteractiveArea(point)
            if inside {
                // Moving inside cancels any pending dismissal
                if dismissalTimer != nil || isDismissalPending {
                    cancelDismissal()
                    if state != .sidebarOpen && !isDragSessionActive {
                        state = .sidebarOpen
                    }
                }
                isUserInteracting = true
            } else {
                // Pointer has left the interactive area
                if !isDragSessionActive && dismissalTimer == nil {
                    scheduleDismissal(reason: "Pointer exited interactive area", at: point)
                }
            }
        }
    }

    private var isDismissalPending: Bool {
        if case .dismissalPending = state { return true }
        return false
    }

    // MARK: - Edge Activation Handling (100ms Delay)

    /// Whether edge activation is currently scheduled and waiting for the 100ms delay.
    public var isEdgeActivationPending: Bool {
        edgeActivationTimer != nil
    }

    /// Schedules edge activation after exactly 100ms to eliminate accidental openings when briefly passing the edge.
    public func scheduleEdgeActivation(on screen: NSScreen) {
        if let pending = pendingActivationScreen, pending == screen, edgeActivationTimer != nil {
            return
        }

        cancelEdgeActivation()
        pendingActivationScreen = screen

        let delay = DesignSystem.Animation.edgeActivationDelay
        edgeActivationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let targetScreen = self.pendingActivationScreen else { return }
                self.edgeActivationTimer = nil
                self.pendingActivationScreen = nil

                // Verify mouse is still inside the activation zone
                let currentPoint = NSEvent.mouseLocation
                if ScreenGeometry.isPointInActivationCorner(currentPoint, for: targetScreen)
                    || ScreenGeometry.edgeHandleFrame(for: targetScreen).contains(currentPoint) {
                    self.activateViaMouseHover(on: targetScreen)
                }
            }
        }
    }

    /// Cancels scheduled edge activation when cursor leaves the edge before 100ms.
    public func cancelEdgeActivation() {
        if edgeActivationTimer != nil {
            edgeActivationTimer?.invalidate()
            edgeActivationTimer = nil
        }
        pendingActivationScreen = nil
    }

    // MARK: - Activation Actions

    /// Reveals the sidebar via mouse hover in the top-right activation corner.
    public func activateViaMouseHover(on screen: NSScreen, animated: Bool = true) {
        cancelEdgeActivation()
        cancelDismissal()
        isMouseHoverActive = true
        activeScreen = screen
        state = .sidebarOpening(screen: screen.localizedName)

        panelController?.expand(on: screen, animated: animated)
        coordinator?.showPanel()
        state = .sidebarOpen
        AppLogger.drag.info("Sidebar revealed via mouse corner hover on screen: \(screen.localizedName)")
    }

    // MARK: - Drag Lifecycle Events

    /// Called when an external drag enters a screen's trigger zone.
    public func dragEnteredTriggerZone(screen: NSScreen, animated: Bool = true) {
        cancelEdgeActivation()
        cancelDismissal()
        isDragSessionActive = true
        activeScreen = screen
        state = .dragDetected(screen: screen.localizedName)

        panelController?.expand(on: screen, animated: animated)
        coordinator?.dragDetected(on: screen.localizedName)
        AppLogger.drag.info("Drag detected in trigger zone on screen: \(screen.localizedName)")
    }

    /// Called when a drag exits a trigger zone. Checks whether it transitioned into the sidebar.
    public func dragExitedTriggerZone(at point: NSPoint) {
        // If pointer is moving into the collection panel or still in interactive area:
        if isPointInInteractiveArea(point) {
            AppLogger.drag.debug("Drag transitioned across trigger zone boundary into sidebar. Preserving session.")
            return
        }

        // Pointer genuinely moved away
        scheduleDismissal(reason: "Drag left trigger zone and interactive area", at: point)
    }

    /// Called when a drag enters the collection panel window.
    public func dragEnteredCollectionPanel(sender: NSDraggingInfo, animated: Bool = true) {
        cancelDismissal()
        isDragSessionActive = true

        if state == .idle || state == .dragCancelled || !state.isExpanded {
            let screen = activeScreen ?? panelController?.panelWindow.screen ?? NSScreen.main ?? NSScreen()
            state = .dragDetected(screen: screen.localizedName)
            panelController?.expand(on: screen, animated: animated)
            coordinator?.dragDetected(on: screen.localizedName)
        } else {
            if state != .sidebarOpen && activeBoardID == nil {
                state = .sidebarOpen
            }
        }
    }

    /// Called when a drag exits the collection panel root view.
    public func dragExitedCollectionPanel(at point: NSPoint) {
        // If pointer is still inside the panel frame (e.g. moving across SwiftUI subviews), ignore
        if isPointInInteractiveArea(point) {
            AppLogger.drag.debug("Drag exited root view but pointer remains within panel bounds. Preserving session.")
            return
        }

        scheduleDismissal(reason: "Drag exited sidebar interactive area", at: point)
    }

    /// Called when a drag enters a board card or header.
    public func dragEnteredBoard(id: UUID) {
        cancelDismissal()
        isDragSessionActive = true
        activeBoardID = id
        state = .hoveringOverBoard(boardID: id)
        coordinator?.dragHoverBoard(id: id)

        // Automatically expand board if collapsed
        Task { @MainActor in
            await self.coordinator?.expandBoard(id: id)
        }
    }

    /// Called when a drag exits a board.
    public func dragExitedBoard() {
        if isDragSessionActive {
            activeBoardID = nil
            state = .sidebarOpen
            coordinator?.dragHoverBoard(id: nil)
        }
    }

    /// Called when a drag moves into a board's content area (media grid).
    public func dragMovedOverBoardContent(id: UUID) {
        cancelDismissal()
        isDragSessionActive = true
        activeBoardID = id
        state = .hoveringOverBoardContent(boardID: id)
        coordinator?.dragHoverBoard(id: id)
        // Keep board expanded! Never collapse while hovering content.
    }

    private var lastDropTimestamp: TimeInterval = 0

    /// Called when an item is dropped onto a specific board.
    public func itemDropped(onBoardID: UUID, pasteboard: NSPasteboard) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastDropTimestamp > 0.3 else { return }
        lastDropTimestamp = now

        cancelDismissal()
        isDragSessionActive = false
        activeBoardID = onBoardID
        state = .itemDropped(boardID: onBoardID)

        Task { @MainActor in
            await self.coordinator?.handleDrop(pasteboard: pasteboard, into: onBoardID)
            self.activeBoardID = nil
            self.state = .idle
            self.isMouseHoverActive = false
        }
    }

    /// Called when an item is dropped into empty sidebar space without targeting an existing board.
    public func itemDroppedWithoutTarget(pasteboard: NSPasteboard) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastDropTimestamp > 0.3 else { return }
        lastDropTimestamp = now

        cancelDismissal()
        isDragSessionActive = false
        activeBoardID = nil
        state = .sidebarOpen
        isUserInteracting = true

        Task { @MainActor in
            await self.coordinator?.handleDropWithoutTarget(pasteboard: pasteboard)
        }
    }

    /// Called when a drag ends or is cancelled.
    public func dragCancelledOrEnded(at point: NSPoint? = nil) {
        isDragSessionActive = false
        if case .itemDropped = state { return }
        if let coord = coordinator, case .confirmation = coord.dragState { return }

        let checkPoint = point ?? NSEvent.mouseLocation
        if isPointInInteractiveArea(checkPoint) {
            activeBoardID = nil
            state = .sidebarOpen
            isMouseHoverActive = true
        } else {
            scheduleDismissal(reason: "Drag ended outside sidebar", at: checkPoint)
        }
    }

    // MARK: - Sidebar Mouse Events

    public func pointerEnteredSidebar() {
        cancelDismissal()
        isUserInteracting = true
        if state != .sidebarOpen && !isDragSessionActive {
            state = .sidebarOpen
        }
    }

    public func pointerMovedInSidebar() {
        cancelDismissal()
        isUserInteracting = true
    }

    public func pointerExitedSidebar(at point: NSPoint) {
        if isPointInInteractiveArea(point) {
            return
        }
        if !isDragSessionActive {
            scheduleDismissal(reason: "Mouse exited sidebar", at: point)
        }
    }

    // MARK: - Dismissal Handling

    /// Schedules sidebar dismissal after a grace period, verifying no active drag or pointer presence.
    public func scheduleDismissal(reason: String, at point: NSPoint? = nil) {
        // Never dismiss if drag session is active
        guard !isDragSessionActive else { return }
        // Never dismiss during board editing
        if let coord = coordinator, coord.isEditingBoard { return }
        // Never dismiss during active drop ingestion
        if case .itemDropped = state { return }
        if let coord = coordinator, case .confirmation = coord.dragState { return }

        let checkPoint = point ?? NSEvent.mouseLocation
        guard !isPointInInteractiveArea(checkPoint) else { return }

        dismissalTimer?.invalidate()
        state = .dismissalPending(reason: reason)
        AppLogger.drag.debug("Dismissal scheduled (\(self.dismissalGracePeriod)s) - reason: \(reason)")

        dismissalTimer = Timer.scheduledTimer(withTimeInterval: dismissalGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeDismissal()
            }
        }
    }

    /// Cancels any scheduled dismissal and restores interactive state.
    public func cancelDismissal() {
        if dismissalTimer != nil {
            dismissalTimer?.invalidate()
            dismissalTimer = nil
            AppLogger.drag.debug("Dismissal timer cancelled.")
        }
        if case .dismissalPending = state {
            state = .sidebarOpen
        }
    }

    /// Performs the actual collapse of the sidebar.
    public func executeDismissal(animated: Bool = true, at point: NSPoint? = nil) {
        dismissalTimer = nil
        guard !isDragSessionActive else { return }

        let checkPoint = point ?? NSEvent.mouseLocation
        guard !isPointInInteractiveArea(checkPoint) else {
            cancelDismissal()
            return
        }

        AppLogger.drag.info("Dismissing collection sidebar.")
        isMouseHoverActive = false
        activeBoardID = nil
        state = .idle
        panelController?.collapse(animated: animated)
        coordinator?.hidePanel()
    }

    /// Forcefully collapses the sidebar immediately (e.g. on ESC key or explicit close).
    public func forceCollapse(animated: Bool = true) {
        cancelEdgeActivation()
        cancelDismissal()
        isDragSessionActive = false
        isMouseHoverActive = false
        activeBoardID = nil
        state = .idle
        panelController?.collapse(animated: animated)
        coordinator?.hidePanel()
    }
}
