import Foundation
import XCTest
@testable import HappaToolsShared

final class ReadmeCreatorTests: XCTestCase {
    func testCreatesEmptyReadmeAndLogsSuccess() throws {
        let directory = try TestSupport.temporaryDirectory()
        let database = try DatabaseManager(url: directory.appendingPathComponent("logs.sqlite"))
        let url = try ReadmeCreator.create(at: directory, database: database)
        XCTAssertEqual(try Data(contentsOf: url), Data())
        XCTAssertEqual(try database.records(operationType: "create_readme").first?.status, "success")
    }

    func testDoesNotOverwriteExistingFileOrFollowSymlink() throws {
        for useSymlink in [false, true] {
            let directory = try TestSupport.temporaryDirectory()
            let database = try DatabaseManager(url: directory.appendingPathComponent("logs.sqlite"))
            let readme = directory.appendingPathComponent("README.md")
            let original = directory.appendingPathComponent("original.txt")
            try Data("keep me".utf8).write(to: original)
            if useSymlink {
                try FileManager.default.createSymbolicLink(at: readme, withDestinationURL: original)
            } else {
                try Data("keep me".utf8).write(to: readme)
            }

            XCTAssertThrowsError(try ReadmeCreator.create(at: directory, database: database))
            XCTAssertEqual(try String(contentsOf: original), "keep me")
            if !useSymlink {
                XCTAssertEqual(try String(contentsOf: readme), "keep me")
            }
            XCTAssertEqual(try database.records(operationType: "create_readme").first?.status, "failure")
        }
    }
}
