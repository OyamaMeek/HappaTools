import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.finishLaunching()
let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

for replacement in [nil, "修复输入\n保留多行说明"] as [String?] {
    var initialMessage = ""
    let timer = Timer(timeInterval: 0.1, repeats: false) { _ in
        guard let editor = app.modalWindow?.firstResponder as? NSTextView else {
            fatalError("提交框打开后必须聚焦文本编辑器")
        }
        initialMessage = editor.string
        assert(!initialMessage.isEmpty)
        assert(editor.selectedRange() == NSRange(location: 0, length: (initialMessage as NSString).length),
               "默认日期必须全选，直接输入即可替换")
        if let replacement {
            editor.insertText(replacement, replacementRange: editor.selectedRange())
        }
        app.stopModal(withCode: .alertFirstButtonReturn)
    }
    RunLoop.main.add(timer, forMode: .modalPanel)
    let result = OperationPrompt.commitMessage(at: directory)
    assert(result == (replacement ?? initialMessage), "输入必须替换整段日期，并保留多行文字")
}

let cancel = Timer(timeInterval: 0.1, repeats: false) { _ in
    app.stopModal(withCode: .alertSecondButtonReturn)
}
RunLoop.main.add(cancel, forMode: .modalPanel)
assert(OperationPrompt.commitMessage(at: directory) == nil)
print("提交框检查通过：日期全选、直接替换、多行输入、保留默认日期和取消。")
