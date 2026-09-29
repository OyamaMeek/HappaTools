import Foundation

public struct ThingsSyncTarget: Codable, Equatable {
    public let root: URL
    public let branch: String
    public let remote: String
    public let destination: String
    let remoteURL: String

    public static func capture(at directory: URL, executor: GitExecutor) throws -> ThingsSyncTarget {
        let validator = GitValidator(executor: executor)
        guard try validator.isGitRepository(at: directory) else { throw GitError.notRepository }
        func git(_ args: [String]) throws -> String {
            let value = try executor.run(args, at: directory).stdout
            return value.hasSuffix("\n") ? String(value.dropLast()) : value
        }
        let root = try URL(fileURLWithPath: git(["rev-parse", "--show-toplevel"])).resolvingSymlinksInPath()
        let branch = try validator.currentBranch(at: root)
        guard try validator.hasRemoteTracking(at: root, branch: branch) else { throw GitError.noRemote }
        let remote = try git(["config", "--get", "branch.\(branch).remote"])
        let destination = try git(["config", "--get", "branch.\(branch).merge"])
        guard !remote.isEmpty, remote != ".", destination.hasPrefix("refs/heads/") else { throw GitError.noRemote }
        let remoteURL = try git(["remote", "get-url", "--push", "--all", "--", remote])
        guard !remoteURL.isEmpty, !remoteURL.contains("\n") else {
            throw ThingsFailure("Things3 自动上传需要唯一的远端推送地址。")
        }
        return ThingsSyncTarget(root: root, branch: branch, remote: remote, destination: destination, remoteURL: remoteURL)
    }
}

public struct ThingsSyncResult {
    public let committed: Bool
    public let pushed: Bool
    public let taskCount: Int
}

public final class ThingsSync {
    private let executor: GitExecutor
    public init(executor: GitExecutor) { self.executor = executor }

    public func run(database: URL, target: ThingsSyncTarget) throws -> ThingsSyncResult {
        let lock = try RepositoryLock(path: target.root.path)
        defer { withExtendedLifetime(lock) {} }
        guard try ThingsSyncTarget.capture(at: target.root, executor: executor) == target else {
            throw ThingsFailure("仓库分支或上游已变化，请在 Things3 页面重新选择仓库。")
        }
        let gitDirectory = try executor.run(["rev-parse", "--absolute-git-dir"], at: target.root).stdout.trimmingCharacters(in: .newlines)
        for name in ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "index.lock"] {
            guard !FileManager.default.fileExists(atPath: URL(fileURLWithPath: gitDirectory).appendingPathComponent(name).path) else {
                throw ThingsFailure("仓库正在进行其他 Git 操作，请完成后重试。")
            }
        }
        let snapshot = try ThingsReader.read(at: database)
        let paths = try ThingsExport.reconcile(ThingsExport.render(snapshot), at: target.root)
        let tracked = try executor.run(["--literal-pathspecs", "ls-files", "-z", "--"] + paths, at: target.root).stdout.split(separator: "\0").map(String.init)
        let stageable = Set(tracked).union(paths.filter { FileManager.default.fileExists(atPath: target.root.appendingPathComponent($0).path) }).sorted()
        let committedPaths = try executor.run(["--literal-pathspecs", "ls-tree", "-r", "--name-only", "-z", "HEAD", "--"] + paths, at: target.root).stdout.split(separator: "\0").map(String.init)
        let relevant = Set(stageable).union(committedPaths).sorted()
        _ = try executor.run(["--literal-pathspecs", "add", "--"] + stageable, at: target.root)
        let diff = try executor.run(["--literal-pathspecs", "diff", "--cached", "--name-only", "-z", "--"] + relevant, at: target.root)
        let committed = !diff.stdout.isEmpty
        if committed {
            _ = try executor.run(["--literal-pathspecs", "commit", "--only", "-m", "chore: sync Things3", "--"] + relevant, at: target.root)
        }
        guard try ThingsSyncTarget.capture(at: target.root, executor: executor) == target else {
            throw ThingsFailure("同步期间仓库分支或上游发生变化，本地导出已保留。")
        }
        let ahead = try executor.run(["rev-list", "--count", "@{upstream}..HEAD"], at: target.root).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let count = Int(ahead) else { throw ThingsFailure("无法判断待推送提交数量。") }
        if count > 0 {
            do {
                _ = try executor.run(["push", "--", target.remote, "HEAD:\(target.destination)"], at: target.root)
            } catch {
                throw ThingsFailure("Things3 推送失败，本地提交已保留；请检查网络、认证或远端冲突，下次同步会重试。")
            }
        }
        return ThingsSyncResult(committed: committed, pushed: count > 0, taskCount: snapshot.taskCount)
    }
}
