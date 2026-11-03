import AppKit
import Combine
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var coordinator: AppCoordinator!
    public private(set) var themeManager: ThemeManager!
    public private(set) var panelController: CollectionPanelController!
    public private(set) var triggerWindows: [TriggerZoneWindow] = []
    public private(set) var edgeHandleWindows: [EdgeHandleWindow] = []
    public private(set) var statusItem: NSStatusItem?

    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        KikobarFont.registerFonts()
        NSApp.setActivationPolicy(.regular) // Native macOS application with Dock icon, menu bar, and floating side panel

        setupMainMenu()

        let themeMgr = ThemeManager()
        self.themeManager = themeMgr

        let fileStorage = LocalFileStorageService()
        let dragService = DragIngestionService(fileStorageService: fileStorage)

        let database: SQLiteDatabase
        do {
            database = try SQLiteDatabase()
        } catch {
            AppLogger.persistence.fault("Failed to initialize SQLite database: \(error.localizedDescription)")
            fatalError("Failed to initialize SQLite database: \(error)")
        }

        let categoryRepo = SQLiteCategoryRepository(database: database, fileStorageService: fileStorage)
        let collectionRepo = SQLiteCollectionRepository(database: database, fileStorageService: fileStorage)

        let environment = AppEnvironment(
            dragIngestionService: dragService,
            categoryRepository: categoryRepo,
            collectionRepository: collectionRepo,
            fileStorageService: fileStorage,
            thumbnailService: QuickLookThumbnailService(),
            themeManager: themeMgr
        )

        let coord = AppCoordinator(environment: environment)
        self.coordinator = coord

        // Instantiate the native floating side panel (starts collapsed/hidden by default)
        self.panelController = CollectionPanelController(coordinator: coord, themeManager: themeMgr)

        DragSessionManager.shared.coordinator = coord
        DragSessionManager.shared.panelController = self.panelController

        setupStatusItem()
        setupEdgeHandleWindows()
        setupTriggerWindows()
        setupScreenNotifications()
        bindCoordinator()

        DragSessionManager.shared.startMouseMonitoring()

        Task {
            await coord.start()
        }

        AppLogger.general.info("Kikobar side panel initialized successfully.")
    }

    private func setupEdgeHandleWindows() {
        edgeHandleWindows.forEach { $0.close() }
        edgeHandleWindows.removeAll()

        for screen in NSScreen.screens {
            let win = EdgeHandleWindow(screen: screen) { [weak self] in
                self?.panelController.expand(on: screen)
            }
            win.orderFrontRegardless()
            edgeHandleWindows.append(win)
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Kikobar", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Toggle Panel", action: #selector(statusItemClicked), keyEquivalent: "k")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Kikobar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New Board", action: #selector(newBoardAction), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Close", action: #selector(closeAction), keyEquivalent: "w")

        // 3. Edit Menu (Standard macOS Copy/Paste)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Copy", action: #selector(copyAction), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(pasteAction), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(selectAllAction), keyEquivalent: "a")
        editMenu.addItem(withTitle: "Delete", action: #selector(deleteAction), keyEquivalent: "\u{08}")

        // 4. View Menu (Quick Look)
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Quick Look", action: #selector(quickLookAction), keyEquivalent: " ")

        NSApp.mainMenu = mainMenu
    }

    @objc private func newBoardAction() {
        Task { @MainActor in
            _ = await coordinator.createNewBoardInteractive()
        }
    }

    @objc private func closeAction() {
        panelController.collapse()
    }

    @objc private func copyAction() {
        coordinator.copySelectedItems()
    }

    @objc private func pasteAction() {
        Task { @MainActor in
            await coordinator.pasteFromClipboard()
        }
    }

    @objc private func selectAllAction() {
        let allIDs = coordinator.itemsByBoard.values.flatMap { $0 }.map { $0.id }
        coordinator.selectedItemIDs = Set(allIDs)
    }

    @objc private func deleteAction() {
        Task { @MainActor in
            await coordinator.deleteSelectedItems()
        }
    }

    @objc private func quickLookAction() {
        coordinator.quickLookSelectedItems()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController.expand()
        panelController.panelWindow.orderFrontRegardless()
        return true
    }

    private func setupScreenNotifications() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLogger.drag.info("Display layout changed; recalculating trigger zones...")
                self?.setupTriggerWindows()
                self?.setupEdgeHandleWindows()
                self?.panelController.reposition()
            }
            .store(in: &cancellables)
    }

    private func setupTriggerWindows() {
        triggerWindows.forEach { $0.close() }
        triggerWindows.removeAll()

        for screen in NSScreen.screens {
            let frame = ScreenGeometry.triggerFrame(for: screen)
            let win = TriggerZoneWindow(contentRect: frame)

            let destView = TriggerZoneDestinationView(frame: NSRect(origin: .zero, size: frame.size))
            destView.autoresizingMask = [.width, .height]
            destView.onDragEntered = { [weak self] targetScreen in
                Task { @MainActor in
                    self?.coordinator.dragDetected(on: targetScreen.localizedName)
                    self?.panelController.expand(on: targetScreen)
                }
            }
            destView.onDragCancelled = { [weak self] in
                Task { @MainActor in
                    self?.coordinator.dragSessionEnded()
                }
            }

            win.contentView = destView
            win.orderFrontRegardless()
            triggerWindows.append(win)
        }

        DragSessionManager.shared.triggerWindows = triggerWindows
    }

    private func bindCoordinator() {
        coordinator.$isPanelVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible {
                    self?.panelController.expand()
                } else {
                    self?.panelController.collapse()
                }
            }
            .store(in: &cancellables)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Kikobar Drawer")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        self.statusItem = item
    }

    @objc private func statusItemClicked() {
        coordinator.togglePanel()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppLogger.general.info("Kikobar terminating.")
    }
}
