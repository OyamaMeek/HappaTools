import AppKit
import HappaToolsShared

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let model = AppModel()
app.delegate = model
app.finishLaunching()
assert(app.activationPolicy() == (model.settings.hideFromDock ? .accessory : .regular),
       "启动完成后必须应用保存的 Dock 设置")
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                      styleMask: [.titled, .closable], backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("HappaTools-FinderSmoke-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

// Missing cancellation/completion cleanup must leave a visible window and fail this check.
for (operation, confirm, target) in [(FinderRequest.Operation.readme, false, directory),
                                    (.git, false, directory), (.readme, true, directory),
                                    (.git, true, directory),
                                    (.readme, false, directory.appendingPathComponent("missing"))] {
    app.unhide(nil)
    window.makeKeyAndOrderFront(nil)
    var dismissed = false
    var alertCount = 0
    let response = Timer(timeInterval: 0.1, repeats: true) { _ in
        guard app.modalWindow != nil else { return }
        alertCount += 1
        if alertCount == 2 {
            assert(model.operationRunning && model.settings.operationInProgress,
                   "结果弹窗关闭前必须阻止重复操作")
        }
        app.stopModal(withCode: confirm ? .alertFirstButtonReturn : .alertSecondButtonReturn)
        dismissed = !confirm || alertCount == 2
    }
    RunLoop.main.add(response, forMode: .modalPanel)
    model.handle(FinderRequest(operation: operation, directory: target).url)
    let deadline = Date().addingTimeInterval(5)
    while !dismissed && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    response.invalidate()
    assert(dismissed, "必须显示操作确认框")
    assert(!window.isVisible, "Finder 操作结束后必须关闭 HappaTools 主窗口")
    assert(!model.operationRunning && !model.settings.operationInProgress)
    assert(app.activationPolicy() == (model.settings.hideFromDock ? .accessory : .regular),
           "操作结束后必须保持保存的 Dock 显示设置")
    if operation == .readme && confirm {
        assert(FileManager.default.fileExists(atPath: directory.appendingPathComponent("README.md").path),
               "必须验证真实 README 创建成功后的收尾")
    }
}
print("Finder 操作检查通过：启动 Dock 设置、Git / README 取消、README 成功、Git 失败、目录失效及结果弹窗防重入。")
