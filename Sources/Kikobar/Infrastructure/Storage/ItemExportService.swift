import AppKit
import Foundation
import UniformTypeIdentifiers

/// Coordinates file resolution, export representations, drag-out operations,
/// and standard macOS pasteboard clipboard integrations for CollectionItems.
@MainActor
public final class ItemExportService {
    public static let shared = ItemExportService()

    private let fileManager = FileManager.default

    public init() {}

    // MARK: - File Resolution

    /// Resolves the actual filesystem URL for a collection item.
    /// Supports managed storage files, security-scoped bookmark references,
    /// direct local file URLs, and synthesized text snippet files.
    public func resolveFileURL(for item: CollectionItem) -> URL? {
        // 1. Managed filesystem storage path
        if let localPath = item.localPath {
            let standardized = (localPath as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: standardized) {
                return URL(fileURLWithPath: standardized)
            }
        }

        // 2. Security-Scoped Bookmark for externally referenced files
        if let bookmarkData = item.bookmarkData {
            do {
                let resolved = try SecurityScopedBookmarkManager.shared.resolveBookmark(data: bookmarkData)
                if fileManager.fileExists(atPath: resolved.url.path) {
                    _ = SecurityScopedBookmarkManager.shared.startAccessingSecurityScopedResource(for: resolved.url)
                    return resolved.url
                }
            } catch {
                AppLogger.storage.warning("Security-scoped bookmark resolution failed for '\(item.name)': \(error.localizedDescription)")
            }
        }

        // 3. Direct local file URL if available and accessible
        if let sourceURL = item.sourceURL, sourceURL.isFileURL {
            if fileManager.fileExists(atPath: sourceURL.path) {
                return sourceURL
            }
        }

        // 4. Synthesize exportable plain text file for text snippets without an existing disk copy
        if let text = item.textContent {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("KikobarExports", isDirectory: true)
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let safeName = item.name.hasSuffix(".txt") ? item.name : "\(item.name).txt"
            let tempURL = tempDir.appendingPathComponent(safeName)
            if !fileManager.fileExists(atPath: tempURL.path) {
                try? text.write(to: tempURL, atomically: true, encoding: .utf8)
            }
            return tempURL
        }

        return nil
    }

    // MARK: - Drag Out (NSItemProvider)

    /// Creates an NSItemProvider for dragging an item out of Kikobar into Finder, Desktop, or other apps.
    public func createItemProvider(for item: CollectionItem) -> NSItemProvider {
        // Case 1: Real file (managed storage, external referenced document/image/pdf/folder)
        if let fileURL = resolveFileURL(for: item) {
            let provider = NSItemProvider(contentsOf: fileURL) ?? NSItemProvider()
            provider.suggestedName = item.name

            // Supplementary representations for versatile destination drop acceptance
            if let text = item.textContent {
                provider.registerObject(text as NSString, visibility: .all)
            }
            if let sourceURL = item.sourceURL, !sourceURL.isFileURL {
                provider.registerObject(sourceURL as NSURL, visibility: .all)
            }
            return provider
        }

        // Case 2: Web URL / Hyperlink
        if let sourceURL = item.sourceURL {
            let provider = NSItemProvider(object: sourceURL as NSURL)
            provider.registerObject(sourceURL.absoluteString as NSString, visibility: .all)
            provider.suggestedName = item.name
            return provider
        }

        // Case 3: Text Snippet
        if let text = item.textContent {
            let provider = NSItemProvider(object: text as NSString)
            provider.suggestedName = item.name
            return provider
        }

        // Case 4: Fallback for missing/corrupted references: provide name as string representation
        let fallbackProvider = NSItemProvider(object: item.name as NSString)
        fallbackProvider.suggestedName = item.name
        return fallbackProvider
    }

    // MARK: - Copy and Paste (macOS Pasteboard)

    /// Copies one or multiple items to the standard macOS pasteboard.
    /// Provides real file URLs for Finder, images for graphics apps, and strings for text editors.
    public func copyToPasteboard(items: [CollectionItem], pasteboard: NSPasteboard = .general) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()

        var objectsToWrite: [NSPasteboardWriting] = []

        for item in items {
            if let fileURL = resolveFileURL(for: item) {
                objectsToWrite.append(fileURL as NSURL)

                // If image, also write NSImage so applications like Preview (Cmd+N) or Photoshop paste raw pixels
                if item.contentType == .image, let image = NSImage(contentsOf: fileURL) {
                    objectsToWrite.append(image)
                }
            } else if let sourceURL = item.sourceURL {
                objectsToWrite.append(sourceURL as NSURL)
                objectsToWrite.append(sourceURL.absoluteString as NSString)
            } else if let text = item.textContent {
                objectsToWrite.append(text as NSString)
            }
        }

        pasteboard.writeObjects(objectsToWrite)
        AppLogger.storage.info("Copied \(items.count) item(s) to pasteboard (\(pasteboard.name.rawValue)).")
    }

    /// Specifically formats the pasteboard as a file copy for Finder pasting.
    public func copyFileReference(item: CollectionItem, pasteboard: NSPasteboard = .general) {
        guard let fileURL = resolveFileURL(for: item) else { return }
        pasteboard.clearContents()

        var objects: [NSPasteboardWriting] = [fileURL as NSURL]
        if item.contentType == .image, let image = NSImage(contentsOf: fileURL) {
            objects.append(image)
        }

        pasteboard.writeObjects(objects)
        AppLogger.storage.info("Copied file reference for '\(item.name)' to pasteboard.")
    }

    // MARK: - Open & Finder Integration

    /// Opens the item using macOS default application for its file or content type.
    public func openItem(_ item: CollectionItem) {
        if let fileURL = resolveFileURL(for: item) {
            NSWorkspace.shared.open(fileURL)
        } else if let sourceURL = item.sourceURL {
            NSWorkspace.shared.open(sourceURL)
        } else if let text = item.textContent {
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("KikobarExports", isDirectory: true)
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempURL = tempDir.appendingPathComponent("\(item.name).txt")
            try? text.write(to: tempURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempURL)
        }
    }

    /// Reveals the underlying file in Finder.
    public func revealInFinder(_ item: CollectionItem) {
        if let fileURL = resolveFileURL(for: item) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else if let sourceURL = item.sourceURL {
            NSWorkspace.shared.open(sourceURL)
        }
    }
}
