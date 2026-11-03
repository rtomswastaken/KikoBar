import Foundation

/// Errors that can occur during security-scoped bookmark operations.
public enum BookmarkError: LocalizedError, Equatable {
    case unableToCreateBookmark(String)
    case unableToResolveBookmark(String)

    public var errorDescription: String? {
        switch self {
        case .unableToCreateBookmark(let msg):
            return "Failed to create security-scoped bookmark: \(msg)"
        case .unableToResolveBookmark(let msg):
            return "Failed to resolve security-scoped bookmark: \(msg)"
        }
    }
}

/// Manages creation, resolution, and security-scoped resource access for referenced files on macOS.
public final class SecurityScopedBookmarkManager: @unchecked Sendable {
    public static let shared = SecurityScopedBookmarkManager()

    public init() {}

    /// Creates persistent bookmark data for a file URL.
    /// Attempts `.withSecurityScope` first; falls back to standard bookmark options
    /// if running outside a sandboxed App environment (such as during test execution or CLI usage).
    public func createBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            do {
                return try url.bookmarkData(
                    options: .suitableForBookmarkFile,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                do {
                    return try url.bookmarkData(
                        options: [],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } catch {
                    throw BookmarkError.unableToCreateBookmark(error.localizedDescription)
                }
            }
        }
    }

    /// Resolves bookmark data back into a file URL, indicating whether the bookmark data is stale.
    /// Tries security-scoped resolution first, then falls back to non-scoped resolution.
    public func resolveBookmark(data: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (resolvedURL, isStale)
        } catch {
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (resolvedURL, isStale)
            } catch {
                throw BookmarkError.unableToResolveBookmark(error.localizedDescription)
            }
        }
    }

    /// Starts accessing a security-scoped resource URL.
    /// Returns true if access was granted or if the resource is not security-scoped.
    @discardableResult
    public func startAccessingSecurityScopedResource(for url: URL) -> Bool {
        return url.startAccessingSecurityScopedResource()
    }

    /// Stops accessing a security-scoped resource URL.
    public func stopAccessingSecurityScopedResource(for url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
