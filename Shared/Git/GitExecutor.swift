import Darwin
import Foundation

public struct GitResult: Equatable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public enum GitError: Error, LocalizedError {
    case notRepository
    case noRemote
    case detachedHEAD
    case blankCommitMessage
    case executableUnavailable(path: String)
    case launchFailed(message: String)
    case repositoryBusy
    case commandFailed(arguments: [String], exitCode: Int32, stdout: String, stderr: String)
    case timedOut(arguments: [String], stdout: String, stderr: String)
    case pushFailedLocalCommitPreserved(stdout: String, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .notRepository:
            return "当前目录不是 Git 仓库"
        case .noRemote:
            return "未配置远程仓库"
        case .detachedHEAD:
            return "当前仓库处于 detached HEAD 状态"
        case .blankCommitMessage:
            return "提交信息不能为空"
        case let .executableUnavailable(path):
            return "Git 可执行文件不可用：\(path)"
        case let .launchFailed(message):
            return "无法启动 Git 命令：\(message)"
        case .repositoryBusy:
            return "该仓库正在执行 Git 操作"
        case let .commandFailed(arguments, exitCode, stdout, stderr):
            let detail = [stderr, stdout].first(where: { !$0.isEmpty }) ?? "无输出"
            return "Git 命令失败（\(exitCode)）：git \(arguments.joined(separator: " "))\n\(detail)"
        case let .timedOut(arguments, _, _):
            return "Git 命令超时：git \(arguments.joined(separator: " "))"
        case let .pushFailedLocalCommitPreserved(_, stderr):
            return "推送失败，本地提交已保留\(stderr.isEmpty ? "" : "：\(stderr)")"
        }
    }
}

public final class GitExecutor {
    // ponytail: 每路日志保留前 1 MiB；需要完整大输出时改为流式文件。
    private static let outputLimit = 1_048_576
    private let executableURL: URL
    private let timeout: TimeInterval

    public init(executableURL: URL, timeout: TimeInterval = 30) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    public func run(_ arguments: [String], at directory: URL) throws -> GitResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw GitError.executableUnavailable(path: executableURL.path)
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdout = StreamCapture(limit: Self.outputLimit)
        let stderr = StreamCapture(limit: Self.outputLimit)
        let readers = DispatchGroup()

        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GCM_INTERACTIVE"] = "Never"
        process.environment = environment

        startReading(stdoutPipe.fileHandleForReading, into: stdout, group: readers)
        startReading(stderrPipe.fileHandleForReading, into: stderr, group: readers)

        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        do {
            try process.run()
        } catch {
            let cleanupErrors = [
                stopReading(stdoutPipe.fileHandleForReading, capture: stdout, group: readers),
                stopReading(stderrPipe.fileHandleForReading, capture: stderr, group: readers)
            ].compactMap { $0?.localizedDescription }
            let details = ([error.localizedDescription] + cleanupErrors).joined(separator: "；")
            throw GitError.launchFailed(message: details)
        }

        let processGroup = getpgid(process.processIdentifier) == process.processIdentifier
            ? process.processIdentifier
            : 0
        let timedOut = completed.wait(timeout: .now() + max(timeout, 0.01)) == .timedOut
        if timedOut {
            if processGroup > 0 {
                kill(-processGroup, SIGTERM)
            } else {
                process.terminate()
            }
            _ = completed.wait(timeout: .now() + 0.25)
            if processGroup > 0 {
                kill(-processGroup, SIGKILL)
            } else if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            _ = completed.wait(timeout: .now() + 0.25)
        }

        if readers.wait(timeout: .now() + 0.25) == .timedOut {
            let cleanupErrors = [
                stopReading(stdoutPipe.fileHandleForReading, capture: stdout, group: readers),
                stopReading(stderrPipe.fileHandleForReading, capture: stderr, group: readers)
            ].compactMap { $0?.localizedDescription }
            if !cleanupErrors.isEmpty {
                stderr.append(Data(("\n" + cleanupErrors.joined(separator: "；")).utf8))
            }
            _ = readers.wait(timeout: .now() + 0.25)
        }

        let stdoutText = stdout.text
        let stderrText = stderr.text
        if timedOut {
            throw GitError.timedOut(arguments: arguments, stdout: stdoutText, stderr: stderrText)
        }

        let result = GitResult(
            stdout: stdoutText,
            stderr: stderrText,
            exitCode: process.terminationStatus
        )
        guard result.exitCode == 0 else {
            throw GitError.commandFailed(
                arguments: arguments,
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }
        return result
    }

    private func startReading(_ handle: FileHandle, into capture: StreamCapture, group: DispatchGroup) {
        group.enter()
        handle.readabilityHandler = { readable in
            let data = readable.availableData
            if data.isEmpty {
                readable.readabilityHandler = nil
                if capture.finish() { group.leave() }
            } else {
                capture.append(data)
            }
        }
    }

    private func stopReading(
        _ handle: FileHandle,
        capture: StreamCapture,
        group: DispatchGroup
    ) -> Error? {
        handle.readabilityHandler = nil
        let closeError: Error?
        do {
            try handle.close()
            closeError = nil
        } catch {
            closeError = error
        }
        if capture.finish() { group.leave() }
        return closeError
    }
}

private final class StreamCapture {
    private let limit: Int
    private let lock = NSLock()
    private var data = Data()
    private var finished = false

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ incoming: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard data.count < limit else { return }
        data.append(incoming.prefix(limit - data.count))
    }

    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
