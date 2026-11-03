import SwiftUI

/// Scrollable container rendering all categories and inline new category creation.
public struct CategoryListView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var themeManager: ThemeManager

    @State private var isCreatingCategory: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryHex: String = "#8B7CFF"
    @State private var isAddButtonHovered: Bool = false

    public init(coordinator: AppCoordinator, themeManager: ThemeManager? = nil) {
        self.coordinator = coordinator
        self.themeManager = themeManager ?? (coordinator.environment.themeManager as? ThemeManager) ?? ThemeManager()
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // New Category Creation Bar
                if isCreatingCategory {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("Category Name", text: $newCategoryName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(themeManager.panelBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(HexColor.toColor(hex: newCategoryHex).opacity(0.6), lineWidth: 1)
                                )
                                .onSubmit {
                                    createNewCategory()
                                }

                            Button("Create") {
                                createNewCategory()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(HexColor.toColor(hex: newCategoryHex))
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Cancel") {
                                withAnimation(DesignSystem.Animation.hoverHighlight) {
                                    isCreatingCategory = false
                                    newCategoryName = ""
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                        }

                        ColorPickerHexView(selectedHex: $newCategoryHex)
                    }
                    .padding(12)
                    .background(themeManager.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(HexColor.toColor(hex: newCategoryHex).opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: HexColor.toColor(hex: newCategoryHex).opacity(0.2), radius: 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Category Rows
                ForEach(coordinator.categories) { category in
                    CategoryRowView(
                        category: category,
                        items: coordinator.itemsByCategory[category.id] ?? [],
                        coordinator: coordinator,
                        themeManager: themeManager
                    )
                }

                // Add Category Button
                if !isCreatingCategory {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isCreatingCategory = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                            Text("New Category")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isAddButtonHovered ? themeManager.accentColor : themeManager.secondaryTextColor)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(isAddButtonHovered ? themeManager.accentColor.opacity(0.12) : themeManager.cardBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isAddButtonHovered ? themeManager.accentColor.opacity(0.4) : themeManager.borderColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DesignSystem.Animation.hoverHighlight) {
                            isAddButtonHovered = hovering
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func createNewCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        Task {
            _ = try? await coordinator.createCategory(name: name, hexColor: newCategoryHex)
            newCategoryName = ""
            withAnimation(DesignSystem.Animation.hoverHighlight) {
                isCreatingCategory = false
            }
        }
    }
}
