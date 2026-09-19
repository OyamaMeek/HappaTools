import Foundation

public final class GitValidator {
    private let executor: GitExecutor

    public init(executor: GitExecutor) {
        self.executor = executor
    }

    public func isGitRepository(at directory: URL) throws -> Bool {
        do {
            let result = try executor.run(["rev-parse", "--is-inside-work-tree"], at: directory)
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch GitError.commandFailed {
            return false
        }
    }

    public func hasRemoteTracking(at directory: URL, branch: String) throws -> Bool {
        do {
            _ = try executor.run(["rev-parse", "--verify", "--quiet", "\(branch)@{upstream}"], at: directory)
            return true
        } catch GitError.commandFailed {
            return false
        }
    }

    public func currentBranch(at directory: URL) throws -> String {
        do {
            let result = try executor.run(["symbolic-ref", "--quiet", "HEAD"], at: directory)
            let reference = result.stdout.hasSuffix("\n")
                ? String(result.stdout.dropLast())
                : result.stdout
            let prefix = "refs/heads/"
            guard reference.hasPrefix(prefix), reference.count > prefix.count else {
                throw GitError.detachedHEAD
            }
            return String(reference.dropFirst(prefix.count))
        } catch GitError.commandFailed {
            throw GitError.detachedHEAD
        }
    }
}
