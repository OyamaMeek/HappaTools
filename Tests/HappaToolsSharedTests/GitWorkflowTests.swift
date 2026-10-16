import Darwin
import Foundation
import XCTest
@testable import HappaToolsShared

final class GitWorkflowTests: XCTestCase {
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    func testPullRebasesCurrentBranchOntoOriginMainWithoutUpstream() throws {
        let setup = try TestSupport.configuredRepository()
        let peer = setup.root.deletingLastPathComponent().appendingPathComponent("peer")
        try TestSupport.git(["clone", "--branch", "main", setup.remote.path, peer.path], at: setup.root)
        try TestSupport.git(["config", "user.name", "HappaTools Tests"], at: peer)
        try TestSupport.git(["config", "user.email", "tests@example.com"], at: peer)
        try Data("remote update\n".utf8).write(to: peer.appendingPathComponent("tracked.txt"))
        try TestSupport.git(["add", "-A"], at: peer)
        try TestSupport.git(["commit", "-m", "remote update"], at: peer)
        try TestSupport.git(["push", "origin", "main"], at: peer)
        let remoteHead = try TestSupport.git(["rev-parse", "refs/heads/main"], at: setup.remote)
        try TestSupport.git(["checkout", "--no-track", "-b", "topic"], at: setup.root)
        try Data("local\n".utf8).write(to: setup.root.appendingPathComponent("local.txt"))
        try TestSupport.git(["add", "-A"], at: setup.root)
        try TestSupport.git(["commit", "-m", "local update"], at: setup.root)
        let nested = setup.root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let database = try DatabaseManager(url: peer.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))

        try GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database).pull(at: nested)

        XCTAssertEqual(try TestSupport.git(["branch", "--show-current"], at: setup.root), "topic\n")
        XCTAssertEqual(try TestSupport.git(["rev-parse", "HEAD^"], at: setup.root), remoteHead)
        XCTAssertEqual(try TestSupport.git(["log", "-1", "--format=%s"], at: setup.root), "local update\n")
        XCTAssertEqual(try String(contentsOf: setup.root.appendingPathComponent("tracked.txt"), encoding: .utf8), "remote update\n")
        XCTAssertEqual(try String(contentsOf: setup.root.appendingPathComponent("local.txt"), encoding: .utf8), "local\n")
        XCTAssertEqual(try TestSupport.git(["rev-parse", "refs/heads/main"], at: setup.remote), remoteHead)
        XCTAssertEqual(try database.records(operationType: "git_pull").first?.status, "success")
    }

    func testPullPreservesDirtyWorktreeAndLogsGitFailure() throws {
        let setup = try TestSupport.configuredRepository()
        let file = setup.root.appendingPathComponent("tracked.txt")
        try Data("uncommitted\n".utf8).write(to: file)
        let before = try TestSupport.git(["rev-parse", "HEAD"], at: setup.root)
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))

        XCTAssertThrowsError(try GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database).pull(at: setup.root)) { error in
            guard case let GitError.commandFailed(arguments, _, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(arguments, ["pull", "--rebase", "origin", "main"])
        }
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "uncommitted\n")
        XCTAssertEqual(try TestSupport.git(["rev-parse", "HEAD"], at: setup.root), before)
        let record = try XCTUnwrap(database.records(operationType: "git_pull").first)
        XCTAssertEqual(record.status, "failure")
        XCTAssertFalse(record.stderr.isEmpty)
    }

    func testPullLeavesConflictForUserToResolve() throws {
        let setup = try TestSupport.configuredRepository()
        try Data("local change\n".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        try TestSupport.git(["commit", "-am", "local change"], at: setup.root)
        let localHead = try TestSupport.git(["rev-parse", "HEAD"], at: setup.root)
        try TestSupport.git(["checkout", "-b", "remote-update", "origin/main"], at: setup.root)
        try Data("remote change\n".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        try TestSupport.git(["commit", "-am", "remote change"], at: setup.root)
        try TestSupport.git(["push", "origin", "HEAD:main"], at: setup.root)
        try TestSupport.git(["checkout", "main"], at: setup.root)
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))

        XCTAssertThrowsError(try GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database).pull(at: setup.root))

        XCTAssertFalse(try TestSupport.git(["diff", "--name-only", "--diff-filter=U"], at: setup.root).isEmpty)
        XCTAssertEqual(try TestSupport.git(["rev-parse", "ORIG_HEAD"], at: setup.root), localHead)
        XCTAssertEqual(try TestSupport.git(["show", "ORIG_HEAD:tracked.txt"], at: setup.root), "local change\n")
        XCTAssertEqual(try database.records(operationType: "git_pull").first?.status, "failure")
    }

    func testPullRespectsRepositoryLock() throws {
        let setup = try TestSupport.configuredRepository()
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        let lock = try RepositoryLock(path: setup.root.path)
        defer { withExtendedLifetime(lock) {} }
        XCTAssertThrowsError(try GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database).pull(at: setup.root)) { error in
            guard case GitError.repositoryBusy = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try database.records(operationType: "git_pull").first?.status, "failure")
    }

    func testValidatorDistinguishesNonRepositoryAndMissingUpstream() throws {
        let directory = try TestSupport.temporaryDirectory()
        let gitBoundary = directory.appendingPathComponent(".git")
        try Data("gitdir: /nonexistent".utf8).write(to: gitBoundary)
        let executor = GitExecutor(executableURL: gitURL)
        let validator = GitValidator(executor: executor)
        XCTAssertFalse(try validator.isGitRepository(at: directory))
        let database = try DatabaseManager(url: directory.appendingPathComponent("logs.sqlite"))
        let workflow = GitWorkflow(executor: executor, database: database)
        XCTAssertThrowsError(try workflow.commitAndPush(at: directory, message: "message", preferredBranch: "main")) { error in
            XCTAssertEqual(error.localizedDescription, "当前目录不是 Git 仓库")
        }

        try FileManager.default.removeItem(at: gitBoundary)
        try TestSupport.git(["init", "-b", "main"], at: directory)
        XCTAssertTrue(try validator.isGitRepository(at: directory))
        XCTAssertFalse(try validator.hasRemoteTracking(at: directory, branch: "main"))
    }

    func testValidatorPropagatesUnavailableExecutableAndRejectsDetachedHead() throws {
        let directory = try TestSupport.temporaryDirectory()
        let missing = GitValidator(executor: GitExecutor(
            executableURL: directory.appendingPathComponent("missing-git")
        ))
        XCTAssertThrowsError(try missing.isGitRepository(at: directory)) { error in
            guard case GitError.executableUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let setup = try TestSupport.configuredRepository()
        try TestSupport.git(["checkout", "--detach"], at: setup.root)
        let validator = GitValidator(executor: GitExecutor(executableURL: gitURL))
        XCTAssertThrowsError(try validator.currentBranch(at: setup.root)) { error in
            guard case GitError.detachedHEAD = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCurrentBranchIgnoresSameNamedTag() throws {
        let setup = try TestSupport.configuredRepository()
        try TestSupport.git(["tag", "main"], at: setup.root)
        let validator = GitValidator(executor: GitExecutor(executableURL: gitURL))

        XCTAssertEqual(try validator.currentBranch(at: setup.root), "main")
    }

    func testConcurrentWorkflowIsRejectedWhileRepositoryLockIsHeld() throws {
        let setup = try TestSupport.configuredRepository()
        let hook = setup.root.appendingPathComponent(".git/hooks/pre-commit")
        let hookStarted = setup.root.appendingPathComponent(".git/hook-started")
        try Data("#!/bin/sh\ntouch .git/hook-started\nsleep 1\n".utf8).write(to: hook)
        XCTAssertEqual(chmod(hook.path, S_IRWXU), 0)
        try Data("changed".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        let databaseURL = setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite")
        let first = GitWorkflow(
            executor: GitExecutor(executableURL: gitURL, timeout: 5),
            database: try DatabaseManager(url: databaseURL)
        )
        let second = GitWorkflow(
            executor: GitExecutor(executableURL: gitURL, timeout: 5),
            database: try DatabaseManager(url: databaseURL)
        )
        let firstFinished = expectation(description: "first workflow finished")
        DispatchQueue.global().async {
            do {
                try first.commitAndPush(at: setup.root, message: "first", preferredBranch: "main")
            } catch {
                XCTFail("First workflow failed: \(error)")
            }
            firstFinished.fulfill()
        }

        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: hookStarted.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: hookStarted.path))
        XCTAssertThrowsError(try second.commitAndPush(at: setup.root, message: "second", preferredBranch: "main")) { error in
            guard case GitError.repositoryBusy = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        wait(for: [firstFinished], timeout: 5)
    }

    func testWorkflowStagesWholeRepositoryAndPushesMultilineMessageToCustomUpstream() throws {
        let setup = try TestSupport.configuredRepository(remoteName: "backup", upstreamBranch: "stable")
        let subdirectory = setup.root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)
        try Data("root change\n".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        try Data("nested\n".utf8).write(to: subdirectory.appendingPathComponent("new.txt"))
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        let workflow = GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)
        let message = "first line\nsecond line with 'quotes'"

        try workflow.commitAndPush(at: subdirectory, message: message, preferredBranch: "ignored")

        XCTAssertEqual(try TestSupport.git(["log", "-1", "--format=%B", "refs/heads/stable"], at: setup.remote).trimmingCharacters(in: .newlines), message)
        XCTAssertEqual(try TestSupport.git(["show", "refs/heads/stable:nested/new.txt"], at: setup.remote), "nested\n")
        XCTAssertEqual(try database.records(operationType: "git_commit").first?.status, "success")
        XCTAssertEqual(try database.records(operationType: "git_push").first?.status, "success")

        try workflow.commitAndPush(at: setup.root, message: "no changes", preferredBranch: "main")
        XCTAssertEqual(try TestSupport.git(["rev-list", "--count", "refs/heads/stable"], at: setup.remote).trimmingCharacters(in: .whitespacesAndNewlines), "2")
    }

    func testWorkflowPushesBranchWhenRemoteHasSameNamedTag() throws {
        let setup = try TestSupport.configuredRepository()
        let original = try TestSupport.git(["rev-parse", "HEAD"], at: setup.root)
            .trimmingCharacters(in: .newlines)
        try TestSupport.git(["tag", "main"], at: setup.root)
        try TestSupport.git(["push", "origin", "refs/tags/main"], at: setup.root)
        try Data("branch update\n".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        let database = try DatabaseManager(
            url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite")
        )
        let workflow = GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)

        try workflow.commitAndPush(at: setup.root, message: "update branch only", preferredBranch: "main")

        XCTAssertEqual(
            try TestSupport.git(["show", "refs/heads/main:tracked.txt"], at: setup.remote),
            "branch update\n"
        )
        XCTAssertEqual(
            try TestSupport.git(["rev-parse", "refs/tags/main^{}"], at: setup.remote)
                .trimmingCharacters(in: .newlines),
            original
        )
    }

    func testMissingUpstreamFailsBeforeStaging() throws {
        let directory = try TestSupport.temporaryDirectory()
        try TestSupport.git(["init", "-b", "main"], at: directory)
        try TestSupport.git(["config", "user.name", "HappaTools Tests"], at: directory)
        try TestSupport.git(["config", "user.email", "tests@example.com"], at: directory)
        try Data("untracked".utf8).write(to: directory.appendingPathComponent("file.txt"))
        let database = try DatabaseManager(url: directory.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        let workflow = GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)

        XCTAssertThrowsError(try workflow.commitAndPush(at: directory, message: "message", preferredBranch: "main")) { error in
            XCTAssertEqual(error.localizedDescription, "未配置远程仓库")
        }
        XCTAssertEqual(try TestSupport.git(["status", "--porcelain"], at: directory), "?? file.txt\n")
    }

    func testPushFailureKeepsLocalCommit() throws {
        let setup = try TestSupport.configuredRepository()
        try Data("changed".utf8).write(to: setup.root.appendingPathComponent("tracked.txt"))
        try TestSupport.git(["remote", "set-url", "--push", "origin", setup.root.deletingLastPathComponent().appendingPathComponent("missing.git").path], at: setup.root)
        let before = try TestSupport.git(["rev-parse", "HEAD"], at: setup.root)
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        let workflow = GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)

        XCTAssertThrowsError(try workflow.commitAndPush(at: setup.root, message: "local survives", preferredBranch: "main")) { error in
            XCTAssertTrue(error.localizedDescription.contains("本地提交已保留"))
        }
        let after = try TestSupport.git(["rev-parse", "HEAD"], at: setup.root)
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(try database.records(operationType: "git_push").first?.status, "failure")
    }

    func testBlankMessageIsRejected() throws {
        let setup = try TestSupport.configuredRepository()
        let database = try DatabaseManager(url: setup.root.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        let workflow = GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)
        XCTAssertThrowsError(try workflow.commitAndPush(at: setup.root, message: " \n ", preferredBranch: "main"))
    }

    func testRepositoryPathWithTrailingSpaceIsPreserved() throws {
        let setup = try TestSupport.configuredRepository()
        let directory = setup.root.deletingLastPathComponent().appendingPathComponent("repo with trailing space ", isDirectory: true)
        try FileManager.default.moveItem(at: setup.root, to: directory)
        try Data("space path\n".utf8).write(to: directory.appendingPathComponent("tracked.txt"))
        let database = try DatabaseManager(url: directory.deletingLastPathComponent().appendingPathComponent("logs.sqlite"))
        try GitWorkflow(executor: GitExecutor(executableURL: gitURL), database: database)
            .commitAndPush(at: directory, message: "path preserved", preferredBranch: "main")
        XCTAssertEqual(try TestSupport.git(["show", "refs/heads/main:tracked.txt"], at: setup.remote), "space path\n")
    }
}
