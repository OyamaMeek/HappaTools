import Foundation
import SQLite3

public struct ThingsFailure: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct ThingsSnapshot {
    let tasks: [[String: String]]
    let areas: [[String: String]]
    let tags: [[String: String]]
    let checklist: [[String: String]]
    public var taskCount: Int { tasks.filter { $0["type"] == "0" }.count }
}

public enum ThingsReader {
    public static func discover(home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let root = home.appendingPathComponent("Library/Group Containers/JLMPQHK86H.com.culturedcode.ThingsMac")
        let directories = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        var candidates = directories.filter { $0.lastPathComponent.hasPrefix("ThingsData-") }
            .map { $0.appendingPathComponent("Things Database.thingsdatabase/main.sqlite") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        if candidates.isEmpty {
            let legacy = root.appendingPathComponent("Things Database.thingsdatabase/main.sqlite")
            if FileManager.default.fileExists(atPath: legacy.path) { candidates.append(legacy) }
        }
        guard candidates.count == 1, let path = candidates.first else {
            throw ThingsFailure(candidates.isEmpty ? "未找到 Things3 数据库，请选择 main.sqlite。" : "找到多个 Things3 数据库，请手动选择正在使用的 main.sqlite。")
        }
        return path
    }

    public static func read(at url: URL) throws -> ThingsSnapshot {
        var pointer: OpaquePointer?
        let code = sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY, nil)
        guard code == SQLITE_OK, let db = pointer else {
            let detail = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开文件"
            if let pointer { sqlite3_close(pointer) }
            throw ThingsFailure("无法只读访问 Things3 数据库：\(detail)。请检查文件和隐私权限。")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)
        func query(_ sql: String) throws -> [[String: String]] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw ThingsFailure("Things3 数据结构不兼容或读取失败：\(String(cString: sqlite3_errmsg(db)))")
            }
            defer { sqlite3_finalize(statement) }
            var rows: [[String: String]] = []
            var status = sqlite3_step(statement)
            while status == SQLITE_ROW {
                var row: [String: String] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    if let value = sqlite3_column_text(statement, index) {
                        row[String(cString: sqlite3_column_name(statement, index))] = String(cString: value)
                    }
                }
                rows.append(row)
                status = sqlite3_step(statement)
            }
            guard status == SQLITE_DONE else {
                throw ThingsFailure("Things3 读取失败：\(String(cString: sqlite3_errmsg(db)))")
            }
            return rows
        }
        _ = try query("BEGIN")
        let tasks = try query("""
            SELECT T.uuid, T.title, T.type, T.status, T.start, T.notes, T."index", T.todayIndex,
                   T.deadlineSuppressionDate,
                   COALESCE(T.project, H.project) AS project, T.heading,
                   COALESCE(T.area, P.area, HP.area) AS area,
                   \(dateSQL("T.startDate")) AS start_date,
                   \(dateSQL("T.deadline")) AS deadline,
                   CASE WHEN T.reminderTime IS NOT NULL THEN
                     printf('%02d:%02d', (T.reminderTime & 2080374784) >> 26, (T.reminderTime & 66060288) >> 20)
                   END AS reminder_time,
                   datetime(T.creationDate, 'unixepoch', 'localtime') AS created,
                   datetime(T.userModificationDate, 'unixepoch', 'localtime') AS modified,
                   datetime(T.stopDate, 'unixepoch', 'localtime') AS stopped
            FROM TMTask T
            LEFT JOIN TMTask H ON H.uuid = T.heading
            LEFT JOIN TMTask P ON P.uuid = T.project
            LEFT JOIN TMTask HP ON HP.uuid = H.project
            WHERE T.trashed = 0 AND T.rt1_recurrenceRule IS NULL
              AND COALESCE(P.trashed, 0) = 0 AND COALESCE(H.trashed, 0) = 0 AND COALESCE(HP.trashed, 0) = 0
            ORDER BY T."index", T.uuid
            """)
        let areas = try query("SELECT uuid, title FROM TMArea ORDER BY \"index\", uuid")
        let tags = try query("""
            SELECT L.tasks AS owner, G.title FROM TMTaskTag L JOIN TMTag G ON G.uuid=L.tags
            UNION SELECT L.areas AS owner, G.title FROM TMAreaTag L JOIN TMTag G ON G.uuid=L.tags
            ORDER BY owner, title
            """)
        let checklist = try query("""
            SELECT uuid, task, title, status, datetime(stopDate, 'unixepoch', 'localtime') AS stopped
            FROM TMChecklistItem ORDER BY "index", uuid
            """)
        _ = try query("COMMIT")
        for row in tasks + areas + checklist {
            guard let id = row["uuid"], !id.isEmpty,
                  id.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }) else {
                throw ThingsFailure("Things3 中存在无效 UUID，已停止导出。")
            }
            if let status = row["status"], !["0", "2", "3"].contains(status) {
                throw ThingsFailure("Things3 中存在不支持的任务状态，已停止导出。")
            }
            if let type = row["type"], !["0", "1", "2"].contains(type) {
                throw ThingsFailure("Things3 中存在不支持的任务类型，已停止导出。")
            }
        }
        return ThingsSnapshot(tasks: tasks, areas: areas, tags: tags, checklist: checklist)
    }

    private static func dateSQL(_ column: String) -> String {
        "CASE WHEN \(column) > 0 THEN printf('%04d-%02d-%02d', (\(column) & 134152192) >> 16, (\(column) & 61440) >> 12, (\(column) & 3968) >> 7) END"
    }
}
