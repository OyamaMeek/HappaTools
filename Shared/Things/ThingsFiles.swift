import Foundation

extension ThingsExport {
    private struct Manifest: Codable {
        var owner = "happatools-things3"
        var version = 1
        var files: [String] = []
        var containers: [String: String] = [:]
        var archived: [String: String] = [:]
    }

    public static func reconcile(_ output: ThingsRendered, at root: URL) throws -> [String] {
        let fm = FileManager.default
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw ThingsFailure("导出目录不存在。")
        }
        try checkPath(manifestPath, root: root)
        let manifestURL = root.appendingPathComponent(manifestPath)
        var previous = Manifest()
        if fm.fileExists(atPath: manifestURL.path) {
            previous = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            guard previous.owner == "happatools-things3", previous.version == 1 else {
                throw ThingsFailure("Things3 导出清单版本或所有权不匹配。")
            }
        }
        var desired = output.files
        var containers = output.containers
        var archived = previous.archived
        for directory in Array(previous.containers.values) + Array(previous.archived.values) {
            for name in ["tasks.md", "已完成.md", "已取消.md"] {
                guard previous.files.contains(directory + "/" + name) else {
                    throw ThingsFailure("导出清单的容器与文件列表不一致，已停止。")
                }
            }
        }
        for (id, directory) in containers {
            let comparable = (directory + "/tasks.md").precomposedStringWithCanonicalMapping.lowercased()
            if let oldFile = previous.files.first(where: { $0.precomposedStringWithCanonicalMapping.lowercased() == comparable }) {
                let oldDirectory = String(oldFile.dropLast("/tasks.md".count))
                if oldDirectory != directory {
                    for name in ["tasks.md", "已完成.md", "已取消.md"] {
                        desired[oldDirectory + "/" + name] = desired.removeValue(forKey: directory + "/" + name)
                    }
                    containers[id] = oldDirectory
                    desired["README.md"] = desired["README.md"]?.replacingOccurrences(
                        of: "](" + linkPath(directory) + "/", with: "](" + linkPath(oldDirectory) + "/")
                }
            }
        }
        for path in previous.files + Array(desired.keys) {
            try validateExportPath(path)
            try checkPath(path, root: root)
            try requireOwned(path, root: root)
        }
        for (id, directory) in previous.containers where containers[id] == nil {
            let destination = archived[id] ?? "Archived/" + directory
            try validateExportPath(directory + "/tasks.md")
            archived[id] = destination
            for name in ["tasks.md", "已完成.md", "已取消.md"] {
                let source = directory + "/" + name
                let target = destination + "/" + name
                try validateExportPath(target)
                try checkPath(target, root: root)
                try requireOwned(target, root: root)
                if fm.fileExists(atPath: root.appendingPathComponent(source).path) {
                    desired[target] = try String(contentsOf: root.appendingPathComponent(source), encoding: .utf8)
                } else if fm.fileExists(atPath: root.appendingPathComponent(target).path) {
                    desired[target] = try String(contentsOf: root.appendingPathComponent(target), encoding: .utf8)
                } else if previous.files.contains(source) {
                    throw ThingsFailure("待归档文件缺失：\(source)。请从 Git 恢复后重试。")
                }
            }
        }
        let allPaths = Set(previous.files).union(desired.keys)
        guard Set(allPaths.map { $0.precomposedStringWithCanonicalMapping.lowercased() }).count == allPaths.count else {
            throw ThingsFailure("导出路径在不区分大小写的文件系统上发生冲突。")
        }
        for path in desired.keys {
            try checkPath(path, root: root)
            try requireOwned(path, root: root)
        }
        for path in desired.keys.sorted() {
            let file = root.appendingPathComponent(path)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writeIfChanged(Data(desired[path]!.utf8), to: file)
        }
        for path in previous.files where desired[path] == nil && !path.hasPrefix("Archived/") {
            let file = root.appendingPathComponent(path)
            if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
        }
        // ponytail: 保留历史路径用于提交失败后的删除重试；超大重命名历史时再压缩清单。
        let manifest = Manifest(files: allPaths.sorted(), containers: containers, archived: archived)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try writeIfChanged(encoder.encode(manifest), to: manifestURL)
        return allPaths.union([manifestPath]).sorted()
    }

    private static func validateExportPath(_ path: String) throws {
        var parts = path.components(separatedBy: "/")
        if parts.first == "Archived" { parts.removeFirst() }
        let top = ["README.md", "Inbox.md", "Today.md", "Anytime.md", "Someday.md", "Upcoming.md", "已完成.md", "已取消.md"]
        guard (parts.count == 1 && !path.hasPrefix("Archived/") && top.contains(path))
            || (parts.count == 3 && ["Projects", "Areas"].contains(parts[0])
                && !parts[1].isEmpty && ![".", "..", ".git"].contains(parts[1].lowercased())
                && !parts[1].contains("\\") && !parts[1].unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                && ["tasks.md", "已完成.md", "已取消.md"].contains(parts[2])) else {
            throw ThingsFailure("导出清单含无效路径，已停止：\(path)")
        }
    }

    private static func checkPath(_ path: String, root: URL) throws {
        var current = root
        for component in path.components(separatedBy: "/") {
            current.appendPathComponent(component)
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: current.path)
                if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                    throw ThingsFailure("导出路径含符号链接，已停止：\(path)")
                }
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
                continue
            }
        }
    }

    private static func requireOwned(_ path: String, root: URL) throws {
        let file = root.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: file.path) {
            guard try String(contentsOf: file, encoding: .utf8).hasPrefix(marker) else {
                throw ThingsFailure("保留非 HappaTools 导出文件，请选择其他仓库或移走冲突文件：\(path)")
            }
        }
    }

    private static func writeIfChanged(_ data: Data, to file: URL) throws {
        if FileManager.default.fileExists(atPath: file.path), try Data(contentsOf: file) == data { return }
        try data.write(to: file, options: .atomic)
    }
}
