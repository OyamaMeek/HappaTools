import AppKit
import Combine
import FinderSync
import HappaToolsShared

final class AppModel: NSObject, ObservableObject, NSApplicationDelegate {
    let settings = UserSettings()
    @Published var records: [OperationRecord] = []
    @Published var errorMessage: String?
    @Published var extensionEnabled = false
    @Published var accessStatus = "尚未检查"
    @Published var showOnboarding = false
    @Published var search = ""
    @Published var operationType = ""
    @Published var status = ""
    @Published var filterDate = false
    @Published var since = Calendar.current.startOfDay(for: Date())
    @Published var loading = false
    private let queue = DispatchQueue(label: "com.happatools.history", qos: .userInitiated)
    private var database: DatabaseManager?
    private var timer: AnyCancellable?
    private var started = false
    private var requestID = 0
    private let operationHandler = GitOperationHandler()
    private var isChoosing = false
    @Published var operationRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockVisibility()
    }

    func start() {
        guard !started else { return }
        started = true
        applyDockVisibility()
        settings.operationInProgress = false
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HappaTools README.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: helper, configuration: configuration) { _, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "无法注册 README 扩展：\(error.localizedDescription)" }
            }
        }
        showOnboarding = !settings.onboardingCompleted
        refreshStatus()
        queue.async {
            do {
                let database = try DatabaseManager(url: AppGroupConfig.databaseURL())
                try database.cleanupOldLogs(olderThan: Date().addingTimeInterval(-30 * 86_400))
                self.database = database
                DispatchQueue.main.async { self.refresh() }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
        timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.refresh()
            self?.extensionEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }

    func applyDockVisibility() {
        NSApp.setActivationPolicy(settings.hideFromDock ? .accessory : .regular)
    }

    func refresh() {
        requestID += 1
        let request = requestID
        let search = search
        let type = operationType.isEmpty ? nil : operationType
        let status = status.isEmpty ? nil : status
        let date = filterDate ? since : nil
        loading = true
        queue.async {
            do {
                guard let database = self.database else {
                    DispatchQueue.main.async { self.loading = false }
                    return
                }
                let records = try database.records(search: search, operationType: type, status: status, since: date)
                DispatchQueue.main.async {
                    guard request == self.requestID else { return }
                    self.records = records
                    self.loading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.loading = false
                }
            }
        }
    }

    func clearLogs() {
        queue.async {
            do {
                guard let database = self.database else { return }
                try database.clearAllLogs()
                DispatchQueue.main.async { self.refresh() }
            } catch {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func finishOnboarding() {
        settings.onboardingCompleted = true
        showOnboarding = false
    }

    func refreshStatus() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        queue.async {
            let protectedDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
            let status: String
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: protectedDirectory.path)
                status = "Mail 目录可读取；请在系统设置确认完整磁盘访问权限"
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoPermissionError {
                    status = "受保护目录访问被拒绝，请授予完整磁盘访问权限"
                } else {
                    status = "无法自动确认，请在系统设置检查完整磁盘访问权限"
                }
            }
            DispatchQueue.main.async { self.accessStatus = status }
        }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        if !NSWorkspace.shared.open(url) { errorMessage = "无法打开系统设置，请手动前往隐私与安全性 → 完整磁盘访问权限。" }
    }

    func handle(_ url: URL) {
        guard !operationRunning, !operationHandler.isWorking, !isChoosing else { return }
        applyDockVisibility()
        isChoosing = true
        showOnboarding = false
        DispatchQueue.main.async {
            defer { self.isChoosing = false }
            let request: FinderRequest
            do {
                request = try FinderRequest(url: url)
            } catch {
                self.presentFinderResult(error.localizedDescription, failed: true)
                return
            }
            guard request.operation == .git ? self.settings.showGitButton : self.settings.showReadmeButton else {
                self.presentFinderResult("此操作已在设置中关闭。", failed: true)
                return
            }
            guard let directory = request.directory ?? OperationPrompt.chooseDirectory() else {
                self.returnToFinder()
                return
            }
            do {
                guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
                    self.presentFinderResult("请选择一个实际文件夹。", failed: true)
                    return
                }
            } catch {
                self.presentFinderResult(error.localizedDescription, failed: true)
                return
            }
            let message: String?
            if request.operation == .git {
                guard let input = OperationPrompt.commitMessage(at: directory) else {
                    self.returnToFinder()
                    return
                }
                message = input
            } else {
                guard OperationPrompt.confirmReadme(at: directory) else {
                    self.returnToFinder()
                    return
                }
                message = nil
            }
            self.operationRunning = true
            self.settings.operationInProgress = true
            self.operationHandler.perform(at: directory, message: message) { result in
                self.refresh()
                switch result {
                case .success(let file):
                    self.presentFinderResult(file == nil ? "Git 提交与推送已完成。" : "已创建 README.md。")
                case .failure(let error):
                    self.presentFinderResult(error.localizedDescription, failed: true)
                }
                self.operationRunning = false
                self.settings.operationInProgress = false
            }
        }
    }

    private func presentFinderResult(_ message: String, failed: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = failed ? .warning : .informational
        alert.messageText = failed ? "操作失败" : "操作完成"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        returnToFinder()
    }

    private func returnToFinder() {
        for window in NSApp.windows where window.isVisible { window.close() }
        applyDockVisibility()
        // Activate Finder without opening a URL, preserving its current folder and window order.
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
            .first?.activate(options: [])
        NSApp.hide(nil)
    }
}
