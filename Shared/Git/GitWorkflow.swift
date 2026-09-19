import Darwin
import Foundation

public final class GitWorkflow {
    private let executor: GitExecutor
    private let database: DatabaseManager

    public init(executor: GitExecutor, database: DatabaseManager) {
        self.executor = executor
        self.database = database
    }

    public func commitAndPush(at directory: URL, message: String, preferredBranch: String) throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            try log(type: "git_commit", path: directory.path, message: message, error: GitError.blankCommitMessage)
            throw GitError.blankCommitMessage
        }

        let context: RepositoryContext
        do {
            context = try repositoryContext(at: directory, preferredBranch: preferredBranch)
        } catch {
            try log(type: "git_commit", path: directory.path, message: message, error: error)
            throw error
        }

        let repositoryLock: RepositoryLock
        do {
            repositoryLock = try RepositoryLock(path: context.root.path)
        } catch {
            try log(type: "git_commit", path: context.root.path, message: message, error: error)
            throw error
        }
        defer { withExtendedLifetime(repositoryLock) {} }

        var commitCreated = false
        var commitStdout = ""
        var commitStderr = ""
        do {
            let add = try executor.run(["add", "-A"], at: context.root)
            let staged = try executor.run(["diff", "--cached", "--name-only"], at: context.root)
            if staged.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                commitStdout = add.stdout + "无可提交更改"
                commitStderr = add.stderr
            } else {
                let commit = try executor.run(["commit", "-m", message], at: context.root)
                commitCreated = true
                commitStdout = add.stdout + commit.stdout
                commitStderr = add.stderr + commit.stderr
            }
            try database.insertLog(OperationRecord(
                operationType: "git_commit",
                targetPath: context.root.path,
                commitMessage: message,
                stdout: commitStdout,
                stderr: commitStderr,
                status: "success"
            ))
        } catch {
            try log(type: "git_commit", path: context.root.path, message: message, error: error)
            throw error
        }

        do {
            let push = try executor.run(
                ["push", "--", context.remote, "HEAD:\(context.destination)"],
                at: context.root
            )
            try database.insertLog(OperationRecord(
                operationType: "git_push",
                targetPath: context.root.path,
                commitMessage: message,
                stdout: push.stdout,
                stderr: push.stderr,
                status: "success"
            ))
        } catch {
            let output = output(from: error)
            try database.insertLog(OperationRecord(
                operationType: "git_push",
                targetPath: context.root.path,
                commitMessage: message,
                stdout: output.stdout,
                stderr: output.stderr.isEmpty ? error.localizedDescription : output.stderr,
                status: "failure"
            ))
            if commitCreated {
                throw GitError.pushFailedLocalCommitPreserved(
                    stdout: output.stdout,
                    stderr: output.stderr.isEmpty ? error.localizedDescription : output.stderr
                )
            }
            throw error
        }
    }

    private func repositoryContext(at directory: URL, preferredBranch: String) throws -> RepositoryContext {
        let validator = GitValidator(executor: executor)
        guard try validator.isGitRepository(at: directory) else { throw GitError.notRepository }
        let rootOutput = try executor.run(["rev-parse", "--show-toplevel"], at: directory).stdout
        let rootPath = rootOutput.hasSuffix("\n") ? String(rootOutput.dropLast()) : rootOutput
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let detectedBranch = try validator.currentBranch(at: root)
        let branch = detectedBranch.isEmpty ? preferredBranch : detectedBranch
        guard !branch.isEmpty, try validator.hasRemoteTracking(at: root, branch: branch) else {
            throw GitError.noRemote
        }
        let remote = try config("branch.\(branch).remote", at: root)
        let merge = try config("branch.\(branch).merge", at: root)
        guard !remote.isEmpty, remote != ".", merge.hasPrefix("refs/heads/") else {
            throw GitError.noRemote
        }
        do {
            _ = try executor.run(["remote", "get-url", "--push", "--", remote], at: root)
        } catch GitError.commandFailed {
            throw GitError.noRemote
        }
        return RepositoryContext(
            root: root,
            remote: remote,
            destination: merge
        )
    }

    private func config(_ key: String, at directory: URL) throws -> String {
        do {
            return try executor.run(["config", "--get", key], at: directory).stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch GitError.commandFailed {
            throw GitError.noRemote
        }
    }

    private func log(type: String, path: String, message: String, error: Error) throws {
        let output = output(from: error)
        try database.insertLog(OperationRecord(
            operationType: type,
            targetPath: path,
            commitMessage: message,
            stdout: output.stdout,
            stderr: output.stderr.isEmpty ? error.localizedDescription : output.stderr,
            status: "failure"
        ))
    }

    private func output(from error: Error) -> (stdout: String, stderr: String) {
        switch error {
        case let GitError.commandFailed(_, _, stdout, stderr),
             let GitError.timedOut(_, stdout, stderr),
             let GitError.pushFailedLocalCommitPreserved(stdout, stderr):
            return (stdout, stderr)
        default:
            return ("", "")
        }
    }
}

private struct RepositoryContext {
    let root: URL
    let remote: String
    let destination: String
}

private final class RepositoryLock {
    private let descriptor: Int32

    init(path: String) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HappaToolsRepositoryLocks", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(Self.hash(path)).lock")
        descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw GitError.repositoryBusy }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw GitError.repositoryBusy
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }

    private static func hash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
