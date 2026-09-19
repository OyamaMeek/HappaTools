import Foundation
import SQLite3

public enum DatabaseError: LocalizedError {
    case sqlite(code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .sqlite(code, message):
            return "SQLite 错误 \(code)：\(message)"
        }
    }
}

public final class DatabaseManager {
    private let connection: OpaquePointer
    private let lock = NSLock()
    private let iso8601 = ISO8601DateFormatter()
    private let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var database: OpaquePointer?
        let code = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard code == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开数据库"
            if let database { sqlite3_close(database) }
            throw DatabaseError.sqlite(code: code, message: message)
        }
        connection = database
        sqlite3_busy_timeout(connection, 5_000)
        do {
            try execute("PRAGMA journal_mode=WAL;")
            try migrate()
        } catch {
            sqlite3_close(connection)
            throw error
        }
    }

    deinit {
        sqlite3_close(connection)
    }

    public func insertLog(_ record: OperationRecord) throws {
        try synchronized {
            try transaction {
                let sql = """
                    INSERT INTO operation_logs
                    (timestamp, operation_type, target_path, commit_message, stdout, stderr, status, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                    """
                try withStatement(sql) { statement in
                    try bind(iso8601Fractional.string(from: record.timestamp), to: 1, in: statement)
                    try bind(record.operationType, to: 2, in: statement)
                    try bind(record.targetPath, to: 3, in: statement)
                    try bind(record.commitMessage, to: 4, in: statement)
                    try bind(record.stdout, to: 5, in: statement)
                    try bind(record.stderr, to: 6, in: statement)
                    try bind(record.status, to: 7, in: statement)
                    try check(sqlite3_bind_double(statement, 8, julianDay(record.timestamp)))
                    try stepDone(statement)
                }
            }
        }
    }

    public func records(
        search: String = "",
        operationType: String? = nil,
        status: String? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) throws -> [OperationRecord] {
        try synchronized {
            var conditions: [String] = []
            var values: [SQLValue] = []
            if !search.isEmpty {
                conditions.append("""
                    (operation_type LIKE ? ESCAPE '\\' OR target_path LIKE ? ESCAPE '\\' OR
                     commit_message LIKE ? ESCAPE '\\' OR stdout LIKE ? ESCAPE '\\' OR
                     stderr LIKE ? ESCAPE '\\' OR status LIKE ? ESCAPE '\\')
                    """)
                let pattern = "%\(escapeLike(search))%"
                values.append(contentsOf: Array(repeating: .text(pattern), count: 6))
            }
            if let operationType {
                conditions.append("operation_type = ?")
                values.append(.text(operationType))
            }
            if let status {
                conditions.append("status = ?")
                values.append(.text(status))
            }
            if let since {
                conditions.append("created_at >= ?")
                values.append(.double(julianDay(since)))
            }
            let whereClause = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
            let sql = """
                SELECT id, timestamp, operation_type, target_path, commit_message, stdout, stderr, status
                FROM operation_logs\(whereClause)
                ORDER BY created_at DESC, id DESC LIMIT ?;
                """
            values.append(.integer(Int64(max(0, limit))))
            return try withStatement(sql) { statement in
                for (offset, value) in values.enumerated() {
                    try bind(value, to: Int32(offset + 1), in: statement)
                }
                var result: [OperationRecord] = []
                while true {
                    let code = sqlite3_step(statement)
                    if code == SQLITE_DONE { return result }
                    try check(code)
                    let timestampText = text(statement, column: 1) ?? ""
                    guard let timestamp = iso8601Fractional.date(from: timestampText)
                        ?? iso8601.date(from: timestampText) else {
                        throw DatabaseError.sqlite(code: SQLITE_MISMATCH, message: "无效时间戳")
                    }
                    result.append(OperationRecord(
                        id: sqlite3_column_int64(statement, 0),
                        timestamp: timestamp,
                        operationType: text(statement, column: 2) ?? "",
                        targetPath: text(statement, column: 3) ?? "",
                        commitMessage: text(statement, column: 4),
                        stdout: text(statement, column: 5) ?? "",
                        stderr: text(statement, column: 6) ?? "",
                        status: text(statement, column: 7) ?? ""
                    ))
                }
            }
        }
    }

    public func cleanupOldLogs(olderThan date: Date) throws {
        try mutate("DELETE FROM operation_logs WHERE created_at < ?;", value: .double(julianDay(date)))
    }

    public func clearAllLogs() throws {
        try mutate("DELETE FROM operation_logs;", value: nil)
    }

    private func migrate() throws {
        try transaction {
            try execute(Schema.createOperationLogs)
            try execute(Schema.createTimestampIndex)
            try execute(Schema.createCreatedAtIndex)
            try execute("PRAGMA user_version=1;")
        }
    }

    private func mutate(_ sql: String, value: SQLValue?) throws {
        try synchronized {
            try transaction {
                try withStatement(sql) { statement in
                    if let value { try bind(value, to: 1, in: statement) }
                    try stepDone(statement)
                }
            }
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do {
            try body()
            try execute("COMMIT;")
        } catch let operationError {
            do {
                try execute("ROLLBACK;")
            } catch let rollbackError {
                throw rollbackError
            }
            throw operationError
        }
    }

    private func synchronized<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(connection, sql, nil, nil, &message)
        guard code == SQLITE_OK else {
            let detail = message.map { String(cString: $0) }
                ?? String(cString: sqlite3_errmsg(connection))
            sqlite3_free(message)
            throw DatabaseError.sqlite(code: code, message: detail)
        }
    }

    private func withStatement<T>(_ sql: String, body: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(connection, sql, -1, &statement, nil))
        guard let statement else {
            throw DatabaseError.sqlite(code: SQLITE_ERROR, message: "无法创建 SQL 语句")
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else { try check(code); return }
    }

    private func check(_ code: Int32) throws {
        guard code == SQLITE_OK || code == SQLITE_ROW else {
            throw DatabaseError.sqlite(code: code, message: String(cString: sqlite3_errmsg(connection)))
        }
    }

    private func bind(_ value: String?, to index: Int32, in statement: OpaquePointer) throws {
        guard let value else {
            try check(sqlite3_bind_null(statement, index))
            return
        }
        let code = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        try check(code)
    }

    private func bind(_ value: SQLValue, to index: Int32, in statement: OpaquePointer) throws {
        switch value {
        case let .text(value): try bind(value, to: index, in: statement)
        case let .double(value): try check(sqlite3_bind_double(statement, index, value))
        case let .integer(value): try check(sqlite3_bind_int64(statement, index, value))
        }
    }

    private func text(_ statement: OpaquePointer, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    private func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private func escapeLike(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    private enum SQLValue {
        case text(String)
        case double(Double)
        case integer(Int64)
    }
}
