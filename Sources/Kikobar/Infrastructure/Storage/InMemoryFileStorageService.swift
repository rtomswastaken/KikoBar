import Foundation

/// In-memory/mock implementation of FileStorageServiceProtocol for rapid development and testing.
public final class InMemoryFileStorageService: FileStorageServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var inMemoryFiles: [String: Data] = [:]

    public var baseStorageDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("KikobarTestStorage")
    }

    public init() {}

    public func importData(_ data: Data, filename: String, categoryID: UUID) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let path = baseStorageDirectory.appendingPathComponent(categoryID.uuidString).appendingPathComponent(filename).path
        inMemoryFiles[path] = data
        return URL(fileURLWithPath: path)
    }

    public func importFile(from sourceURL: URL, categoryID: UUID) throws -> URL {
        let data = (try? Data(contentsOf: sourceURL)) ?? Data()
        return try importData(data, filename: sourceURL.lastPathComponent, categoryID: categoryID)
    }

    public func saveSnippet(_ text: String, title: String, categoryID: UUID) throws -> URL {
        let data = Data(text.utf8)
        let filename = "\(title).txt"
        return try importData(data, filename: filename, categoryID: categoryID)
    }

    public func createSecurityScopedBookmark(for url: URL) throws -> Data {
        return url.absoluteString.data(using: .utf8) ?? Data()
    }

    public func resolveSecurityScopedBookmark(data: Data) throws -> (url: URL, isStale: Bool) {
        if let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
            return (url, false)
        }
        return (URL(fileURLWithPath: "/"), true)
    }

    public func verifySourceAvailability(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path) || inMemoryFiles[path] != nil
    }

    public func deleteStoredItem(at path: String) throws {
        lock.lock()
        defer { lock.unlock() }
        inMemoryFiles.removeValue(forKey: path)
    }
}
