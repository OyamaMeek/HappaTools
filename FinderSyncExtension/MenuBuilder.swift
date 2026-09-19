import AppKit

enum MenuBuilder {
    static func make(directory: URL?, isGit: Bool, gitEnabled: Bool, readmeEnabled: Bool, busy: Bool,
                     target: AnyObject, gitAction: Selector, readmeAction: Selector) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let notice = NSMenuItem(title: directory?.path ?? "Finder 未提供当前路径", action: nil, keyEquivalent: "")
        notice.isEnabled = false
        menu.addItem(notice)
        let operations = isGit ? [true, false] : [false]
        for git in operations {
            let enabled = git ? gitEnabled : readmeEnabled
            var title = directory == nil
                ? (git ? "选择文件夹并提交…" : "选择文件夹并创建 README…")
                : (git ? "提交并推送…" : "创建空白 README.md")
            if !enabled { title += "（已关闭）" }
            else if busy { title += "（正在处理…）" }
            let item = NSMenuItem(title: title, action: git ? gitAction : readmeAction, keyEquivalent: "")
            item.target = target
            item.isEnabled = enabled && !busy
            menu.addItem(item)
        }
        return menu
    }
}
