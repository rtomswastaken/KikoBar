import AppKit
import SwiftUI

/// Draggable vertical divider handle on the left edge of the sidebar panel.
/// Allows the user to freely resize the panel width according to their preference,
/// persisting the chosen width across application launches.
public struct ResizeHandleView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false

    public init(coordinator: AppCoordinator, themeManager: ThemeManager) {
        self.coordinator = coordinator
        self.themeManager = themeManager
    }

    public var body: some View {
        ZStack {
            // Invisible wider hit-target area (7pt)
            Color.clear
                .frame(width: 7)

            // Sleek vertical resize indicator line
            Rectangle()
                .fill(indicatorColor)
                .frame(width: isDragging || isHovered ? 2.5 : 1)
        }
        .frame(width: 7)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverFeedback) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in
                    isDragging = true
                    coordinator.cancelDismissalCountdown()

                    let currentMouseX = NSEvent.mouseLocation.x
                    let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
                        ?? NSScreen.main
                        ?? NSScreen()
                    let newWidth = screen.visibleFrame.maxX - currentMouseX
                    coordinator.updatePanelWidth(newWidth)
                }
                .onEnded { _ in
                    isDragging = false
                    coordinator.cancelDismissalCountdown()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                coordinator.resetPanelWidth()
            }
        )
        .help("Drag to resize sidebar • Double-click to reset width")
    }

    private var indicatorColor: Color {
        if isDragging {
            return themeManager.accentColor
        } else if isHovered {
            return themeManager.primaryTextColor.opacity(0.6)
        } else {
            return themeManager.borderColor
        }
    }
}
