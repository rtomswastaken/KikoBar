import AppKit
import Foundation

/// Defines asynchronous thumbnail generation and caching for collection items.
public protocol ThumbnailServiceProtocol: AnyObject, Sendable {
    /// Generates or fetches a cached thumbnail image for a file URL or image data.
    func generateThumbnail(for url: URL, targetSize: CGSize) async -> NSImage?

    /// Generates or fetches a cached thumbnail for an item and writes it to disk if appropriate.
    func generateThumbnail(for item: CollectionItem, targetSize: CGSize) async -> NSImage?

    /// Prewarms or caches a thumbnail for fast presentation.
    func prewarmThumbnail(for item: CollectionItem) async
}
