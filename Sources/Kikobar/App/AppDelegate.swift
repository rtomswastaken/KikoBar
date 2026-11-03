import AppKit
import Combine
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public private(set) var coordinator: AppCoordinator!
    public private(set) var themeManager: ThemeManager!
    public private(set) var panelController: CollectionPanelController!
    public private(set) var triggerWindows: [TriggerZoneWindow] = []

    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Runs as a lightweight menu/floating accessory utility

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

        self.panelController = CollectionPanelController(coordinator: coord, themeManager: themeMgr)

        setupTriggerWindows()
        setupScreenNotifications()
        bindCoordinator()

        Task {
            await coord.start()
        }

        AppLogger.general.info("Kikobar initialized successfully.")
    }

    private func setupScreenNotifications() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                AppLogger.drag.info("Display layout changed; recalculating trigger zones...")
                self?.setupTriggerWindows()
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
                    self?.coordinator.showPanel()
                    self?.panelController.show(on: targetScreen)
                }
            }
            destView.onDragCancelled = { [weak self] in
                Task { @MainActor in
                    // If not currently hovering over a drop category, dismiss panel
                    if self?.coordinator.activeHoverCategoryID == nil {
                        self?.coordinator.hidePanel()
                    }
                }
            }

            win.contentView = destView
            win.orderFrontRegardless()
            triggerWindows.append(win)
        }
    }

    private func bindCoordinator() {
        coordinator.$isPanelVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible {
                    self?.panelController.show()
                } else {
                    self?.panelController.hide()
                }
            }
            .store(in: &cancellables)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        AppLogger.general.info("Kikobar terminating.")
    }
}
