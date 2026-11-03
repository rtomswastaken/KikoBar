import AppKit

/// Floating AppKit NSPanel hosting the SwiftUI collection drawer.
public final class CollectionPanelWindow: NSPanel {
    public var onEscapePressed: (() -> Void)?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
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
