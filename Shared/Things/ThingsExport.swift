import Foundation

public struct ThingsRendered {
    var files: [String: String]
    var containers: [String: String]
}

public enum ThingsExport {
    static let marker = "<!-- generated-by: happatools-things3; do not edit -->\n"
    static let manifestPath = ".happatools-things3.json"
    private static let lists = ["Inbox", "Today", "Anytime", "Someday", "Upcoming", "已完成", "已取消"]

    public static func render(_ snapshot: ThingsSnapshot, now: Date = Date()) throws -> ThingsRendered {
        var files = Dictionary(uniqueKeysWithValues: lists.map { ($0 + ".md", marker + "# " + $0 + "\n\n") })
        var containers: [String: String] = [:]
        let projects = snapshot.tasks.filter { $0["type"] == "1" }
        let entities = Dictionary(uniqueKeysWithValues: (snapshot.tasks + snapshot.areas).map { ($0["uuid"]!, $0) })
        let tags = Dictionary(grouping: snapshot.tags, by: { $0["owner"]! })
        let checklist = Dictionary(grouping: snapshot.checklist, by: { $0["task"]! })
        for entity in projects + snapshot.areas {
            let id = entity["uuid"]!
            let prefix = entity["type"] == "1" ? "Projects" : "Areas"
            let directory = prefix + "/" + filename(entity["title"] ?? "") + "-" + id
            containers[id] = directory
            for name in ["tasks", "已完成", "已取消"] {
                files[directory + "/" + name + ".md"] = marker + "# " + line(entity["title"] ?? "") + "\n\n"
            }
            files[directory + "/tasks.md"]! += block(entity, entities: entities, tags: tags, checklist: checklist)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        let tasks = snapshot.tasks.filter { $0["type"] == "0" }
        for task in tasks {
            let directory = (task["project"].flatMap { containers[$0] } ?? task["area"].flatMap { containers[$0] })
            let name: String
            switch task["status"] {
            case "3": name = "已完成"
            case "2": name = "已取消"
            default:
                name = directory == nil ? (["0": "Inbox", "1": "Anytime", "2": "Someday"][task["start"] ?? ""] ?? "Inbox") : "tasks"
            }
            let path = directory.map { $0 + "/" + name + ".md" } ?? name + ".md"
            files[path, default: marker + "# " + name + "\n\n"] += block(task, entities: entities, tags: tags, checklist: checklist)
        }
        let byToday = tasks.sorted {
            let left = Int($0["todayIndex"] ?? "0") ?? 0
            let right = Int($1["todayIndex"] ?? "0") ?? 0
            return left == right ? $0["uuid"]! < $1["uuid"]! : left < right
        }
        for task in byToday where task["status"] == "0" {
            let start = task["start_date"]
            let due = task["deadline"]
            if (task["start"] == "1" && start != nil)
                || (task["start"] == "2" && start != nil && start! <= today)
                || (start == nil && due != nil && due! <= today && (task["deadlineSuppressionDate"] == nil || task["deadlineSuppressionDate"] == "0")) {
                files["Today.md"]! += block(task, entities: entities, tags: tags, checklist: checklist)
            }
            if task["start"] == "2", let start, start > today {
                files["Upcoming.md"]! += block(task, entities: entities, tags: tags, checklist: checklist)
            }
        }
        return ThingsRendered(files: files, containers: containers)
    }

    private static func line(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            .reduce(into: "") { result, character in
                if "\\`*_{}[]<>#|!".contains(character) { result += "\\" }
                result.append(character)
            }
    }

    private static func filename(_ value: String) -> String {
        let invalid = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:?*<>|\"\\"))
        let clean = value.unicodeScalars.map { invalid.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        var result = ""
        for character in clean {
            if result.utf8.count + String(character).utf8.count > 120 { break }
            result.append(character)
        }
        return result.isEmpty ? "Untitled" : result
    }

    private static func block(_ row: [String: String], entities: [String: [String: String]], tags: [String: [[String: String]]], checklist: [String: [[String: String]]]) -> String {
        let id = row["uuid"]!
        let state = ["0": " ", "2": "-", "3": "x"][row["status"] ?? "0"] ?? " "
        var text = "## [\(state)] \(line(row["title"] ?? ""))\n<!-- uuid: \(id) -->\n"
        for (key, label) in [("created", "创建时间"), ("modified", "修改时间"), ("start_date", "开始日期"), ("deadline", "截止日期"), ("reminder_time", "提醒时间"), ("stopped", "完成/取消时间")] {
            if let value = row[key], !value.isEmpty { text += "- **\(label)**: \(line(value))\n" }
        }
        for (key, label) in [("project", "项目"), ("area", "领域"), ("heading", "标题分组")] {
            if let parent = row[key], let entity = entities[parent] { text += "- **\(label)**: \(line(entity["title"] ?? ""))\n" }
        }
        if let values = tags[id], !values.isEmpty {
            text += "- **标签**: " + values.map { "#" + line($0["title"] ?? "") }.joined(separator: " ") + "\n"
        }
        if let notes = row["notes"], !notes.isEmpty {
            text += "- **备注**:\n" + notes.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n").map { "  " + $0 }.joined(separator: "\n") + "\n"
        }
        if let items = checklist[id], !items.isEmpty {
            text += "- **子任务**:\n"
            for item in items {
                let status = ["0": " ", "2": "-", "3": "x"][item["status"] ?? "0"] ?? " "
                text += "  - [\(status)] \(line(item["title"] ?? "")) <!-- uuid: \(item["uuid"]!) -->\n"
                if let stopped = item["stopped"] { text += "    - 完成/取消时间: \(line(stopped))\n" }
            }
        }
        return text + "\n---\n\n"
    }
}
