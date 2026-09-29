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
        _ = try ThingsExport.reconcile(ThingsExport.render(ThingsReader.read(at: db)), at: root)
        try sql("UPDATE TMTask SET title=lower(title) WHERE type=1; UPDATE TMChecklistItem SET status=3,stopDate=1234567890 WHERE title='Item 2'", at: db)
        let output = try ThingsExport.render(ThingsReader.read(at: db))
        XCTAssertTrue(output.files["Inbox.md"]!.contains("完成/取消时间"))
        XCTAssertNoThrow(try ThingsExport.reconcile(output, at: root))
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
