import AppKit

final class Receiver: NSObject {
    @objc func runGitOperation(_ sender: NSMenuItem) {}
    @objc func runReadmeOperation(_ sender: NSMenuItem) {}
}

let receiver = Receiver()
let directory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
let gitAction = #selector(Receiver.runGitOperation(_:))
let readmeAction = #selector(Receiver.runReadmeOperation(_:))
for isGit in [true, false] {
    for directory in [directory, nil] as [URL?] {
        for gitEnabled in [true, false] {
            for readmeEnabled in [true, false] {
                for busy in [true, false] {
                    let menu = MenuBuilder.make(directory: directory, isGit: isGit,
                                                gitEnabled: gitEnabled, readmeEnabled: readmeEnabled,
                                                busy: busy, target: receiver, gitAction: gitAction, readmeAction: readmeAction)
                    assert(!menu.items[0].isEnabled)
                    let actions = Array(menu.items.dropFirst())
                    assert(actions.map(\.action) == (isGit ? [gitAction, readmeAction] : [readmeAction]),
                           "Git 菜单必须按提交、README 顺序提供独立动作")
                    assert(actions.allSatisfy { $0.target === receiver && $0.view == nil })
                    assert(actions.last!.isEnabled == (readmeEnabled && !busy))
                    if isGit { assert(actions[0].isEnabled == (gitEnabled && !busy)) }
                    if directory == nil { assert(actions.allSatisfy { $0.title.contains("选择文件夹") }) }
                }
            }
        }
    }
}
print("Finder 菜单检查通过：README 顺序与独立动作、独立开关、忙碌、无路径，共 32 种状态。")
