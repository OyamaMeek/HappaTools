import Foundation

enum GitError: LocalizedError {
    case invalidInput(String)
    case notRepository(String)
    case noChanges
    case commandFailed(String)
    case pushFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message), .commandFailed(let message): return message
        case .notRepository(let details):
            return "Not a git repository. Run 'git init' first.\n\n\(details)"
        case .noChanges: return "No changes to commit."
        case .pushFailed(let details):
            return "Push failed. Your local commit is preserved. Check the origin remote, network and credentials, then use Retry Push. For rejected updates, reconcile the remote changes in Terminal first.\n\n\(details)"
        }
    }
}

struct GitService {
    typealias Runner = ([String], URL) -> Result<CommandOutput, GitError>
    private let run: Runner

    init(run: @escaping Runner = { arguments, path in
        ProcessRunner.run(executable: "/usr/bin/git", arguments: arguments, directory: path)
    }) {
        self.run = run
    }

    /// 顺序执行暂存、提交、推送；任一步骤失败立即停止，保留本地工作。
    func commitAndPush(message: String, branch: String, path: URL) -> Result<Void, GitError> {
        perform {
            guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !message.contains("\0") else {
                throw GitError.invalidInput("Enter a non-empty commit message without NUL characters.")
            }
            try validateRepository(branch: branch, path: path)
            try addAll(path: path).get()
            let diff = try run(["diff", "--cached", "--quiet", "--exit-code"], path).get()
            if diff.status == 0 { throw GitError.noChanges }
            guard diff.status == 1 else { throw GitError.commandFailed(diff.output) }
            try commit(message: message, path: path).get()
            try push(branch: branch, path: path).get()
        }
    }

    /// 重试只推送现有提交，不重新 add 或 commit。
    func retryPush(branch: String, path: URL) -> Result<Void, GitError> {
        perform {
            try validateRepository(branch: branch, path: path)
            try push(branch: branch, path: path).get()
        }
    }

    func addAll(path: URL) -> Result<Void, GitError> {
        perform { try checked(["add", "."], path: path) }
    }

    func commit(message: String, path: URL) -> Result<Void, GitError> {
        perform { try checked(["commit", "-m", message], path: path) }
    }

    func push(branch: String, path: URL) -> Result<Void, GitError> {
        perform {
            do {
                try checked(["push", "origin", branch], path: path)
            } catch {
                throw GitError.pushFailed(error.localizedDescription)
            }
        }
    }

    private func validateRepository(branch: String, path: URL) throws {
        guard !branch.isEmpty, !branch.hasPrefix("-"), branch != "HEAD", !branch.contains("\0"),
              !branch.contains(where: { $0.isWhitespace }) else {
            throw GitError.invalidInput("Enter a valid branch name in Settings, such as main.")
        }
        try checked(["check-ref-format", "refs/heads/\(branch)"], path: path)
        let repository = try run(["rev-parse", "--is-inside-work-tree"], path).get()
        guard repository.status == 0, repository.output.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            throw GitError.notRepository(repository.output)
        }
        let current = try run(["symbolic-ref", "--quiet", "--short", "HEAD"], path).get()
        guard current.status == 0 else {
            throw GitError.invalidInput("HEAD is detached. Check out a branch in Terminal before committing.\n\n\(current.output)")
        }
        let currentBranch = current.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentBranch == branch else {
            throw GitError.invalidInput("The current branch is '\(currentBranch)', but Settings specifies '\(branch)'. Change Settings or check out the intended branch in Terminal. No files were staged.")
        }
    }

    @discardableResult
    private func checked(_ arguments: [String], path: URL) throws -> String {
        let result = try run(arguments, path).get()
        guard result.status == 0 else {
            throw GitError.commandFailed("git \(arguments.first ?? "") failed (exit \(result.status)).\n\n\(result.output)")
        }
        return result.output
    }

    private func perform(_ operation: () throws -> Void) -> Result<Void, GitError> {
        do {
            try operation()
            return .success(())
        } catch let error as GitError {
            return .failure(error)
        } catch {
            return .failure(.commandFailed(error.localizedDescription))
        }
    }
}
