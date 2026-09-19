import AppKit

enum MenuBuilder {
    static func make(directory: URL?, isGit: Bool, enabled: Bool, busy: Bool, target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let notice = NSMenuItem(title: directory?.path ?? "Finder 未提供当前路径", action: nil, keyEquivalent: "")
        notice.isEnabled = false
        menu.addItem(notice)
        let title: String
        if !enabled { title = "此操作已在 HappaTools 设置中关闭" }
        else if busy { title = "正在处理，请稍候…" }
        else if directory == nil { title = isGit ? "选择文件夹并提交…" : "选择文件夹并创建 README…" }
        else { title = isGit ? "提交并推送…" : "创建空白 README.md" }
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.isEnabled = enabled && !busy
        menu.addItem(item)
        return menu
    }

}
