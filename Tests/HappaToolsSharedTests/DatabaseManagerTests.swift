import Foundation
import XCTest
@testable import HappaToolsShared

final class DatabaseManagerTests: XCTestCase {
    func testQuotesUnicodeNullFiltersAndReopen() throws {
        let directory = try TestSupport.temporaryDirectory()
        let url = directory.appendingPathComponent("logs.sqlite")
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let writer = try DatabaseManager(url: url)
        try writer.insertLog(OperationRecord(
            timestamp: old,
            operationType: "git_commit",
            targetPath: "/tmp/O'Reilly/你好",
            commitMessage: "quote ' and % wildcard",
            stdout: "完成",
            stderr: "",
            status: "success"
        ))
        try writer.insertLog(OperationRecord(
            timestamp: old.addingTimeInterval(1),
            operationType: "create_readme",
            targetPath: "/tmp/docs",
            status: "failure"
        ))

        let reopened = try DatabaseManager(url: url)
        let all = try reopened.records(limit: 10)
        XCTAssertEqual(all.count, 2)
        XCTAssertNil(all.first(where: { $0.operationType == "create_readme" })?.commitMessage)
        XCTAssertEqual(try reopened.records(search: "O'Reilly").count, 1)
        XCTAssertEqual(try reopened.records(search: "%").count, 1)
        XCTAssertEqual(try reopened.records(operationType: "git_commit", status: "success", since: old.addingTimeInterval(-1)).count, 1)
        XCTAssertEqual(try reopened.records(since: old.addingTimeInterval(0.5)).count, 1)
    }

    func testCleanupClearAndTwoInstancesShareData() throws {
        let directory = try TestSupport.temporaryDirectory()
        let url = directory.appendingPathComponent("logs.sqlite")
        let first = try DatabaseManager(url: url)
        let second = try DatabaseManager(url: url)
        try first.insertLog(OperationRecord(
            timestamp: Date(timeIntervalSince1970: 100),
            operationType: "old",
            targetPath: "/old",
            status: "success"
        ))
        try second.insertLog(OperationRecord(
            timestamp: Date(timeIntervalSince1970: 200),
            operationType: "new",
            targetPath: "/new",
            status: "success"
        ))
        XCTAssertEqual(try first.records().count, 2)

        try first.cleanupOldLogs(olderThan: Date(timeIntervalSince1970: 150))
        XCTAssertEqual(try second.records().map(\.operationType), ["new"])

        try second.clearAllLogs()
        XCTAssertTrue(try first.records().isEmpty)
    }
}
