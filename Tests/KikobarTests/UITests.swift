import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Kikobar

@Suite("UI and Interaction Design Tests")
struct UITests {

    // MARK: - Theme Manager Tests

    @Test("ThemeManager initializes to dark mode by default")
    @MainActor
    func themeManagerDefaultInitialization() {
        let testDefaults = UserDefaults(suiteName: "test.theme.default.\(UUID().uuidString)")!
        let manager = ThemeManager(initialMode: .dark, userDefaults: testDefaults)

        #expect(manager.currentTheme == .dark)
    }

    @Test("ThemeManager toggles correctly between dark and light modes")
    @MainActor
    func themeManagerToggling() {
        let testDefaults = UserDefaults(suiteName: "test.theme.toggle.\(UUID().uuidString)")!
        let manager = ThemeManager(initialMode: .dark, userDefaults: testDefaults)

        #expect(manager.currentTheme == .dark)
        manager.toggleTheme()
        #expect(manager.currentTheme == .light)
        manager.toggleTheme()
        #expect(manager.currentTheme == .dark)
    }

    @Test("ThemeManager persists theme changes across instances")
    @MainActor
    func themeManagerPersistence() {
        let suiteName = "test.theme.persist.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!

        let manager1 = ThemeManager(initialMode: .dark, userDefaults: testDefaults)
        #expect(manager1.currentTheme == .dark)
        manager1.toggleTheme()
        #expect(manager1.currentTheme == .light)

        let manager2 = ThemeManager(initialMode: .dark, userDefaults: testDefaults)
        #expect(manager2.currentTheme == .light)
    }

    @Test("ThemeManager produces correct palette colors in Dark mode")
    @MainActor
    func themeManagerDarkColors() {
        let testDefaults = UserDefaults(suiteName: "test.theme.dark.\(UUID().uuidString)")!
        let manager = ThemeManager(initialMode: .dark, userDefaults: testDefaults)

        let expectedPanel = HexColor.toColor(hex: "#161618")
        let expectedCard = HexColor.toColor(hex: "#202024")
        let expectedBorder = HexColor.toColor(hex: "#2E2E34")
        let expectedPrimaryText = HexColor.toColor(hex: "#EEEEF0")
        let expectedAccent = HexColor.toColor(hex: "#8B7CFF")

        #expect(manager.panelBackground == expectedPanel)
        #expect(manager.cardBackground == expectedCard)
        #expect(manager.borderColor == expectedBorder)
        #expect(manager.primaryTextColor == expectedPrimaryText)
        #expect(manager.accentColor == expectedAccent)
    }

    @Test("ThemeManager produces correct palette colors in Light mode")
    @MainActor
    func themeManagerLightColors() {
        let testDefaults = UserDefaults(suiteName: "test.theme.light.\(UUID().uuidString)")!
        let manager = ThemeManager(initialMode: .light, userDefaults: testDefaults)

        let expectedPanel = HexColor.toColor(hex: "#F5F5F7")
        let expectedCard = Color.white
        let expectedBorder = HexColor.toColor(hex: "#E0E0E6")
        let expectedPrimaryText = HexColor.toColor(hex: "#1C1C1E")
        let expectedAccent = HexColor.toColor(hex: "#8B7CFF")

        #expect(manager.panelBackground == expectedPanel)
        #expect(manager.cardBackground == expectedCard)
        #expect(manager.borderColor == expectedBorder)
        #expect(manager.primaryTextColor == expectedPrimaryText)
        #expect(manager.accentColor == expectedAccent)
    }

    // MARK: - Design System Tests

    @Test("DesignSystem contains valid geometry and animation definitions")
    func designSystemColorsAndSpacing() {
        #expect(DesignSystem.CornerRadius.small == 6.0)
        #expect(DesignSystem.CornerRadius.medium == 10.0)
        #expect(DesignSystem.CornerRadius.large == 14.0)
        #expect(DesignSystem.CornerRadius.panel == 18.0)

        #expect(DesignSystem.Spacing.xxs == 2.0)
        #expect(DesignSystem.Spacing.xs == 4.0)
        #expect(DesignSystem.Spacing.small == 8.0)
        #expect(DesignSystem.Spacing.medium == 12.0)
        #expect(DesignSystem.Spacing.large == 16.0)
        #expect(DesignSystem.Spacing.xl == 24.0)
    }

    // MARK: - Color Picker & HEX Validation Tests

    @Test("HEX validation correctly identifies 3, 6, and invalid hex codes")
    func hexValidation() {
        // Valid 3-char
        #expect(HexColor.isValid(hex: "#FFF"))
        #expect(HexColor.isValid(hex: "FFF"))
        #expect(HexColor.isValid(hex: "#F00"))
        #expect(HexColor.isValid(hex: "8BA"))

        // Valid 6-char
        #expect(HexColor.isValid(hex: "#8B7CFF"))
        #expect(HexColor.isValid(hex: "8B7CFF"))
        #expect(HexColor.isValid(hex: "#FF5E7E"))
        #expect(HexColor.isValid(hex: "00B4D8"))

        // Invalid
        #expect(!HexColor.isValid(hex: "#ZZZZZZ"))
        #expect(!HexColor.isValid(hex: "12345"))
        #expect(!HexColor.isValid(hex: "invalid"))
        #expect(!HexColor.isValid(hex: ""))
        #expect(!HexColor.isValid(hex: "#"))
    }

    @Test("HEX sanitization normalizes 3-char codes to full 6-char canonical hex")
    func hexSanitization() {
        #expect(HexColor.sanitize(hex: "#F00") == "#FF0000")
        #expect(HexColor.sanitize(hex: "abc") == "#AABBCC")
        #expect(HexColor.sanitize(hex: "8b7cff") == "#8B7CFF")
        #expect(HexColor.sanitize(hex: "#8b7cff") == "#8B7CFF")
    }

    // MARK: - Collection Panel Window & Controller Tests

    @Test("CollectionPanelWindow is configured as a floating borderless non-activating panel")
    @MainActor
    func collectionPanelWindowConfiguration() {
        let window = CollectionPanelWindow(contentRect: NSRect(x: 100, y: 100, width: 340, height: 600))

        #expect(window.level == .floating)
        #expect(window.styleMask.contains(.borderless))
        #expect(window.styleMask.contains(.nonactivatingPanel))
        #expect(window.isOpaque == false)
        #expect(window.backgroundColor == .clear)
        #expect(window.hasShadow == true)
        #expect(window.canBecomeKey == true)
        #expect(window.canBecomeMain == false)
    }

    @Test("CollectionPanelWindow invokes onEscapePressed when cancelOperation is called")
    @MainActor
    func collectionPanelWindowEscapeHandling() {
        let window = CollectionPanelWindow(contentRect: NSRect(x: 100, y: 100, width: 340, height: 600))
        var escapeTriggered = false
        window.onEscapePressed = {
            escapeTriggered = true
        }

        window.cancelOperation(nil)
        #expect(escapeTriggered == true)
    }

    @Test("CollectionPanelController instantiates window and manages visibility state")
    @MainActor
    func collectionPanelControllerLifecycle() {
        let env = AppEnvironment(
            dragIngestionService: StubDragIngestionService(),
            categoryRepository: InMemoryCategoryRepository(),
            collectionRepository: InMemoryCollectionRepository(),
            fileStorageService: InMemoryFileStorageService(),
            thumbnailService: QuickLookThumbnailService(),
            themeManager: ThemeManager()
        )
        let coordinator = AppCoordinator(environment: env)
        let themeManager = ThemeManager()
        let controller = CollectionPanelController(coordinator: coordinator, themeManager: themeManager)

        #expect(controller.panelWindow.contentViewController != nil)
        #expect(controller.panelWindow.level == .floating)

        // Show panel
        controller.show()
        #expect(controller.panelWindow.isVisible == true)

        // Hide panel
        controller.hide()
    }

    // MARK: - SwiftUI View Instantiation & State Tests

    @Test("CategoryDropTargetView renders with category accent color and targeting states")
    @MainActor
    func categoryDropTargetViewInstantiation() {
        let category = CollectionCategory(name: "Design", hexColor: "#FF5E7E")
        let targetViewIdle = CategoryDropTargetView(category: category, isTargeted: false)
        let targetViewActive = CategoryDropTargetView(category: category, isTargeted: true)

        #expect(targetViewIdle.isTargeted == false)
        #expect(targetViewActive.isTargeted == true)
        #expect(targetViewIdle.category.hexColor == "#FF5E7E")
    }

    @Test("CategoryRowView and CategoryListView render with correct category and item mappings")
    @MainActor
    func categoryViewStructure() async throws {
        let env = AppEnvironment(
            dragIngestionService: StubDragIngestionService(),
            categoryRepository: InMemoryCategoryRepository(),
            collectionRepository: InMemoryCollectionRepository(),
            fileStorageService: InMemoryFileStorageService(),
            thumbnailService: QuickLookThumbnailService(),
            themeManager: ThemeManager()
        )
        let coordinator = AppCoordinator(environment: env)
        await coordinator.start()

        let category = try await coordinator.createCategory(name: "Projects", hexColor: "#00B4D8")
        let rowView = CategoryRowView(
            category: category,
            items: [],
            coordinator: coordinator
        )

        #expect(rowView.category.name == "Projects")
        #expect(rowView.category.hexColor == "#00B4D8")
        #expect(rowView.items.isEmpty)

        let listView = CategoryListView(coordinator: coordinator)
        #expect(listView.coordinator.categories.contains(where: { $0.id == category.id }))
    }

    @Test("ThemeToggleView renders and switches ThemeManager modes")
    @MainActor
    func themeToggleViewBehavior() {
        let testDefaults = UserDefaults(suiteName: "test.themetoggle.view.\(UUID().uuidString)")!
        let themeManager = ThemeManager(initialMode: .dark, userDefaults: testDefaults)
        let toggleView = ThemeToggleView(themeManager: themeManager)

        #expect(toggleView.themeManager.currentTheme == .dark)
        themeManager.toggleTheme()
        #expect(toggleView.themeManager.currentTheme == .light)
    }

    @Test("PanelContainerView configures root drawer container")
    @MainActor
    func panelContainerViewSetup() {
        let env = AppEnvironment(
            dragIngestionService: StubDragIngestionService(),
            categoryRepository: InMemoryCategoryRepository(),
            collectionRepository: InMemoryCollectionRepository(),
            fileStorageService: InMemoryFileStorageService(),
            thumbnailService: QuickLookThumbnailService(),
            themeManager: ThemeManager()
        )
        let coordinator = AppCoordinator(environment: env)
        let themeManager = ThemeManager()
        let container = PanelContainerView(coordinator: coordinator, themeManager: themeManager)

        #expect(container.coordinator === coordinator)
        #expect(container.themeManager === themeManager)
    }
}
