import Foundation
import Combine
import HappaToolsShared

struct ThingsConfiguration: Codable {
    var enabled = false
    var databasePath = ""
    var minutes = 5
    var target: ThingsSyncTarget?
}

final class ThingsController: ObservableObject {
    @Published private(set) var configuration = ThingsConfiguration()
    @Published private(set) var isWorking = false
    @Published private(set) var status = "尚未配置"
    @Published private(set) var failed = false
    @Published private(set) var lastSync: Date?
    var onIdle: (() -> Void)?
    private let settings: UserSettings
    private let logURL: URL?
    private let queue = DispatchQueue(label: "com.happatools.things3", qos: .utility)
    private var timer: Timer?
    private var stopping = false

    init(settings: UserSettings, logURL: URL? = nil) {
        self.settings = settings
        self.logURL = logURL
        do {
            if let data = settings.thingsConfigurationData {
                let saved = try JSONDecoder().decode(ThingsConfiguration.self, from: data)
                guard [1, 5, 15, 60].contains(saved.minutes) else { throw ThingsFailure("同步间隔无效，请重新保存配置。") }
                configuration = saved
                status = saved.target == nil ? "尚未配置" : "等待同步"
            }
        } catch {
            failed = true
            status = "读取 Things3 配置失败：\(error.localizedDescription)"
        }
    }

    func start() {
        timer?.invalidate()
        timer = nil
        guard configuration.enabled, !stopping else { return }
        let timer = Timer(timeInterval: Double(configuration.minutes * 60), repeats: true) { [weak self] _ in self?.syncNow() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        syncNow()
    }

    func stop() {
        stopping = true
        timer?.invalidate()
        timer = nil
    }

    func setAutomatic(_ enabled: Bool) {
        guard !enabled || configuration.target != nil else {
            failed = true
            status = "请先选择仓库并保存配置。"
            return
        }
        var saved = configuration
        saved.enabled = enabled
        do {
            try persist(saved)
            start()
        } catch {
            failed = true
            status = error.localizedDescription
        }
    }

    func save(repository: String, database: String, minutes: Int) {
        guard !isWorking, !stopping else { return }
        guard repository.hasPrefix("/"), [1, 5, 15, 60].contains(minutes), database.isEmpty || database.hasPrefix("/") else {
            failed = true
            status = "请选择仓库和数据库的绝对路径，以及有效同步间隔。"
            return
        }
        isWorking = true
        status = "正在检查仓库和数据库…"
        let executable = URL(fileURLWithPath: settings.gitExecutablePath)
        queue.async {
            let result: Result<ThingsConfiguration, Error>
            do {
                let db = try database.isEmpty ? ThingsReader.discover() : URL(fileURLWithPath: database)
                let target = try ThingsSyncTarget.capture(at: URL(fileURLWithPath: repository), executor: GitExecutor(executableURL: executable))
                _ = try ThingsReader.read(at: db)
                result = .success(ThingsConfiguration(databasePath: db.path, minutes: minutes, target: target))
            } catch { result = .failure(error) }
            DispatchQueue.main.async {
                do {
                    var saved = try result.get()
                    saved.enabled = self.configuration.enabled
                    try self.persist(saved)
                    self.failed = false
                    self.status = "配置已保存"
                } catch {
                    self.failed = true
                    self.status = error.localizedDescription
                }
                self.isWorking = false
                if !self.failed { self.start() }
                self.notifyIdle()
            }
        }
    }

    func syncNow() {
        guard !isWorking, !stopping else { return }
        guard let target = configuration.target, !configuration.databasePath.isEmpty else {
            failed = true
            status = "请先选择仓库并保存配置。"
            return
        }
        isWorking = true
        status = "正在导出并上传 Things3…"
        let database = URL(fileURLWithPath: configuration.databasePath)
        let executable = URL(fileURLWithPath: settings.gitExecutablePath)
        let logURL = logURL
        queue.async {
            var message: String
            var failed = false
            do {
                let result = try ThingsSync(executor: GitExecutor(executableURL: executable)).run(database: database, target: target)
                message = "已检查 \(result.taskCount) 个任务；" + (result.pushed ? "已上传到远端。" : "没有待上传的更改。")
            } catch {
                failed = true
                message = error.localizedDescription
            }
            do {
                let history = try DatabaseManager(url: logURL ?? AppGroupConfig.databaseURL())
                try history.cleanupOldLogs(olderThan: Date().addingTimeInterval(-30 * 86_400))
                try history.insertLog(OperationRecord(operationType: "things_sync", targetPath: target.root.path,
                                                     stdout: failed ? "" : message, stderr: failed ? message : "",
                                                     status: failed ? "failure" : "success"))
            } catch {
                message += " 日志保存失败：\(error.localizedDescription)"
                failed = true
            }
            let finalMessage = message
            let finalFailed = failed
            DispatchQueue.main.async {
                self.isWorking = false
                self.status = finalMessage
                self.failed = finalFailed
                self.lastSync = Date()
                self.notifyIdle()
            }
        }
    }

    private func persist(_ saved: ThingsConfiguration) throws {
        settings.thingsConfigurationData = try JSONEncoder().encode(saved)
        configuration = saved
    }

    private func notifyIdle() {
        guard !isWorking, let callback = onIdle else { return }
        onIdle = nil
        callback()
    }
}
