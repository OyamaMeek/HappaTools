import AppKit

final class Receiver: NSObject {
    @objc func runOperation(_ sender: NSMenuItem) {}
}

let receiver = Receiver()
let directory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
let selector = #selector(Receiver.runOperation(_:))
for isGit in [true, false] {
    let menu = MenuBuilder.make(directory: directory, isGit: isGit, enabled: true, busy: false, target: receiver, action: selector)
    let action = menu.items.last!
    assert(action.action == selector && action.target === receiver && action.isEnabled)
    assert(action.view == nil, "Finder 菜单必须使用可跨进程传递的标准菜单项")
    let busy = MenuBuilder.make(directory: directory, isGit: isGit, enabled: true, busy: true, target: receiver, action: selector)
    assert(busy.items.allSatisfy { !$0.isEnabled })
    let disabled = MenuBuilder.make(directory: directory, isGit: isGit, enabled: false, busy: false, target: receiver, action: selector)
    assert(disabled.items.allSatisfy { !$0.isEnabled })
    let missing = MenuBuilder.make(directory: nil, isGit: isGit, enabled: true, busy: false, target: receiver, action: selector)
    assert(missing.items.last!.isEnabled && missing.items.last!.title.contains("选择文件夹"))
}
print("Finder 菜单契约检查通过：Git、README、忙碌、关闭、无路径。")
