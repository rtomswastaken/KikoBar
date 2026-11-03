import Foundation

/// Production filesystem storage service managing imported assets, snippets,
/// security-scoped bookmarks, and source availability verification.
public final class LocalFileStorageService: FileStorageServiceProtocol, @unchecked Sendable {
    public let baseStorageDirectory: URL
    private let bookmarkManager: SecurityScopedBookmarkManager
    private let fileManager = FileManager.default
    private let lock = NSLock()

    /// Initializes storage with default `~/Library/Application Support/Kikobar/Storage`
    /// or a custom directory (e.g. for testing).
    public init(
        baseStorageDirectory: URL? = nil,
        bookmarkManager: SecurityScopedBookmarkManager = .shared
    ) {
        if let baseDir = baseStorageDirectory {
            self.baseStorageDirectory = baseDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseStorageDirectory = appSupport.appendingPathComponent("Kikobar/Storage", isDirectory: true)
        }
        self.bookmarkManager = bookmarkManager

        try? fileManager.createDirectory(at: self.baseStorageDirectory, withIntermediateDirectories: true)
    }

    /// Imports raw data into the managed container for a category.
    public func importData(_ data: Data, filename: String, categoryID: UUID) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let categoryDir = baseStorageDirectory.appendingPathComponent(categoryID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: categoryDir.path) {
            try fileManager.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }

        let destinationURL = categoryDir.appendingPathComponent(filename)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    /// Copies a local file into the managed container for a category.
    public func importFile(from sourceURL: URL, categoryID: UUID) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let categoryDir = baseStorageDirectory.appendingPathComponent(categoryID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: categoryDir.path) {
            try fileManager.createDirectory(at: categoryDir, withIntermediateDirectories: true)
        }

        let destinationURL = categoryDir.appendingPathComponent(sourceURL.lastPathComponent)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    /// Writes a text snippet file into the managed container.
    public func saveSnippet(_ text: String, title: String, categoryID: UUID) throws -> URL {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = cleanTitle.isEmpty ? "Snippet" : cleanTitle
        let filename = safeTitle.hasSuffix(".txt") ? safeTitle : "\(safeTitle).txt"
        let data = Data(text.utf8)
        return try importData(data, filename: filename, categoryID: categoryID)
    }

    /// Creates a security-scoped bookmark for a referenced local file.
    public func createSecurityScopedBookmark(for url: URL) throws -> Data {
        return try bookmarkManager.createBookmark(for: url)
    }

    /// Resolves a security-scoped bookmark to verify access and staleness.
    public func resolveSecurityScopedBookmark(data: Data) throws -> (url: URL, isStale: Bool) {
        return try bookmarkManager.resolveBookmark(data: data)
    }

    /// Verifies whether a referenced or imported local path still exists on disk.
    public func verifySourceAvailability(at path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let standardizedPath: String
        if path.hasPrefix("file://"), let url = URL(string: path) {
            standardizedPath = url.path
        } else {
            standardizedPath = path
        }
        return fileManager.fileExists(atPath: standardizedPath)
    }

    /// Deletes a managed storage file.
    public func deleteStoredItem(at path: String) throws {
        guard !path.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        let standardizedPath: String
        if path.hasPrefix("file://"), let url = URL(string: path) {
            standardizedPath = url.path
        } else {
            standardizedPath = path
        }

        if fileManager.fileExists(atPath: standardizedPath) {
            try fileManager.removeItem(atPath: standardizedPath)
        }
    }

    /// Deletes the entire managed storage directory for a specific category.
    public func deleteCategoryStorage(categoryID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        let categoryDir = baseStorageDirectory.appendingPathComponent(categoryID.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: categoryDir.path) {
            try fileManager.removeItem(at: categoryDir)
        }
    }
}
