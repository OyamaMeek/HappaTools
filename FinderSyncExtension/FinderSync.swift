import Cocoa
import FinderSync
import HappaToolsShared

final class FinderSync: FIFinderSync {
    private var isOpening = false
    private var containingAppURL: URL {
        let host = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        #if README_EXTENSION
        return host.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        #else
        return host
        #endif
    }

    private var operationIsRunning: Bool {
        guard UserSettings().operationInProgress,
              let identifier = Bundle(url: containingAppURL)?.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty
    }
    #if README_EXTENSION
    private let isGit = false
    #else
    private let isGit = true
    #endif

    override init() {
        super.init()
        updateMonitoredVolumes()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateMonitoredVolumes), name: NSWorkspace.didMountNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateMonitoredVolumes), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }

    @objc private func updateMonitoredVolumes() {
        let manager = FileManager.default
        var urls = manager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
        urls.append(manager.homeDirectoryForCurrentUser)
        FIFinderSyncController.default().directoryURLs = Set(urls)
    }

    override var toolbarItemName: String { isGit ? "Git" : "README" }
    override var toolbarItemToolTip: String { isGit ? "提交并推送，或创建空白 README.md" : "创建空白 README.md" }
    override var toolbarItemImage: NSImage {
        let image = NSImage(systemSymbolName: isGit ? "arrow.triangle.branch" : "doc.badge.plus", accessibilityDescription: toolbarItemName) ?? NSImage(named: NSImage.actionTemplateName)!
        image.isTemplate = true
        return image
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .toolbarItemMenu else { return nil }
        let settings = UserSettings()
        return MenuBuilder.make(directory: currentDirectory(), isGit: isGit,
                                gitEnabled: settings.showGitButton, readmeEnabled: settings.showReadmeButton,
                                busy: operationIsRunning || isOpening, target: self,
                                gitAction: #selector(runGitOperation(_:)), readmeAction: #selector(runReadmeOperation(_:)))
    }

    private func currentDirectory() -> URL? {
        let target = FIFinderSyncController.default().targetedURL()
        return target?.isFileURL == true ? target : nil
    }

    @objc private func runGitOperation(_ sender: NSMenuItem) { runOperation(.git) }

    @objc private func runReadmeOperation(_ sender: NSMenuItem) { runOperation(.readme) }

    private func runOperation(_ operation: FinderRequest.Operation) {
        let settings = UserSettings()
        guard !isOpening, !operationIsRunning else { return }
        guard operation == .git ? settings.showGitButton : settings.showReadmeButton else { return }
        let request = FinderRequest(operation: operation, directory: currentDirectory())
        isOpening = true
        NSWorkspace.shared.open([request.url], withApplicationAt: containingAppURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isOpening = false
                if let error = error { self?.present(error.localizedDescription, success: false) }
            }
        }
    }

    private func present(_ message: String, success: Bool) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = success ? .informational : .warning
            alert.messageText = success ? "HappaTools" : "操作失败"
            alert.informativeText = message
            alert.addButton(withTitle: "好")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
