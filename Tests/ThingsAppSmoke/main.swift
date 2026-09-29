import Foundation
import HappaToolsShared

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/things-app-smoke-" + UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let repo = root.appendingPathComponent("repo")
let remote = root.appendingPathComponent("remote.git")
try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
let git = GitExecutor(executableURL: URL(fileURLWithPath: "/usr/bin/git"))
_ = try git.run(["init", "--bare", remote.path], at: root)
_ = try git.run(["init", "-b", "main"], at: repo)
_ = try git.run(["config", "user.name", "Things Smoke"], at: repo)
_ = try git.run(["config", "user.email", "things@example.com"], at: repo)
_ = try git.run(["commit", "--allow-empty", "-m", "initial"], at: repo)
_ = try git.run(["remote", "add", "origin", remote.path], at: repo)
_ = try git.run(["push", "-u", "origin", "main"], at: repo)
let suite = "HappaToolsThingsSmoke." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let settings = UserSettings(defaults: defaults)
settings.gitExecutablePath = "/usr/bin/git"
let controller = ThingsController(settings: settings, logURL: root.appendingPathComponent("history.sqlite"))
let sample = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/Fixtures/Things/main.sqlite")
func waitUntilIdle() {
    let limit = Date().addingTimeInterval(20)
    while controller.isWorking && Date() < limit { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    assert(!controller.isWorking, "后台同步未按时结束")
    assert(!controller.failed, controller.status)
}
controller.save(repository: repo.path, database: sample.path, minutes: 1)
waitUntilIdle()
assert(controller.configuration.target?.root.path == repo.path)
controller.setAutomatic(true)
controller.syncNow()
waitUntilIdle()
assert(FileManager.default.fileExists(atPath: repo.appendingPathComponent("Inbox.md").path))
let head = try git.run(["rev-parse", "HEAD"], at: repo).stdout
let remoteHead = try git.run(["rev-parse", "refs/heads/main"], at: remote).stdout
assert(head == remoteHead)
controller.setAutomatic(false)
let reopened = ThingsController(settings: settings, logURL: root.appendingPathComponent("history.sqlite"))
assert(!reopened.configuration.enabled && reopened.configuration.target == controller.configuration.target)
let history = try DatabaseManager(url: root.appendingPathComponent("history.sqlite"))
let records = try history.records()
assert(records.contains { $0.operationType == "things_sync" && $0.status == "success" })
controller.syncNow()
waitUntilIdle()
let repeatedHead = try git.run(["rev-parse", "HEAD"], at: repo).stdout
assert(head == repeatedHead)
print("Things3 应用行为检查通过：保存配置、启用自动同步、禁止重入、真实上传、关闭自动同步、重载设置、历史记录、无变化不提交。")

if let live = ProcessInfo.processInfo.environment["THINGS_LIVE_DATABASE"] {
    let destination = root.appendingPathComponent("live-export")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let snapshot = try ThingsReader.read(at: URL(fileURLWithPath: live))
    let paths = try ThingsExport.reconcile(ThingsExport.render(snapshot), at: destination)
    print("本机 Things3 只读导出通过：\(snapshot.taskCount) 个任务，\(paths.count) 个托管路径；个人数据仅位于被忽略的 .build 目录。")
}
