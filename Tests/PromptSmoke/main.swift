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
        editor.moveToEndOfDocument(nil)
        assert(editor.selectedRange().length == 0, "结束选择后必须有插入位置")
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            editor.appearance = NSAppearance(named: appearance)!
            editor.effectiveAppearance.performAsCurrentDrawingAppearance {
                let cursor = editor.insertionPointColor.usingColorSpace(.genericGray)!.whiteComponent
                let background = editor.backgroundColor.usingColorSpace(.genericGray)!.whiteComponent
                assert(abs(cursor - background) >= 0.5,
                       "\(appearance.rawValue) 下光标必须清晰：光标亮度 \(cursor)，背景亮度 \(background)")
            }
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
print("提交框检查通过：日期全选、直接替换、多行输入、保留默认日期、取消和深浅色光标对比。")
