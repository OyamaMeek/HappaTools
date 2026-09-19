import Foundation
import XCTest
@testable import HappaToolsShared

final class GitExecutorTests: XCTestCase {
    func testNonzeroExitPreservesStructuredOutput() throws {
        let directory = try TestSupport.temporaryDirectory()
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/bin/sh"))

        XCTAssertThrowsError(try executor.run(["-c", "printf out; printf err >&2; exit 7"], at: directory)) { error in
            guard case let GitError.commandFailed(_, exitCode, stdout, stderr) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(exitCode, 7)
            XCTAssertEqual(stdout, "out")
            XCTAssertEqual(stderr, "err")
        }
    }

    func testLargeStdoutAndStderrDoNotDeadlock() throws {
        let directory = try TestSupport.temporaryDirectory()
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/bin/sh"), timeout: 10)
        let result = try executor.run(["-c", "i=0; while [ $i -lt 120000 ]; do printf 1234567890; printf abcdefghij >&2; i=$((i+1)); done"], at: directory)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertFalse(result.stdout.isEmpty)
        XCTAssertFalse(result.stderr.isEmpty)
        XCTAssertEqual(result.stdout.utf8.count, 1_048_576)
        XCTAssertEqual(result.stderr.utf8.count, 1_048_576)
    }

    func testTimeoutReturnsWithoutWaitingForChildHoldingPipes() throws {
        let directory = try TestSupport.temporaryDirectory()
        let marker = directory.appendingPathComponent("orphan.txt")
        let executor = GitExecutor(executableURL: URL(fileURLWithPath: "/bin/sh"), timeout: 0.2)
        let started = Date()
        XCTAssertThrowsError(try executor.run(
            ["-c", "trap '' TERM HUP; (trap '' TERM HUP; sleep 0.5; printf orphan > '\(marker.path)') & wait"],
            at: directory
        )) { error in
            guard case GitError.timedOut = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
}
