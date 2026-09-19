import Foundation
import XCTest
@testable import HappaToolsShared

final class FinderRequestTests: XCTestCase {
    func testRoundTripsOperationsWithoutDirectory() throws {
        for operation in [FinderRequest.Operation.git, .readme] {
            let request = FinderRequest(operation: operation, directory: nil)
            let decoded = try FinderRequest(url: request.url)

            XCTAssertEqual(decoded.operation, operation)
            XCTAssertNil(decoded.directory)
        }
    }

    func testRoundTripsDirectoryWithReservedAndUnicodeCharacters() throws {
        let path = "/tmp/中文 空格/#片段?/换\n行"
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let request = FinderRequest(operation: .git, directory: directory)

        let decoded = try FinderRequest(url: request.url)

        XCTAssertEqual(decoded.operation, .git)
        XCTAssertEqual(decoded.directory?.path, path)
        XCTAssertFalse(request.url.absoluteString.contains("#片段"))
    }

    func testAcceptsSlashURLPathAndAbsoluteDirectory() throws {
        let decoded = try FinderRequest(url: URL(string: "happatools://readme/?path=/tmp/project")!)

        XCTAssertEqual(decoded.operation, .readme)
        XCTAssertEqual(decoded.directory?.path, "/tmp/project")
    }

    func testRejectsUntrustedURLShapes() {
        let invalidURLs = [
            "https://git",
            "happatools:git",
            "happatools://other",
            "happatools://user@git",
            "happatools://git:123",
            "happatools://git/#fragment",
            "happatools://git/extra",
            "happatools://git?unknown=value",
            "happatools://git?path=/tmp/a&path=/tmp/b",
            "happatools://git?path",
            "happatools://git?path=",
            "happatools://git?path=relative",
            "happatools://git?path=%00/tmp"
        ]

        for value in invalidURLs {
            XCTAssertThrowsError(try FinderRequest(url: URL(string: value)!), value)
        }
    }

    func testOperationInProgressDefaultsAndPersists() {
        let suite = "FinderRequestTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = UserSettings(defaults: defaults)
        XCTAssertFalse(settings.operationInProgress)
        settings.operationInProgress = true

        XCTAssertTrue(UserSettings(defaults: UserDefaults(suiteName: suite)!).operationInProgress)
    }
}
