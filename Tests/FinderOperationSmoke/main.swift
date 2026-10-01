import AppKit
import HappaToolsShared

let app = NSApplication.shared
let model = AppModel()
app.delegate = model
app.setActivationPolicy(.regular)

func check() throws {
    model.refreshStatus()
    assert(model.accessStatus == "请在系统设置确认完整磁盘访问权限；操作受保护目录时由 macOS 请求授权。",
           "概览检查必须直接说明授权方式，不探测无关 App 的数据目录")
    assert(app.activationPolicy() == .accessory, "没有窗口时必须隐藏 Dock 图标")
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    app.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    app.updateWindows()
    assert(app.activationPolicy() == .regular, "显示窗口时必须显示 Dock 图标")
    let secondWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    secondWindow.isReleasedWhenClosed = false
    secondWindow.makeKeyAndOrderFront(nil)
    window.close()
    assert(app.activationPolicy() == .regular, "仍有窗口时必须保留 Dock 图标")
    secondWindow.miniaturize(nil)
    app.updateWindows()
    assert(app.activationPolicy() == .regular, "最小化时必须保留 Dock 图标")
    secondWindow.deminiaturize(nil)
    secondWindow.close()
    assert(app.activationPolicy() == .accessory, "最后一个窗口关闭后必须隐藏 Dock 图标")
    assert(app.delegate?.applicationShouldTerminateAfterLastWindowClosed?(app) == false,
           "关闭窗口必须保留后台运行")
    var backgroundTick = false
    DispatchQueue.main.async { backgroundTick = true }
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    assert(backgroundTick, "窗口关闭后后台主循环必须继续运行")
    window.makeKeyAndOrderFront(nil)
    app.updateWindows()
    assert(app.activationPolicy() == .regular, "重新打开窗口必须恢复 Dock 图标")
    window.close()
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent(".build", isDirectory: true)
        .appendingPathComponent("HappaTools-FinderSmoke-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let initialize = Process()
    initialize.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    initialize.arguments = ["init", "--quiet", directory.path]
    try initialize.run()
    initialize.waitUntilExit()
    assert(initialize.terminationStatus == 0, "烟测必须使用独立无上游仓库")

    model.settings.operationInProgress = false
    app.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    var readmeAlertCount = 0
    let readmeResponse = Timer(timeInterval: 0.1, repeats: true) { _ in
        guard app.modalWindow != nil else { return }
        readmeAlertCount += 1
        app.stopModal(withCode: .alertFirstButtonReturn)
    }
    RunLoop.main.add(readmeResponse, forMode: .modalPanel)
    model.handle(FinderRequest(operation: .readme, directory: directory).url)
    let readmeDeadline = Date().addingTimeInterval(5)
    while window.isVisible && Date() < readmeDeadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    readmeResponse.invalidate()
    assert(readmeAlertCount == 0, "README 创建前和成功后都不应显示弹窗")
    assert(!window.isVisible, "README 成功后必须关闭主窗口并返回 Finder")
    assert(!model.operationRunning && !model.settings.operationInProgress)
    let readme = directory.appendingPathComponent("README.md")
    let createdContent = try Data(contentsOf: readme)
    assert(createdContent.isEmpty, "必须实际创建空 README.md")
    try Data("保留已有内容".utf8).write(to: readme)

    for (operation, confirm, target) in [(FinderRequest.Operation.git, false, directory),
                                        (.git, true, directory),
                                        (.readme, true, directory),
                                        (.readme, false, directory.appendingPathComponent("missing")),
                                        (.iterm, false, directory.appendingPathComponent("missing"))] {
        app.unhide(nil)
        window.makeKeyAndOrderFront(nil)
        var dismissed = false
        var alertCount = 0
        let expectedAlerts = operation == .git && confirm ? 2 : 1
        let response = Timer(timeInterval: 0.1, repeats: true) { _ in
            guard app.modalWindow != nil else { return }
            alertCount += 1
            if target == directory && (operation == .readme || alertCount == 2) {
                assert(model.operationRunning && model.settings.operationInProgress,
                       "结果弹窗关闭前必须阻止重复操作")
            }
            app.stopModal(withCode: confirm ? .alertFirstButtonReturn : .alertSecondButtonReturn)
            dismissed = alertCount == expectedAlerts
        }
        RunLoop.main.add(response, forMode: .modalPanel)
        model.handle(FinderRequest(operation: operation, directory: target).url)
        let deadline = Date().addingTimeInterval(5)
        while !dismissed && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        response.invalidate()
        assert(dismissed && alertCount == expectedAlerts, "Git 保留确认框，失败仅显示结果提示")
        assert(!window.isVisible, "Finder 操作结束后必须关闭 HappaTools 主窗口")
        assert(!model.operationRunning && !model.settings.operationInProgress)
        assert(app.activationPolicy() == .accessory, "操作结束且窗口关闭后必须隐藏 Dock 图标")
        if operation == .readme && confirm {
            let content = try String(contentsOf: readme, encoding: .utf8)
            assert(content == "保留已有内容", "重复创建不得覆盖已有 README")
        }
    }
    print("Finder 操作检查通过：窗口显示/关闭/重开、多窗口与最小化 Dock 行为、关闭后后台运行、README 零弹窗及内容保护、Git 取消/失败、无效目录与结果防重入。")
}

Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
    do {
        try check()
        exit(0)
    } catch {
        fatalError(error.localizedDescription)
    }
}
app.run()
