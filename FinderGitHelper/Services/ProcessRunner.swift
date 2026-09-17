import Foundation

struct CommandOutput {
    let status: Int32
    let output: String
}

enum ProcessRunner {
    /// 在后台执行；合并输出写入文件，避免 stdout / stderr 管道互相阻塞。
    static func run(
        executable: String,
        arguments: [String],
        directory: URL,
        timeout: TimeInterval = 60
    ) -> Result<CommandOutput, GitError> {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("FinderGitHelper-\(UUID().uuidString)")
        do {
            try Data().write(to: outputURL, options: .withoutOverwriting)
            defer { try? FileManager.default.removeItem(at: outputURL) }
            let output = try FileHandle(forWritingTo: outputURL)
            defer { try? output.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = output
            var environment = ProcessInfo.processInfo.environment
            environment["GIT_TERMINAL_PROMPT"] = "0"
            environment["GCM_INTERACTIVE"] = "never"
            environment["SSH_ASKPASS_REQUIRE"] = "never"
            environment["LC_ALL"] = "C"
            process.environment = environment
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            try process.run()
            let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
            if timedOut && process.isRunning {
                process.terminate()
                if finished.wait(timeout: .now() + 1) == .timedOut && process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    process.waitUntilExit()
                }
            }
            try output.synchronize()
            let text = String(decoding: try Data(contentsOf: outputURL), as: UTF8.self)
            if timedOut {
                return .failure(.commandFailed("Git command timed out after \(timeout) seconds. Check the network, credentials, and Git hooks, then retry.\n\n\(text)"))
            }
            return .success(CommandOutput(status: process.terminationStatus, output: text))
        } catch {
            return .failure(.commandFailed("Could not run \(executable). Install Xcode Command Line Tools if Git is missing.\n\n\(error.localizedDescription)"))
        }
    }
}
