import AppKit
import Foundation
import QuickLookThumbnailing

/// Asynchronously generates thumbnails using QuickLookThumbnailing with in-memory caching.
public final class QuickLookThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    private let cache = NSCache<NSURL, NSImage>()

    public init() {
        cache.countLimit = 300
    }

    public func generateThumbnail(for url: URL, targetSize: CGSize = CGSize(width: 80, height: 80)) async -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: targetSize,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let nsImage = thumbnail.nsImage
            cache.setObject(nsImage, forKey: key)
            return nsImage
        } catch {
            // Fallback to system icon for the file type
            let fallbackImage = NSWorkspace.shared.icon(forFile: url.path)
            fallbackImage.size = targetSize
            return fallbackImage
        }
    }

    public func generateThumbnail(for item: CollectionItem, targetSize: CGSize = CGSize(width: 80, height: 80)) async -> NSImage? {
        if let localPath = item.localPath {
            let url = URL(fileURLWithPath: localPath)
            return await generateThumbnail(for: url, targetSize: targetSize)
        } else if let sourceURL = item.sourceURL, sourceURL.isFileURL {
            return await generateThumbnail(for: sourceURL, targetSize: targetSize)
        }
        return nil
    }

    public func prewarmThumbnail(for item: CollectionItem) async {
        _ = await generateThumbnail(for: item)
    }
}
