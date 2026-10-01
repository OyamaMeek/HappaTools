import Foundation
import SQLite3
import XCTest
@testable import HappaToolsShared

final class ThingsTests: XCTestCase {
    static var fixture: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/Things/main.sqlite")
    }

    func copyDatabase(to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("things.sqlite")
        try FileManager.default.copyItem(at: Self.fixture, to: url)
        return url
    }

    func sql(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "TestSQLite", code: 1)
        }
        defer { sqlite3_close(db) }
        let code = sqlite3_exec(db, sql, nil, nil, nil)
        guard code == SQLITE_OK else {
            throw NSError(domain: "TestSQLite", code: Int(code), userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
        }
    }

    func testReadAndExportActualThingsSample() throws {
        let original = try Data(contentsOf: Self.fixture)
        let snapshot = try ThingsReader.read(at: Self.fixture)
        let output = try ThingsExport.render(snapshot)
        XCTAssertTrue(output.files["Inbox.md"]!.contains("To-Do in Inbox"))
        XCTAssertTrue(output.files["已完成.md"]!.contains("Completed To-Do in Inbox"))
        XCTAssertTrue(output.files["已取消.md"]!.contains("Cancelled To-Do in Inbox"))
        let text = output.files.values.joined(separator: "\n")
        let first = try XCTUnwrap(text.range(of: "Item 1"))
        let second = try XCTUnwrap(text.range(of: "Item 2"))
        let third = try XCTUnwrap(text.range(of: "Item 3"))
        XCTAssertLessThan(first.lowerBound, second.lowerBound)
        XCTAssertLessThan(second.lowerBound, third.lowerBound)
        XCTAssertEqual(original, try Data(contentsOf: Self.fixture))
        XCTAssertEqual(output.files, try ThingsExport.render(ThingsReader.read(at: Self.fixture)).files)
    }

    func testReadmeSummarizesTasksAndLinksToExportedFiles() throws {
        let root = try TestSupport.temporaryDirectory()
        let snapshot = try ThingsReader.read(at: Self.fixture)
        let output = try ThingsExport.render(snapshot)
        let readme = try XCTUnwrap(output.files["README.md"])
        XCTAssertTrue(readme.contains("未完成 **15**"))
        XCTAssertTrue(readme.contains("已完成 **12**"))
        XCTAssertTrue(readme.contains("已取消 **10**"))
        let sections = readme.components(separatedBy: "## 最近完成")
        XCTAssertEqual(sections.count, 2)
        let pending = sections[0]
        XCTAssertEqual(pending.components(separatedBy: "- [ ] ").count - 1, 15)
        for task in snapshot.tasks where task["type"] == "0" && task["status"] == "0" {
            XCTAssertEqual(pending.components(separatedBy: "[\(task["title"]!)](").count - 1, 1)
        }
        XCTAssertFalse(pending.contains("Completed To-Do"))
        XCTAssertFalse(pending.contains("Cancelled To-Do"))
        XCTAssertTrue(pending.contains("Project without Area"))
        XCTAssertTrue(pending.contains("Area 1"))
        XCTAssertEqual(sections[1].components(separatedBy: "- [x] ").count - 1, 12)
        XCTAssertFalse(sections[1].contains("\n## "))
        let paths = try ThingsExport.reconcile(output, at: root)
        XCTAssertTrue(paths.contains("README.md"))
        let pattern = try NSRegularExpression(pattern: #"\]\(([^)]+)\)"#)
        for match in pattern.matches(in: readme, range: NSRange(readme.startIndex..., in: readme)) {
            let range = try XCTUnwrap(Range(match.range(at: 1), in: readme))
            let path = try XCTUnwrap(String(readme[range]).removingPercentEncoding)
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
        }
    }

    func testReadmeRecentCompletionLimitEscapingAndEmptyState() throws {
        let root = try TestSupport.temporaryDirectory()
        let db = try copyDatabase(to: root)
        try sql("UPDATE TMTask SET status=3,stopDate=rowid WHERE type=0; UPDATE TMTask SET stopDate=1700000000 WHERE uuid='LgqUAQAdNsS3CGHok4EjLa'; UPDATE TMTask SET stopDate=1700000001 WHERE uuid='56dtXSk3A373M6n4eqGyr3'; UPDATE TMTask SET stopDate=NULL WHERE uuid='LE2WEGxANmtHWD3c9g5iWA'; UPDATE TMTask SET status=0,title='待办 [特殊] #标题' WHERE uuid='DfYoiXcNLQssk9DkSoJV3Y'; UPDATE TMTask SET title='项目 (中文)' WHERE uuid='TCozQqXVbB2TJkXXXQj2H9'", at: db)
        let output = try ThingsExport.render(ThingsReader.read(at: db))
        let readme = try XCTUnwrap(output.files["README.md"])
        XCTAssertTrue(readme.contains(##"待办 \[特殊\] \#标题"##))
        let recent = try XCTUnwrap(readme.components(separatedBy: "## 最近完成").last)
        XCTAssertEqual(recent.components(separatedBy: "- [x] ").count - 1, 20)
        let newest = try XCTUnwrap(recent.range(of: "Completed To-Do in Today"))
        let older = try XCTUnwrap(recent.range(of: "Completed To-Do in Inbox"))
        XCTAssertLessThan(newest.lowerBound, older.lowerBound)
        XCTAssertFalse(recent.contains("Completed To-Do in Upcoming"))
        XCTAssertTrue(readme.contains("%20%28"))
        try sql("UPDATE TMTask SET trashed=1", at: db)
        let empty = try XCTUnwrap(ThingsExport.render(ThingsReader.read(at: db)).files["README.md"])
        XCTAssertTrue(empty.contains("暂无未完成任务"))
        XCTAssertTrue(empty.contains("暂无已完成任务"))
    }

    func testEmptyRepositoryFirstUploadPreservesUserStaging() throws {
        let base = try TestSupport.temporaryDirectory()
        let root = base.appendingPathComponent("repo")
        let remote = base.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try TestSupport.git(["init", "--bare", remote.path], at: base)
        try TestSupport.git(["init", "-b", "main"], at: root)
        try TestSupport.git(["config", "user.name", "Tests"], at: root)
        try TestSupport.git(["config", "user.email", "tests@example.com"], at: root)
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/usr/bin/git"))
        XCTAssertThrowsError(try ThingsSyncTarget.capture(at: root, executor: executor))
        try TestSupport.git(["remote", "add", "origin", remote.path], at: root)
        try TestSupport.git(["remote", "add", "other", remote.path], at: root)
        XCTAssertThrowsError(try ThingsSyncTarget.capture(at: root, executor: executor))
        try TestSupport.git(["remote", "remove", "other"], at: root)
        let target = try ThingsSyncTarget.capture(at: root, executor: executor)
        XCTAssertThrowsError(try TestSupport.git(["rev-parse", "--verify", "HEAD"], at: root))
        XCTAssertThrowsError(try TestSupport.git(["config", "--get", "branch.main.remote"], at: root))
        try Data("keep staged".utf8).write(to: root.appendingPathComponent("personal.txt"))
        try TestSupport.git(["add", "personal.txt"], at: root)
        let sync = ThingsSync(executor: executor)
        let offline = base.appendingPathComponent("offline.git")
        try FileManager.default.moveItem(at: remote, to: offline)
        XCTAssertThrowsError(try sync.run(database: Self.fixture, target: target))
        let pendingHead = try TestSupport.git(["rev-parse", "HEAD"], at: root)
        XCTAssertThrowsError(try TestSupport.git(["config", "--get", "branch.main.remote"], at: root))
        try FileManager.default.moveItem(at: offline, to: remote)
        let first = try sync.run(database: Self.fixture, target: target)
        XCTAssertFalse(first.committed)
        XCTAssertTrue(first.pushed)
        XCTAssertEqual(try TestSupport.git(["rev-parse", "HEAD"], at: root), pendingHead)
        XCTAssertEqual(try TestSupport.git(["diff", "--cached", "--name-only"], at: root), "personal.txt\n")
        XCTAssertFalse(try TestSupport.git(["ls-tree", "-r", "--name-only", "HEAD"], at: root).contains("personal.txt"))
        XCTAssertEqual(try TestSupport.git(["rev-parse", "HEAD"], at: root), try TestSupport.git(["rev-parse", "@{upstream}"], at: root))
        XCTAssertEqual(try ThingsSyncTarget.capture(at: root, executor: executor), target)
        XCTAssertTrue(try TestSupport.git(["show", "HEAD:README.md"], at: root).contains("## 最近完成"))
        XCTAssertFalse(try sync.run(database: Self.fixture, target: target).committed)
    }

    func testReconcileArchivesContainersAndPreservesForeignFiles() throws {
        let root = try TestSupport.temporaryDirectory()
        let db = try copyDatabase(to: root)
        let output = try ThingsExport.render(ThingsReader.read(at: db))
        let paths = try ThingsExport.reconcile(output, at: root)
        XCTAssertTrue(paths.contains("Inbox.md"))
        let project = try XCTUnwrap(output.containers.first { $0.value.hasPrefix("Projects/") })
        let file = root.appendingPathComponent(project.value + "/tasks.md")
        let contents = try Data(contentsOf: file)
        try Data("keep".utf8).write(to: file.deletingLastPathComponent().appendingPathComponent("personal.txt"))
        try sql("UPDATE TMTask SET trashed=1 WHERE uuid='\(project.key)'", at: db)
        _ = try ThingsExport.reconcile(ThingsExport.render(ThingsReader.read(at: db)), at: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Archived/" + project.value + "/tasks.md")), contents)
        XCTAssertEqual(try String(contentsOf: file.deletingLastPathComponent().appendingPathComponent("personal.txt")), "keep")
        XCTAssertThrowsError(try ThingsExport.reconcile(output, at: root.appendingPathComponent("missing")))
    }

    func testUnownedFilesAndSymlinksBlockBeforeWriting() throws {
        let root = try TestSupport.temporaryDirectory()
        let output = try ThingsExport.render(ThingsReader.read(at: Self.fixture))
        try Data("user readme".utf8).write(to: root.appendingPathComponent("README.md"))
        XCTAssertThrowsError(try ThingsExport.reconcile(output, at: root))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("README.md")), "user readme")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Inbox.md").path))
        try FileManager.default.removeItem(at: root.appendingPathComponent("README.md"))
        try Data("user notes".utf8).write(to: root.appendingPathComponent("Today.md"))
        XCTAssertThrowsError(try ThingsExport.reconcile(output, at: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Inbox.md").path))
        try FileManager.default.removeItem(at: root.appendingPathComponent("Today.md"))
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("Projects").path, withDestinationPath: root.path)
        XCTAssertThrowsError(try ThingsExport.reconcile(output, at: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Inbox.md").path))
    }

    func testMalformedManifestCannotArchiveUserFiles() throws {
        let root = try TestSupport.temporaryDirectory()
        let user = root.appendingPathComponent("Projects/Personal")
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
        try Data("private notes".utf8).write(to: user.appendingPathComponent("tasks.md"))
        let manifest = """
        {"owner":"happatools-things3","version":1,"files":[],"containers":{"gone":"Projects/Personal"},"archived":{}}
        """
        try Data(manifest.utf8).write(to: root.appendingPathComponent(ThingsExport.manifestPath))
        XCTAssertThrowsError(try ThingsExport.reconcile(ThingsExport.render(ThingsReader.read(at: Self.fixture)), at: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Archived").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Inbox.md").path))
    }

    func testCaseOnlyRenameAndChecklistCompletionDate() throws {
        let root = try TestSupport.temporaryDirectory()
        let db = try copyDatabase(to: root)
        let original = try ThingsExport.render(ThingsReader.read(at: db))
        _ = try ThingsExport.reconcile(original, at: root)
        try sql("UPDATE TMTask SET title=lower(title) WHERE type=1; UPDATE TMChecklistItem SET status=3,stopDate=1234567890 WHERE title='Item 2'", at: db)
        let output = try ThingsExport.render(ThingsReader.read(at: db))
        XCTAssertTrue(output.files["Inbox.md"]!.contains("完成/取消时间"))
        XCTAssertNoThrow(try ThingsExport.reconcile(output, at: root))
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"))
        let pattern = try NSRegularExpression(pattern: #"\]\(([^)]+)\)"#)
        for match in pattern.matches(in: readme, range: NSRange(readme.startIndex..., in: readme)) {
            let range = try XCTUnwrap(Range(match.range(at: 1), in: readme))
            let path = try XCTUnwrap(String(readme[range]).removingPercentEncoding)
            XCTAssertNotNil(original.files[path], path)
        }
    }

    func testFailedCommitRetriesPreviouslyStagedDeletions() throws {
        let (root, _) = try TestSupport.configuredRepository()
        let db = try copyDatabase(to: root.deletingLastPathComponent())
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/usr/bin/git"))
        let target = try ThingsSyncTarget.capture(at: root, executor: executor)
        let sync = ThingsSync(executor: executor)
        _ = try sync.run(database: db, target: target)
        let original = try ThingsExport.render(ThingsReader.read(at: db))
        let project = try XCTUnwrap(original.containers.first { $0.value.hasPrefix("Projects/") })
        try sql("UPDATE TMTask SET title='Renamed' WHERE uuid='\(project.key)'", at: db)
        try TestSupport.git(["config", "commit.gpgSign", "true"], at: root)
        try TestSupport.git(["config", "gpg.program", root.appendingPathComponent("missing-gpg").path], at: root)
        XCTAssertThrowsError(try sync.run(database: db, target: target))
        try TestSupport.git(["config", "commit.gpgSign", "false"], at: root)
        XCTAssertTrue(try sync.run(database: db, target: target).committed)
        XCTAssertEqual(try TestSupport.git(["diff", "--cached", "--name-only"], at: root), "")
        XCTAssertFalse(try TestSupport.git(["ls-tree", "-r", "--name-only", "HEAD"], at: root).contains(project.value + "/"))
    }

    func testWALChangesAndUnreadableDatabaseProtectPreviousExport() throws {
        let (root, _) = try TestSupport.configuredRepository()
        let dbURL = try copyDatabase(to: root.deletingLastPathComponent())
        var writer: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbURL.path, &writer), SQLITE_OK)
        let db = try XCTUnwrap(writer)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL; UPDATE TMTask SET title='Changed in WAL' WHERE uuid='DfYoiXcNLQssk9DkSoJV3Y';", nil, nil, nil), SQLITE_OK)
        let snapshot = try ThingsReader.read(at: dbURL)
        XCTAssertTrue(try ThingsExport.render(snapshot).files["Inbox.md"]!.contains("Changed in WAL"))
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/usr/bin/git"))
        let target = try ThingsSyncTarget.capture(at: root, executor: executor)
        let sync = ThingsSync(executor: executor)
        _ = try sync.run(database: dbURL, target: target)
        let original = try Data(contentsOf: root.appendingPathComponent("Inbox.md"))
        XCTAssertThrowsError(try sync.run(database: root.appendingPathComponent("missing.sqlite"), target: target))
        XCTAssertEqual(original, try Data(contentsOf: root.appendingPathComponent("Inbox.md")))
        try TestSupport.git(["remote", "set-url", "origin", root.appendingPathComponent("another.git").path], at: root)
        XCTAssertThrowsError(try sync.run(database: dbURL, target: target))
        XCTAssertEqual(original, try Data(contentsOf: root.appendingPathComponent("Inbox.md")))
    }

    func testSyncPreservesStagingAndRetriesPushWithoutChanges() throws {
        let (root, remote) = try TestSupport.configuredRepository()
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/usr/bin/git"))
        let target = try ThingsSyncTarget.capture(at: root, executor: executor)
        let sync = ThingsSync(executor: executor)
        try Data("staged".utf8).write(to: root.appendingPathComponent("personal.txt"))
        try TestSupport.git(["add", "personal.txt"], at: root)
        let hidden = remote.appendingPathExtension("offline")
        try FileManager.default.moveItem(at: remote, to: hidden)
        XCTAssertThrowsError(try sync.run(database: Self.fixture, target: target))
        let head = try TestSupport.git(["rev-parse", "HEAD"], at: root)
        XCTAssertEqual(try TestSupport.git(["diff", "--cached", "--name-only"], at: root), "personal.txt\n")
        XCTAssertFalse(try TestSupport.git(["show", "--format=", "--name-only", "HEAD"], at: root).contains("personal.txt"))
        try FileManager.default.moveItem(at: hidden, to: remote)
        let retry = try sync.run(database: Self.fixture, target: target)
        XCTAssertFalse(retry.committed)
        XCTAssertTrue(retry.pushed)
        XCTAssertEqual(try TestSupport.git(["rev-parse", "refs/heads/main"], at: remote), head)
        XCTAssertFalse(try sync.run(database: Self.fixture, target: target).committed)
        try TestSupport.git(["checkout", "-b", "other"], at: root)
        XCTAssertThrowsError(try sync.run(database: Self.fixture, target: target))
    }
}
