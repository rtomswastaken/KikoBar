import SwiftUI

/// Individual category row supporting collapse/expand, item count badge, color indicators, hover glow, and editing.
public struct CategoryRowView: View {
    public let category: CollectionCategory
    public let items: [CollectionItem]
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var editedHex: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var isHovered: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    public init(
        category: CollectionCategory,
        items: [CollectionItem],
        coordinator: AppCoordinator,
        themeManager: ThemeManager? = nil
    ) {
        self.category = category
        self.items = items
        self.coordinator = coordinator
        self.themeManager = themeManager ?? (coordinator.environment.themeManager as? ThemeManager) ?? ThemeManager()
    }

    public var body: some View {
        let categoryColor = HexColor.toColor(hex: category.hexColor)

        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(spacing: 8) {
                // Color Pill & Expand Button
                Button(action: {
                    Task {
                        await coordinator.toggleCategoryExpansion(id: category.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor)
                            .frame(width: 10, height: 10)
                            .shadow(color: categoryColor.opacity(0.6), radius: 2)

                        Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                .buttonStyle(.plain)

                // Category Name
                if isEditing {
                    TextField("Category Name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(themeManager.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(categoryColor, lineWidth: 1)
                        )
                        .onSubmit {
                            saveEdits()
                        }
                } else {
                    Text(category.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.primaryTextColor)
                }

                Spacer()

                // Item Count Badge
                Text("\(items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.18))
                    .foregroundColor(categoryColor)
                    .clipShape(Capsule())

                // Action Controls
                if isEditing {
                    HStack(spacing: 6) {
                        Button(action: saveEdits) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Save changes (Return)")

                        Button(action: cancelEdits) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(themeManager.secondaryTextColor)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .help("Cancel")
                    }
                } else {
                    Menu {
                        Button("Edit Category") {
                            startEditing()
                        }
                        Divider()
                        Button("Delete Category", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isHovered ? themeManager.primaryTextColor : themeManager.secondaryTextColor)
                            .frame(width: 18, height: 18)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 18)
                }
            }

            // Inline Color Editor when editing
            if isEditing {
                ColorPickerHexView(selectedHex: $editedHex)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
            }

            // Drop Target Zone
            CategoryDropTargetView(category: category, isTargeted: isDropTargeted, themeManager: themeManager)
                .onDrop(of: [.item, .fileURL, .url, .utf8PlainText], isTargeted: $isDropTargeted) { providers in
                    AppLogger.drag.info("Items dropped into category \(category.name)")
                    let dragPasteboard = NSPasteboard(name: .drag)
                    let pasteboardToUse: NSPasteboard
                    if let types = dragPasteboard.types, !types.isEmpty {
                        pasteboardToUse = dragPasteboard
                    } else {
                        pasteboardToUse = NSPasteboard.general
                    }
                    Task {
                        await coordinator.handleDrop(pasteboard: pasteboardToUse, into: category.id)
                    }
                    return true
                }

            // Expandable Items List
            if category.isExpanded {
                if items.isEmpty {
                    HStack {
                        Text("No items collected yet")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                            .padding(.vertical, 4)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 4) {
                        ForEach(items) { item in
                            ItemThumbnailView(item: item, coordinator: coordinator, themeManager: themeManager)
                        }
                    }
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(10)
        .background(isHovered ? themeManager.cardBackground : themeManager.cardBackground.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isDropTargeted ? categoryColor : (isHovered ? categoryColor.opacity(0.65) : themeManager.borderColor),
                    lineWidth: isDropTargeted ? 2.0 : (isHovered ? 1.5 : 1.0)
                )
        )
        .shadow(
            color: categoryColor.opacity(isDropTargeted ? 0.45 : (isHovered ? 0.25 : 0.0)),
            radius: isDropTargeted ? 10 : (isHovered ? 6 : 0),
            x: 0,
            y: 0
        )
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.hoverHighlight) {
                isHovered = hovering
            }
        }
        .confirmationDialog(
            "Delete \"\(category.name)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Category", role: .destructive) {
                Task {
                    try? await coordinator.deleteCategory(id: category.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this category? All items in this category will be removed from Kikobar.")
        }
    }

    private func startEditing() {
        editedName = category.name
        editedHex = category.hexColor
        isEditing = true
    }

    private func cancelEdits() {
        isEditing = false
        editedName = ""
        editedHex = ""
    }

    private func saveEdits() {
        var updated = category
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? category.name : trimmed
        updated.hexColor = HexColor.sanitize(hex: editedHex)
        updated.updatedAt = Date()
        isEditing = false

        Task {
            try? await coordinator.updateCategory(updated)
        }
    }
}
