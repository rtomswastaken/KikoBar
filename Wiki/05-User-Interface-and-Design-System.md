# Module 05: User Interface & Design System

This module provides the comprehensive engineering manual for Kikobar's visual layer: design tokens, custom typography, SwiftUI component hierarchy, reactive state bindings, and native QuickLook keyboard integration.

---

## 1. Design Tokens & Visual Hierarchy

Kikobar delivers an indie macOS aesthetic: very dark charcoal backgrounds, crisp lavender/purple accents, subtle borders, and smooth spring animations.

### Design Tokens (`DesignSystem.swift`)

```swift
public enum DesignSystem {
    public enum Colors {
        // Dark Charcoal Palette (Default)
        public static let darkBackground = Color(hex: "#161618")
        public static let darkSurface    = Color(hex: "#1F1F23")
        public static let darkCard       = Color(hex: "#26262B")
        public static let darkBorder     = Color(hex: "#323238")
        public static let darkTextPrimary   = Color(hex: "#FFFFFF")
        public static let darkTextSecondary = Color(hex: "#8E8E93")

        // Light Daylight Palette
        public static let lightBackground = Color(hex: "#F7F7F9")
        public static let lightSurface    = Color(hex: "#FFFFFF")
        public static let lightCard       = Color(hex: "#EDEDF0")
        public static let lightBorder     = Color(hex: "#DCDCE0")
        public static let lightTextPrimary   = Color(hex: "#1C1C1E")
        public static let lightTextSecondary = Color(hex: "#636366")

        // Curated 10-Shade Board Palette
        public static let boardPalette: [String] = [
            "#8B7CFF", // Lavender (Primary Brand Accent)
            "#5E5CE6", // Indigo
            "#0A84FF", // Electric Blue
            "#30D158", // Mint Green
            "#FFD60A", // Sunflower Yellow
            "#FF9F0A", // Tangerine Orange
            "#FF453A", // Crimson Red
            "#FF375F", // Hot Pink
            "#BF5AF2", // Royal Purple
            "#64D2FF"  // Sky Cyan
        ]
    }

    public enum CornerRadius {
        public static let small: CGFloat = 6.0
        public static let medium: CGFloat = 10.0
        public static let large: CGFloat = 14.0
        public static let drawer: CGFloat = 16.0
    }

    public enum Animation {
        public static let drawerSpring = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.82)
        public static let drawerSpringDuration: TimeInterval = 0.25
        public static let themeSwitch = SwiftUI.Animation.easeInOut(duration: 0.20)
        public static let autoDismissalDelay: TimeInterval = 1.0 // 1,000ms debounced dismissal
    }
}
```

---

## 2. Dynamic Typography Engine (`KikobarFont.swift`)

To achieve a distinctive macOS interface, Kikobar bundles the **Poppins** font family (`Regular`, `Medium`, `SemiBold`, `Bold`) directly inside the application bundle.

### Font Registration Lifecycle

At startup (`AppDelegate.swift`), TTF fonts located in `Contents/Resources/Fonts/` are dynamically registered into the macOS font manager:

```swift
public static func registerCustomFonts() {
    let fontFiles = [
        "Poppins-Regular.ttf",
        "Poppins-Medium.ttf",
        "Poppins-SemiBold.ttf",
        "Poppins-Bold.ttf"
    ]

    for file in fontFiles {
        if let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Fonts") ??
                     Bundle.main.url(forResource: file, withExtension: nil) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
```

### Type Scale Abstraction

```swift
public struct KikobarFont {
    public static func bold(size: CGFloat) -> Font {
        Font.custom("Poppins-Bold", size: size)
    }

    public static func semiBold(size: CGFloat) -> Font {
        Font.custom("Poppins-SemiBold", size: size)
    }

    public static func medium(size: CGFloat) -> Font {
        Font.custom("Poppins-Medium", size: size)
    }

    public static func regular(size: CGFloat) -> Font {
        Font.custom("Poppins-Regular", size: size)
    }
}
```

If custom fonts are unavailable, the engine falls back to Apple's system font (`.system(size:weight:)`), guaranteeing text never fails to render.

---

## 3. SwiftUI Component Hierarchy

The interface structure is composed of modular SwiftUI views:

```
┌─────────────────────────────────────────────────────────────┐
│ PanelContainerView (Root Container + Blur Material)         │
│                                                             │
│  ┌──────────────┐ ┌───────────────────────────────────────┐ │
│  │ ResizeHandle │ │ RightSidebarView                      │ │
│  │ (Left border │ │                                       │ │
│  │  drag bar)   │ │  ┌─────────────────────────────────┐  │ │
│  │              │ │  │ Header (Logo + Title + Collapse)│  │ │
│  │              │ │  └─────────────────────────────────┘  │ │
│  │              │ │                                       │ │
│  │              │ │  ┌─────────────────────────────────┐  │ │
│  │              │ │  │ ScrollView (Board Cards)        │  │ │
│  │              │ │  │                                 │  │ │
│  │              │ │  │  ┌───────────────────────────┐  │  │ │
│  │              │ │  │  │ BoardCardView (Expanded)  │  │  │ │
│  │              │ │  │  │  - Swatch + Title + Count │  │  │ │
│  │              │ │  │  │  - BoardMediaGridView     │  │  │ │
│  │              │ │  │  │    [Card 1] [Card 2]      │  │  │ │
│  │              │ │  │  └───────────────────────────┘  │  │ │
│  │              │ │  │                                 │  │ │
│  │              │ │  │  ┌───────────────────────────┐  │  │ │
│  │              │ │  │  │ BoardCardView (Collapsed) │  │  │ │
│  │              │ │  │  └───────────────────────────┘  │  │ │
│  │              │ │  │                                 │  │ │
│  │              │ │  │  [Empty Space Drop Area]     │  │  │ │
│  │              │ │  └─────────────────────────────────┘  │  │ │
│  │              │ │                                       │ │
│  │              │ │  ┌─────────────────────────────────┐  │ │
│  │              │ │  │ BottomControlsBar               │  │ │
│  │              │ │  │  [+] New Board  [☀/☾]  [⚙]      │  │ │
│  │              │ │  └─────────────────────────────────┘  │ │
│  │              │ └───────────────────────────────────────┘ │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Key Component Implementations

### A. Root Container & Window Resizing (`PanelContainerView.swift`)

The root container hosts the sidebar, applies the background material, and embeds the interactive left resize handle:

```swift
public struct PanelContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager = ThemeManager.shared

    public var body: some View {
        HStack(spacing: 0) {
            // Interactive Left Edge Resize Handle
            ResizeHandleView(currentWidth: $coordinator.panelWidth) { newWidth in
                ScreenGeometry.userPanelWidth = newWidth
            }

            // Main Sidebar Content
            RightSidebarView(coordinator: coordinator)
                .frame(width: coordinator.panelWidth)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.drawer))
    }
}
```

### B. Board Card View (`BoardCardView.swift`)

Each board is rendered as a clean card featuring:
- An interactive color swatch that toggles the circular palette popover.
- An inline editable text field for renaming.
- An item count pill badge.
- An expansion toggle chevron.
- Drag-and-drop targeting cues.

```swift
public struct BoardCardView: View {
    @ObservedObject var board: Board
    @ObservedObject var coordinator: AppCoordinator
    @State private var isShowingColorPicker: Bool = false
    @State private var isHovering: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Board Header
            HStack(spacing: 8) {
                // Circular Color Indicator (Toggles Color Popover)
                Circle()
                    .fill(Color(hex: board.hexColor))
                    .frame(width: 12, height: 12)
                    .onTapGesture { isShowingColorPicker.toggle() }
                    .popover(isPresented: $isShowingColorPicker) {
                        BoardColorPickerPopover(selectedHex: board.hexColor) { newColor in
                            Task { await coordinator.updateBoardColor(id: board.id, hexColor: newColor) }
                        }
                    }

                // Board Name (or Inline Text Editor)
                if coordinator.editingBoardID == board.id {
                    InlineBoardNameEditor(board: board, coordinator: coordinator)
                } else {
                    Text(board.name)
                        .font(KikobarFont.medium(size: 13))
                        .lineLimit(1)
                }

                Spacer()

                // Item Count Badge
                Text("\(coordinator.itemsByBoard[board.id]?.count ?? 0)")
                    .font(KikobarFont.regular(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())

                // Collapse / Expand Chevron
                Image(systemName: board.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .onTapGesture {
                        Task { await coordinator.toggleBoardExpansion(id: board.id) }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Media Grid (if expanded)
            if board.isExpanded {
                BoardMediaGridView(boardID: board.id, coordinator: coordinator)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .background(themeManager.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(isHovering ? Color(hex: board.hexColor) : themeManager.borderColor, lineWidth: 1)
        )
    }
}
```

### C. Circular 10-Color Palette Popover (`BoardColorPickerPopover.swift`)

Displays the curated color palette in a clean 5×2 circular swatch grid:

```swift
public struct BoardColorPickerPopover: View {
    let selectedHex: String
    let onSelectColor: (String) -> Void

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 5), spacing: 8) {
            ForEach(DesignSystem.Colors.boardPalette, id: \.self) { hex in
                ZStack {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)

                    if hex.uppercased() == selectedHex.uppercased() {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                }
                .onTapGesture { onSelectColor(hex) }
            }
        }
        .padding(12)
    }
}
```

### D. Themed Board Deletion Modal (`BoardDeletionDialogView.swift`)

When a user requests to delete a board, Kikobar presents an alert modal:

```swift
public struct BoardDeletionDialogView: View {
    let board: Board
    let itemCount: Int
    let onCancel: () -> Void
    let onConfirmDelete: () -> Void

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(.red)

            Text("Delete '\(board.name)'?")
                .font(KikobarFont.bold(size: 15))

            Text("This will permanently delete this board and its \(itemCount) collected items. This action cannot be undone.")
                .font(KikobarFont.regular(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)

                Button("Delete Board", action: onConfirmDelete)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
        .padding(20)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
```

---

## 5. Native QuickLook Spacebar Preview Integration

macOS users expect the **Spacebar** key to immediately preview any highlighted file or media asset.

### Bridging QuickLook to Floating Panels (`QuickLookCoordinator.swift`)

Because `CollectionPanelWindow` is a floating `.nonactivatingPanel`, standard `NSResponder` responder chains do not automatically wire up `QLPreviewPanel`. Kikobar bridges this via a custom coordinator:

```swift
@MainActor
public final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookCoordinator()
    public var previewItems: [URL] = []

    public func togglePreview(for urls: [URL]) {
        self.previewItems = urls
        guard let panel = QLPreviewPanel.shared() else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewItems[index] as NSURL
    }
}
```

In `RightSidebarView.swift`, keyboard events are intercepted cleanly using SwiftUI's `.onKeyPress`:

```swift
.onKeyPress(.space) {
    coordinator.quickLookSelectedItems()
    return .handled
}
.onKeyPress(.return) {
    if let item = coordinator.firstSelectedItem {
        coordinator.openItem(item)
        return .handled
    }
    return .ignored
}
.onKeyPress(.delete) {
    Task { await coordinator.deleteSelectedItems() }
    return .handled
}
```

---

Continue to [**Module 06: Step-by-Step Implementation Guide**](06-Step-by-Step-Implementation-Guide.md) for the end-to-end recipe to build this application from scratch.
