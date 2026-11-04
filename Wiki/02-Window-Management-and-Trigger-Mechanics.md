# Module 02: Window Management & Trigger Mechanics

This module provides the low-level implementation details for Kikobar's AppKit windowing subsystem, multi-monitor coordinate math, zero-permission edge detection, and interactive dismissal state machine.

---

## 1. The Zero-Permission macOS Windowing Architecture

In macOS, standard applications run as `.regular` processes with a Dock icon and standard windows. Utilities that operate alongside user workflows must behave as unobtrusive system overlays:

```swift
// AppDelegate.swift
NSApp.setActivationPolicy(.accessory)
```

Setting `.accessory` removes the Dock icon and menu bar, ensuring the app remains a background helper.

### Custom `NSPanel` Subclasses

All Kikobar visual elements—the collection drawer, the edge handle, and the invisible trigger zones—subclass `NSPanel`:

```swift
public final class CollectionPanelWindow: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [
            .canJoinAllSpaces,      // Persists across all Mission Control virtual desktops
            .fullScreenAuxiliary,   // Overlays on top of full-screen applications (Xcode, Safari)
            .ignoresCycle           // Excluded from Cmd+Tab application switching
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    // Crucial: Prevents the window from stealing primary key window status
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}
```

### Critical Window Configuration Flags

| Property | Value | Purpose |
| :--- | :--- | :--- |
| `styleMask` | `[.borderless, .nonactivatingPanel]` | Removes title bar and prevents activating the utility over the user's foreground app. |
| `level` | `.floating` (or `.popUpMenu`) | Places the panel in front of standard document windows and desktop icons. |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]` | Keeps the drawer accessible on all virtual desktops and full-screen spaces without disrupting `Cmd+Tab`. |
| `isOpaque` | `false` | Enables transparent SwiftUI rounded backgrounds and drop shadows. |

---

## 2. Screen Geometry & Coordinate Mathematics

macOS Cocoa coordinate systems place the origin `(0, 0)` at the **bottom-left corner of the primary screen**. When calculating window frames across multiple screens, developers must account for:
1. Secondary monitors positioned to the left or above the primary monitor (which can have negative coordinates).
2. The macOS Menu Bar at the top of the screen (`screen.visibleFrame.maxY < screen.frame.maxY`).
3. The Dock positioned at the bottom, left, or right (`screen.visibleFrame`).

Kikobar encapsulates all coordinate calculations in `Sources/Kikobar/Core/Utilities/ScreenGeometry.swift`:

```
┌─────────────────────────────────────────────────────────────┐  Screen Frame (NSScreen.frame)
│ [Apple Menu] [File] [Edit] ...                 [Clock]      │  Height: e.g. 1080px
├─────────────────────────────────────────────────────────────┤
│                                            │  Top-Right     │
│                                            │  Trigger Zone  │  Height: 40% of visibleFrame
│                                            │  (Width: 20px) │
│                                            ├────────────────┤
│                                            │                │
│                                            │  Floating      │
│                                            │  Drawer Panel  │  User Width: 180px - 700px
│                                            │  (Full Height) │  (Default: 240px)
│                                            │                │
│                                            │                │
│                                            │                │
│ [Dock: Finder, Safari, Xcode, Terminal]    │                │
└────────────────────────────────────────────┴────────────────┘
 (0,0) Primary Screen Cocoa Origin
```

### Core Geometry Formulas

```swift
public struct ScreenGeometry: Sendable {
    public static let collapsedWidth: CGFloat = 0.0
    public static let defaultExpandedWidth: CGFloat = 240.0
    public static let minPanelWidth: CGFloat = 180.0
    public static let maxPanelWidth: CGFloat = 700.0

    /// Width persisted across launches in UserDefaults
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

    /// Expanded drawer frame docked along the right screen edge
    public static func drawerExpandedFrame(forVisibleFrame visible: CGRect, width: CGFloat = userPanelWidth) -> CGRect {
        return CGRect(
            x: visible.maxX - width,
            y: visible.minY,
            width: width,
            height: visible.height
        )
    }

    /// Collapsed offscreen drawer frame
    public static func drawerCollapsedFrame(forVisibleFrame visible: CGRect) -> CGRect {
        return CGRect(
            x: visible.maxX - collapsedWidth,
            y: visible.minY,
            width: collapsedWidth,
            height: visible.height
        )
    }

    /// Top-Right Quadrant Trigger Frame (40% of screen height, 20px width)
    public static func triggerFrame(forVisibleFrame visible: CGRect, heightRatio: CGFloat = 0.40) -> CGRect {
        let height = max(240.0, visible.height * heightRatio)
        return CGRect(
            x: visible.maxX - 20.0,
            y: visible.maxY - height,
            width: 20.0,
            height: height
        )
    }

    /// Identifies which physical NSScreen contains a given global point
    public static func screen(containing point: CGPoint) -> NSScreen {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
}
```

---

## 3. The Edge Trigger Mechanics

To trigger drawer expansion without accessibility hooks, Kikobar places an invisible `TriggerZoneWindow` along the top-right border of every display:

```swift
public final class TriggerZoneWindow: NSPanel {
    public init(screen: NSScreen) {
        let frame = ScreenGeometry.triggerFrame(for: screen)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false

        let triggerView = TriggerZoneDropView(frame: NSRect(origin: .zero, size: frame.size))
        self.contentView = triggerView
    }
}
```

### Drag Detection via `NSDraggingDestination`

The trigger view registers to receive all system drag types:

```swift
final class TriggerZoneDropView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .tiff,
            .png,
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            .item
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let screen = self.window?.screen else { return [] }
        
        // Notify the DragSessionManager that a drag has breached the edge zone
        DragSessionManager.shared.dragEnteredTriggerZone(on: screen)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // Drag moved away from the trigger zone
        DragSessionManager.shared.dragExitedTriggerZone()
    }
}
```

When `draggingEntered` fires:
1. `DragSessionManager.shared` transitions state from `.idle` to `.dragDetected(screen)`.
2. `CollectionPanelController` immediately animates the collection drawer into view on the targeted screen.
3. The user continues their drag seamlessly across the threshold into the newly revealed drawer.

---

## 4. Collection Drawer Window & Animations

The collection drawer is managed by `CollectionPanelController`:

```swift
@MainActor
public final class CollectionPanelController: NSObject {
    public let panel: CollectionPanelWindow
    public let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.panel = CollectionPanelWindow(contentRect: .zero)
        super.init()

        let rootView = PanelContainerView(coordinator: coordinator)
        let hostingView = NSHostingView(rootView: rootView)
        self.panel.contentView = hostingView
    }

    public func expand(on screen: NSScreen, animated: Bool = true) {
        let targetFrame = ScreenGeometry.drawerExpandedFrame(for: screen)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = DesignSystem.Animation.drawerSpringDuration // 0.25s
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            self.panel.setFrame(targetFrame, display: true)
        }

        self.panel.orderFront(nil)
        coordinator.showPanel()
    }

    public func collapse(animated: Bool = true) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let targetFrame = ScreenGeometry.drawerCollapsedFrame(for: screen)

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = DesignSystem.Animation.drawerSpringDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.panel.animator().setFrame(targetFrame, display: true)
            }, completionHandler: {
                self.panel.orderOut(nil)
                self.coordinator.hidePanel()
            })
        } else {
            self.panel.setFrame(targetFrame, display: true)
            self.panel.orderOut(nil)
            coordinator.hidePanel()
        }
    }
}
```

---

## 5. Drag & Hover State Machine (`DragSessionManager`)

Managing when to open, keep open, or dismiss the drawer requires a sophisticated state machine to avoid premature flickering or trapped panels:

```
                  ┌──────────────┐
                  │    .idle     │◄───────────────────────────┐
                  └──────┬───────┘                            │
                         │ Drag enters trigger zone           │
                         ▼                                    │
               ┌───────────────────┐                          │
               │   .dragDetected   │                          │
               └─────────┬─────────┘                          │
                         │ Panel expands                      │
                         ▼                                    │
               ┌───────────────────┐                          │
               │   .sidebarOpen    │                          │
               └────┬─────────┬────┘                          │
   Drag hovers board│         │ Drag enters empty space       │
                    ▼         ▼                               │
      ┌────────────────┐   ┌───────────────────────────┐      │
      │.hoveringBoard  │   │ .sidebarOpen (Drop target)│      │
      └───────┬────────┘   └─────────────┬─────────────┘      │
              │                          │                    │
              │ Drop item                │ Drop item          │
              ▼                          ▼                    │
      ┌────────────────┐   ┌───────────────────────────┐      │
      │  .itemDropped  │   │  Automatic Board Creation │      │
      └───────┬────────┘   └─────────────┬─────────────┘      │
              │                          │                    │
              └──────────────┬───────────┘                    │
                             │ Pointer leaves / 1.0s timeout  │
                             ▼                                │
                 ┌───────────────────────┐                    │
                 │   .dismissalPending   │────────────────────┘
                 └───────────────────────┘
```

### The 1.0-Second Grace Period Debouncer

When the user's cursor or drag exits the sidebar bounds, Kikobar does not instantly snap closed. It begins an exact **1,000ms countdown**:

```swift
public func scheduleDismissal(reason: String, at point: NSPoint? = nil) {
    guard isExpanded else { return }
    // Never dismiss if modal is active or user is naming a board
    if let coord = coordinator {
        guard !coord.isEditingBoard, coord.boardPendingDeletion == nil else { return }
    }

    dismissalTimer?.invalidate()
    dismissalTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
        Task { @MainActor in
            guard let self = self else { return }
            // Verify pointer hasn't re-entered
            if !self.isPointInInteractiveArea(NSEvent.mouseLocation) {
                self.panelController?.collapse(animated: true)
                self.state = .idle
            }
        }
    }
}

public func cancelDismissal() {
    dismissalTimer?.invalidate()
    dismissalTimer = nil
}
```

### Pointer Interactivity Rules

The dismissal countdown is immediately **cancelled** whenever:
1. `onHover` in SwiftUI registers mouse presence within the sidebar.
2. The user is actively typing a board name in inline editing mode.
3. The board deletion confirmation modal is visible.
4. Drag cursor hovers over any board card or media thumbnail.

---

Continue to [**Module 03: Drag-and-Drop Ingestion & Export Engine**](03-Drag-and-Drop-Ingestion-and-Export-Engine.md) to explore payload extraction and drop workflows.
