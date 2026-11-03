import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Errors encountered during SQLite database operations.
public enum SQLiteError: LocalizedError, Equatable {
    case connectionFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case executionFailed(String)
    case databaseClosed
    case notFound

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):
            return "SQLite connection failed: \(msg)"
        case .prepareFailed(let msg):
            return "SQLite prepare statement failed: \(msg)"
        case .stepFailed(let msg):
            return "SQLite step failed: \(msg)"
        case .bindFailed(let msg):
            return "SQLite bind parameter failed: \(msg)"
        case .executionFailed(let msg):
            return "SQLite execution failed: \(msg)"
        case .databaseClosed:
            return "SQLite database is closed"
        case .notFound:
            return "Requested record was not found"
        }
    }
}

/// Lightweight wrapper around a prepared SQLite statement providing type-safe binding and column extraction.
public struct SQLiteStatement {
    public let handle: OpaquePointer

    public init(handle: OpaquePointer) {
        self.handle = handle
    }

    // MARK: - Binding

    public func bind(index: Int32, _ value: String?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = sqlite3_bind_text(handle, index, value, -1, SQLITE_TRANSIENT)
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind String at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: Int?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = sqlite3_bind_int64(handle, index, Int64(value))
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind Int at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: Int64?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = sqlite3_bind_int64(handle, index, value)
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind Int64 at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: Double?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = sqlite3_bind_double(handle, index, value)
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind Double at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: Bool?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = sqlite3_bind_int(handle, index, value ? 1 : 0)
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind Bool at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: Data?) throws {
        guard let value = value else {
            sqlite3_bind_null(handle, index)
            return
        }
        let rc = value.withUnsafeBytes { rawBuffer in
            sqlite3_bind_blob(handle, index, rawBuffer.baseAddress, Int32(rawBuffer.count), SQLITE_TRANSIENT)
        }
        if rc != SQLITE_OK {
            throw SQLiteError.bindFailed("Failed to bind Data at index \(index): \(rc)")
        }
    }

    public func bind(index: Int32, _ value: UUID?) throws {
        try bind(index: index, value?.uuidString)
    }

    public func bind(index: Int32, _ value: Date?) throws {
        try bind(index: index, value?.timeIntervalSince1970)
    }

    // MARK: - Column Extraction

    public func columnString(index: Int32) -> String? {
        guard sqlite3_column_type(handle, index) != SQLITE_NULL else { return nil }
        guard let cStr = sqlite3_column_text(handle, index) else { return nil }
        return String(cString: cStr)
    }

    public func columnInt(index: Int32) -> Int {
        return Int(sqlite3_column_int64(handle, index))
    }

    public func columnInt64(index: Int32) -> Int64? {
        guard sqlite3_column_type(handle, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(handle, index)
    }

    public func columnDouble(index: Int32) -> Double {
        return sqlite3_column_double(handle, index)
    }

    public func columnBool(index: Int32) -> Bool {
        return sqlite3_column_int(handle, index) != 0
    }

    public func columnData(index: Int32) -> Data? {
        guard sqlite3_column_type(handle, index) != SQLITE_NULL else { return nil }
        guard let bytes = sqlite3_column_blob(handle, index) else { return nil }
        let count = Int(sqlite3_column_bytes(handle, index))
        return Data(bytes: bytes, count: count)
    }

    public func columnUUID(index: Int32) -> UUID? {
        guard let str = columnString(index: index) else { return nil }
        return UUID(uuidString: str)
    }

    public func columnDate(index: Int32) -> Date {
        let timeInterval = columnDouble(index: index)
        return Date(timeIntervalSince1970: timeInterval)
    }
}

/// Thread-safe SQLite database manager using a serial dispatch queue, WAL journal mode, and foreign keys.
public final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    public let databaseURL: URL?
    private let queue = DispatchQueue(label: "com.kikobar.database.queue", qos: .userInitiated)
    private static let queueSpecificKey = DispatchSpecificKey<Void>()

    public static var defaultDatabaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Kikobar/Database/kikobar.sqlite")
    }

    public init(databaseURL: URL? = nil, inMemory: Bool = false) throws {
        queue.setSpecific(key: Self.queueSpecificKey, value: ())

        if inMemory {
            self.databaseURL = nil
            var handle: OpaquePointer?
            let rc = sqlite3_open_v2(":memory:", &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            guard rc == SQLITE_OK, let handle = handle else {
                let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open in-memory database"
                if let handle = handle { sqlite3_close_v2(handle) }
                throw SQLiteError.connectionFailed(msg)
            }
            self.db = handle
        } else {
            let targetURL = databaseURL ?? Self.defaultDatabaseURL
            self.databaseURL = targetURL
            let dir = targetURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            var handle: OpaquePointer?
            let rc = sqlite3_open_v2(targetURL.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
            guard rc == SQLITE_OK, let handle = handle else {
                let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database at \(targetURL.path)"
                if let handle = handle { sqlite3_close_v2(handle) }
                throw SQLiteError.connectionFailed(msg)
            }
            self.db = handle
        }

        try configurePragmas()
        try createTables()
    }

    deinit {
        if let handle = db {
            sqlite3_close_v2(handle)
        }
    }

    private var lastErrorMessage: String {
        guard let handle = db else { return "Database handle is nil" }
        return String(cString: sqlite3_errmsg(handle))
    }

    private func perform<T>(_ block: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: Self.queueSpecificKey) != nil {
            return try block()
        } else {
            return try queue.sync {
                try block()
            }
        }
    }

    private func configurePragmas() throws {
        try executeRaw("PRAGMA foreign_keys = ON;")
        try executeRaw("PRAGMA journal_mode = WAL;")
        try executeRaw("PRAGMA busy_timeout = 5000;")
    }

    private func createTables() throws {
        let schema = """
        CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            hex_color TEXT NOT NULL,
            is_expanded INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category_id TEXT NOT NULL,
            content_type TEXT NOT NULL,
            storage_type TEXT NOT NULL,
            source_url TEXT,
            local_path TEXT,
            bookmark_data BLOB,
            text_content TEXT,
            thumbnail_path TEXT,
            file_size INTEGER,
            uti TEXT,
            date_added REAL NOT NULL,
            is_source_available INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_items_category ON items(category_id);
        CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON categories(sort_order);
        """
        try executeRaw(schema)
    }

    // MARK: - Synchronous Execution Helpers (Queue Serialized & Re-entrant Safe)

    /// Executes raw multi-statement SQL strings (e.g. for PRAGMAs or schema creation).
    public func executeRaw(_ sql: String) throws {
        try perform {
            guard let handle = db else { throw SQLiteError.databaseClosed }
            var errorMsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(handle, sql, nil, nil, &errorMsg)
            if rc != SQLITE_OK {
                let msg = errorMsg.map { String(cString: $0) } ?? lastErrorMessage
                sqlite3_free(errorMsg)
                throw SQLiteError.executionFailed(msg)
            }
        }
    }

    /// Executes a single prepared SQL statement with parameter binding.
    public func execute(
        _ sql: String,
        binder: ((SQLiteStatement) throws -> Void)? = nil
    ) throws {
        try perform {
            guard let handle = db else { throw SQLiteError.databaseClosed }
            var stmt: OpaquePointer?
            let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
            guard rc == SQLITE_OK, let stmt = stmt else {
                throw SQLiteError.prepareFailed(lastErrorMessage)
            }
            defer { sqlite3_finalize(stmt) }

            let statement = SQLiteStatement(handle: stmt)
            try binder?(statement)

            let stepRc = sqlite3_step(stmt)
            if stepRc != SQLITE_DONE && stepRc != SQLITE_ROW {
                throw SQLiteError.stepFailed(lastErrorMessage)
            }
        }
    }

    /// Queries records using a prepared SQL statement, mapping each row using `mapper`.
    public func query<T>(
        _ sql: String,
        binder: ((SQLiteStatement) throws -> Void)? = nil,
        mapper: (SQLiteStatement) throws -> T
    ) throws -> [T] {
        try perform {
            guard let handle = db else { throw SQLiteError.databaseClosed }
            var stmt: OpaquePointer?
            let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
            guard rc == SQLITE_OK, let stmt = stmt else {
                throw SQLiteError.prepareFailed(lastErrorMessage)
            }
            defer { sqlite3_finalize(stmt) }

            let statement = SQLiteStatement(handle: stmt)
            try binder?(statement)

            var results: [T] = []
            while true {
                let stepRc = sqlite3_step(stmt)
                if stepRc == SQLITE_ROW {
                    let item = try mapper(statement)
                    results.append(item)
                } else if stepRc == SQLITE_DONE {
                    break
                } else {
                    throw SQLiteError.stepFailed(lastErrorMessage)
                }
            }
            return results
        }
    }

    /// Runs a block enclosed within an IMMEDIATE transaction serialized on the database queue.
    /// Rolls back if an error is thrown, commits otherwise.
    public func transaction<T>(_ block: () throws -> T) throws -> T {
        try perform {
            guard let handle = db else { throw SQLiteError.databaseClosed }

            var errorMsg: UnsafeMutablePointer<CChar>?
            let beginRc = sqlite3_exec(handle, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, &errorMsg)
            if beginRc != SQLITE_OK {
                let msg = errorMsg.map { String(cString: $0) } ?? lastErrorMessage
                sqlite3_free(errorMsg)
                throw SQLiteError.executionFailed(msg)
            }

            do {
                let result = try block()
                let commitRc = sqlite3_exec(handle, "COMMIT TRANSACTION;", nil, nil, &errorMsg)
                if commitRc != SQLITE_OK {
                    let msg = errorMsg.map { String(cString: $0) } ?? lastErrorMessage
                    sqlite3_free(errorMsg)
                    throw SQLiteError.executionFailed(msg)
                }
                return result
            } catch {
                sqlite3_exec(handle, "ROLLBACK TRANSACTION;", nil, nil, nil)
                throw error
            }
        }
    }
}
