import Foundation

/// Defines filesystem operations for managing app-imported assets, security-scoped bookmarks, and path verification.
public protocol FileStorageServiceProtocol: AnyObject, Sendable {
    /// The base directory inside Application Support for Kikobar assets.
    var baseStorageDirectory: URL { get }

    /// Imports raw data or browser file promises into the managed container for a category.
    func importData(_ data: Data, filename: String, categoryID: UUID) throws -> URL

    /// Imports a transient file into the managed container for a category.
    func importFile(from sourceURL: URL, categoryID: UUID) throws -> URL

    /// Writes text snippet content to the managed container.
    func saveSnippet(_ text: String, title: String, categoryID: UUID) throws -> URL

    /// Creates a security-scoped bookmark for a local referenced file.
    func createSecurityScopedBookmark(for url: URL) throws -> Data

    /// Resolves a security-scoped bookmark, indicating whether the source is still present or stale.
    func resolveSecurityScopedBookmark(data: Data) throws -> (url: URL, isStale: Bool)

    /// Verifies whether a referenced or imported local path still exists on disk.
    func verifySourceAvailability(at path: String) -> Bool

    /// Deletes a managed storage file or directory.
    func deleteStoredItem(at path: String) throws
}
