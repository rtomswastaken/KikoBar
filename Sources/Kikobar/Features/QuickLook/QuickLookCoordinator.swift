import AppKit
import Foundation
import QuickLookUI

/// Coordinates native macOS Quick Look previews for collection items.
@MainActor
public final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookCoordinator()

    public private(set) var currentURLs: [URL] = []

    public override init() {
        super.init()
    }

    // MARK: - QLPreviewPanelDataSource

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentURLs.count
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index < currentURLs.count else { return nil }
        return currentURLs[index] as NSURL
    }

    // MARK: - Preview Lifecycle

    /// Toggles or updates the Quick Look panel for the provided file URLs.
    public func toggleQuickLook(for urls: [URL]) {
        guard !urls.isEmpty else {
            closeQuickLook()
            return
        }

        self.currentURLs = urls

        guard let panel = QLPreviewPanel.shared() else { return }

        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.reloadData()
        } else {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Closes the Quick Look panel if currently open.
    public func closeQuickLook() {
        if QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared()?.orderOut(nil)
        }
        currentURLs = []
    }
}
