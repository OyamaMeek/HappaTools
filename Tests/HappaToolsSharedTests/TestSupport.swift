import Foundation
import XCTest

enum TestSupport {
    static func temporaryDirectory(_ name: String = UUID().uuidString) throws -> URL {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/test-data", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name, isDirectory: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    static func git(_ arguments: [String], at directory: URL) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let error = stderr.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TestGit",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: String(decoding: error, as: UTF8.self)]
            )
        }
        return String(decoding: output, as: UTF8.self)
    }

    static func configuredRepository(remoteName: String = "origin", upstreamBranch: String = "main") throws -> (root: URL, remote: URL) {
        let directory = try temporaryDirectory()
        let root = directory.appendingPathComponent("repo", isDirectory: true)
        let remote = directory.appendingPathComponent("remote.git", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare"], at: remote)
        try git(["init", "-b", "main"], at: root)
        try git(["config", "user.name", "HappaTools Tests"], at: root)
        try git(["config", "user.email", "tests@example.com"], at: root)
        try Data("initial\n".utf8).write(to: root.appendingPathComponent("tracked.txt"))
        try git(["add", "-A"], at: root)
        try git(["commit", "-m", "initial"], at: root)
        try git(["remote", "add", remoteName, remote.path], at: root)
        try git(["push", "-u", remoteName, "HEAD:\(upstreamBranch)"], at: root)
        return (root, remote)
    }
}
