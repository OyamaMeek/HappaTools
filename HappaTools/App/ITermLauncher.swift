import AppKit

enum ITermLauncher {
    static func open(at directory: URL) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") != nil else {
            throw NSError(domain: "HappaTools.iTerm2", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "请先安装 iTerm2。"])
        }
        let script = """
        on run argv
            set commandText to "cd " & quoted form of (item 1 of argv) & "; clear; pwd"
            with timeout of 30 seconds
                tell application id "com.googlecode.iterm2"
                    set terminalWindow to create window with default profile
                    tell current session of terminalWindow to write text commandText
                    activate
                end tell
            end timeout
        end run
        """
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, directory.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let detail = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "HappaTools.iTerm2", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "无法打开 iTerm2：\(detail)"])
        }
    }
}
