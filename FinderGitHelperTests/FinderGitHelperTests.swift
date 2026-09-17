import AppKit
import XCTest

final class FinderGitHelperTests: XCTestCase {
    private var directory: URL!
    private var previousGitCeiling: String?

    override func setUpWithError() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/test-data", isDirectory: true)
        directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        previousGitCeiling = ProcessInfo.processInfo.environment["GIT_CEILING_DIRECTORIES"]
        setenv("GIT_CEILING_DIRECTORIES", root.path, 1)
    }

    override func tearDownWithError() throws {
        if let previousGitCeiling = previousGitCeiling {
            setenv("GIT_CEILING_DIRECTORIES", previousGitCeiling, 1)
        } else {
            unsetenv("GIT_CEILING_DIRECTORIES")
        }
        try FileManager.default.removeItem(at: directory)
    }

    func testSettingsDefaultsAndPersistence() throws {
        let suite = "FinderGitHelperTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.defaultBranch, "main")
        XCTAssertTrue(settings.showGitButton)
        XCTAssertTrue(settings.showReadmeButton)
        settings.defaultBranch = "feature/example"
        settings.showGitButton = false
        settings.showReadmeButton = false
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.defaultBranch, "feature/example")
        XCTAssertFalse(reloaded.showGitButton)
        XCTAssertFalse(reloaded.showReadmeButton)
    }

    func testDateTemplateUsesCalendarYearAnd24HourTime() throws {
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        XCTAssertEqual(DateFormatter.commitMessage(for: Date(timeIntervalSince1970: 0), timeZone: utc), "1970-01-01 00:00")
        XCTAssertEqual(DateFormatter.commitMessage(for: Date(timeIntervalSince1970: 1609459140), timeZone: utc), "2020-12-31 23:59")
    }

    func testFinderAppleScriptsCompile() throws {
        for source in [FinderService.pathScript, FinderService.refreshScript] {
            let script = try XCTUnwrap(NSAppleScript(source: source))
            var error: NSDictionary?
            XCTAssertTrue(script.compileAndReturnError(&error), "\(String(describing: error))")
        }
    }

    func testFinderPathValidation() {
        if case .noWindow = FinderService.parsePath("") {} else { XCTFail("Expected no window") }
        if case .success(let path) = FinderService.parsePath(directory.path) {
            XCTAssertEqual(path, directory.path)
        } else { XCTFail("Expected a local directory") }
        if case .error = FinderService.parsePath("file:///Network") {} else { XCTFail("Expected special location error") }
        if case .error = FinderService.parsePath(directory.appendingPathComponent("missing").path) {} else { XCTFail("Expected missing directory error") }
    }

    func testReadmeCreationNeverOverwritesExistingContent() throws {
        try ReadmeService.create(at: directory)
        let file = directory.appendingPathComponent("README.md")
        XCTAssertTrue(ReadmeService.exists(at: directory))
        XCTAssertEqual(try Data(contentsOf: file), Data())
        try Data("keep this".utf8).write(to: file)
        XCTAssertThrowsError(try ReadmeService.create(at: directory))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "keep this")
    }

    func testReadmeDoesNotFollowDanglingSymlink() throws {
        let destination = directory.appendingPathComponent("missing")
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("README.md"), withDestinationURL: destination)
        XCTAssertTrue(ReadmeService.exists(at: directory))
        XCTAssertThrowsError(try ReadmeService.create(at: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testCommandConstructionKeepsMessageAsSingleArgument() throws {
        var commands = [[String]]()
        let message = "a quote \"; $(touch injected)\nsecond line"
        let service = GitService { arguments, path in
            XCTAssertEqual(path, self.directory)
            commands.append(arguments)
            let output: String
            switch arguments {
            case ["symbolic-ref", "--quiet", "--short", "HEAD"]: output = "main\n"
            case ["rev-parse", "--is-inside-work-tree"]: output = "true\n"
            default: output = ""
            }
            let status: Int32 = arguments == ["diff", "--cached", "--quiet", "--exit-code"] ? 1 : 0
            return .success(CommandOutput(status: status, output: output))
        }
        try service.commitAndPush(message: message, branch: "main", path: directory).get()
        XCTAssertEqual(Array(commands.suffix(4)), [
            ["add", "."], ["diff", "--cached", "--quiet", "--exit-code"],
            ["commit", "-m", message], ["push", "origin", "main"]
        ])
    }

    func testInvalidInputDoesNotRunGit() {
        let service = GitService { _, _ in
            XCTFail("Invalid input must be rejected before launching Git")
            return .success(CommandOutput(status: 0, output: ""))
        }
        XCTAssertThrowsError(try service.commitAndPush(message: " \n", branch: "main", path: directory).get())
        XCTAssertThrowsError(try service.commitAndPush(message: "ok", branch: "--all", path: directory).get())
        XCTAssertThrowsError(try service.commitAndPush(message: "ok", branch: "HEAD", path: directory).get())
        XCTAssertThrowsError(try service.commitAndPush(message: "bad\0message", branch: "main", path: directory).get())
    }

    func testRealCommitAndPushWithMultilineMessageAndUnusualPath() throws {
        let repo = try makeRepository(name: "repo ' \" $ (space)")
        let remote = try makeRemote()
        try git(["remote", "add", "origin", remote.path], in: repo)
        let message = "feat: first change\n\nLiteral $(touch injected) and \"quotes\""
        try Data("hello".utf8).write(to: repo.appendingPathComponent("hello.txt"))
        try GitService().commitAndPush(message: message, branch: "main", path: repo).get()
        let local = try git(["rev-parse", "HEAD"], in: repo)
        XCTAssertEqual(local, try git(["rev-parse", "refs/heads/main"], in: remote))
        XCTAssertEqual(try git(["log", "-1", "--format=%B"], in: repo).trimmingCharacters(in: .whitespacesAndNewlines), message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repo.appendingPathComponent("injected").path))
        XCTAssertEqual(try git(["status", "--porcelain"], in: repo), "")
        XCTAssertThrowsError(try GitService().commitAndPush(message: "again", branch: "main", path: repo).get()) { error in
            XCTAssertEqual(error.localizedDescription, "No changes to commit.")
        }
    }

    func testBranchMismatchStopsBeforeStaging() throws {
        let repo = try makeRepository()
        try Data("keep unstaged".utf8).write(to: repo.appendingPathComponent("change.txt"))
        XCTAssertThrowsError(try GitService().commitAndPush(message: "wrong branch", branch: "other", path: repo).get())
        XCTAssertEqual(try git(["diff", "--cached", "--name-only"], in: repo), "")
    }

    func testNotARepositoryHasActionableError() {
        XCTAssertThrowsError(try GitService().commitAndPush(message: "test", branch: "main", path: directory).get()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Not a git repository. Run 'git init' first."))
        }
    }

    func testPushFailureCanRetryWithoutCreatingAnotherCommit() throws {
        let repo = try makeRepository()
        try Data("hello".utf8).write(to: repo.appendingPathComponent("hello.txt"))
        let service = GitService()
        guard case .failure(.pushFailed(let details)) = service.commitAndPush(message: "keep this commit", branch: "main", path: repo) else {
            return XCTFail("Expected push failure with a retained local commit")
        }
        XCTAssertTrue(details.contains("origin"))
        let original = try git(["rev-parse", "HEAD"], in: repo)
        let remote = try makeRemote()
        try git(["remote", "add", "origin", remote.path], in: repo)
        try service.retryPush(branch: "main", path: repo).get()
        XCTAssertEqual(original, try git(["rev-parse", "HEAD"], in: repo))
        XCTAssertEqual(original, try git(["rev-parse", "refs/heads/main"], in: remote))
        XCTAssertEqual(try git(["rev-list", "--count", "HEAD"], in: repo), "1\n")
    }

    func testSubdirectoryStagesOnlyThatDirectory() throws {
        let repo = try makeRepository()
        let remote = try makeRemote()
        try git(["remote", "add", "origin", remote.path], in: repo)
        let child = repo.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: child.appendingPathComponent("inside.txt"))
        try Data("outside".utf8).write(to: repo.appendingPathComponent("outside.txt"))
        try GitService().commitAndPush(message: "child only", branch: "main", path: child).get()
        XCTAssertEqual(try git(["ls-tree", "-r", "--name-only", "HEAD"], in: repo), "child/inside.txt\n")
        XCTAssertTrue(try git(["status", "--porcelain"], in: repo).contains("outside.txt"))
    }

    func testProcessPreservesLargeOutputAndReportsTimeout() throws {
        let large = String(repeating: "x", count: 100_000)
        let result = try ProcessRunner.run(executable: "/usr/bin/printf", arguments: ["%s", large], directory: directory, timeout: 5).get()
        XCTAssertEqual(result.output, large)
        let start = Date()
        XCTAssertThrowsError(try ProcessRunner.run(executable: "/bin/sleep", arguments: ["10"], directory: directory, timeout: 0.1).get()) { error in
            XCTAssertTrue(error.localizedDescription.contains("timed out"))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testProcessReportsLaunchFailureAndStderr() throws {
        XCTAssertThrowsError(try ProcessRunner.run(executable: "/no/such/executable", arguments: [], directory: directory).get())
        let result = try ProcessRunner.run(executable: "/usr/bin/git", arguments: ["not-a-real-command"], directory: directory).get()
        XCTAssertNotEqual(result.status, 0)
        XCTAssertTrue(result.output.contains("not-a-real-command"))
    }

    private func makeRepository(name: String = "repo") throws -> URL {
        let repo = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "FinderGitHelper Tests"], in: repo)
        try git(["config", "user.email", "tests@example.invalid"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        try git(["config", "core.hooksPath", "/dev/null"], in: repo)
        return repo
    }

    private func makeRemote() throws -> URL {
        let remote = directory.appendingPathComponent("remote.git", isDirectory: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare"], in: remote)
        return remote
    }

    @discardableResult
    private func git(_ arguments: [String], in path: URL) throws -> String {
        let result = try ProcessRunner.run(executable: "/usr/bin/git", arguments: arguments, directory: path).get()
        guard result.status == 0 else { throw GitError.commandFailed(result.output) }
        return result.output
    }
}
