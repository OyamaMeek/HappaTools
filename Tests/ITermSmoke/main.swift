import AppKit

@discardableResult
func appleScript(_ source: String, arguments: [String] = []) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", source] + arguments
    process.standardOutput = output
    try process.run()
    let result = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    process.waitUntilExit()
    assert(process.terminationStatus == 0, "iTerm2 状态查询必须成功")
    return result
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    .appendingPathComponent(".build/iterm-smoke-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
for name in ["普通目录", "中文 空格 '引号\" $(false); exit; `false`"] {
    let directory = root.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let previousWindows = try appleScript("tell application id \"com.googlecode.iterm2\" to get id of every window")
    try ITermLauncher.open(at: directory)
    let newWindow = try appleScript("tell application id \"com.googlecode.iterm2\" to get id of current window")
    assert(!previousWindows.components(separatedBy: ", ").contains(newWindow), "必须新建独立窗口")
    let outputFile = root.appendingPathComponent("pwd-\(UUID().uuidString).txt")
    try appleScript("""
    on run argv
        tell application id "com.googlecode.iterm2"
            tell current session of window id \(newWindow) to write text ("pwd > " & quoted form of (item 1 of argv))
        end tell
    end run
    """, arguments: [outputFile.path])
    let outputDeadline = Date().addingTimeInterval(10)
    while !FileManager.default.fileExists(atPath: outputFile.path) && Date() < outputDeadline {
        Thread.sleep(forTimeInterval: 0.05)
    }
    let output = try String(contentsOf: outputFile, encoding: .utf8)
    assert(output == directory.path + "\n", "pwd 必须输出完整目标目录")
    assert(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("README.md").path))
    try appleScript("tell application id \"com.googlecode.iterm2\" to tell current session of window id \(newWindow) to write text \"exit\"")
}
print("iTerm2 真实检查通过：新窗口、实际工作目录、中文/空格/引号/命令元字符。")
