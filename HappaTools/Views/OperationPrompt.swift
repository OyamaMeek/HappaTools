import AppKit

enum OperationPrompt {
    static func chooseDirectory() -> URL? {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "选择文件夹"
        NSApp.activate(ignoringOtherApps: true)
        return picker.runModal() == .OK ? picker.url : nil
    }

    static func confirmReadme(at directory: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "创建 README.md"
        alert.informativeText = directory.path + "\n已有文件会保留原样。"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func commitMessage(at directory: URL) -> String? {
        let alert = NSAlert()
        alert.messageText = "提交并推送"
        alert.informativeText = "\(directory.path)\n将暂存整个仓库的全部更改，提交后推送到当前分支的上游。"
        alert.addButton(withTitle: "提交并推送")
        alert.addButton(withTitle: "取消")
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 120))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        editor.string = formatter.string(from: Date())
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.font = .systemFont(ofSize: 13)
        editor.textContainerInset = NSSize(width: 6, height: 8)
        editor.setAccessibilityLabel("Git 提交说明，支持多行")
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(frame: editor.frame)
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = editor
        alert.accessoryView = scroll
        alert.window.initialFirstResponder = editor
        editor.selectAll(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return editor.string
    }
}
