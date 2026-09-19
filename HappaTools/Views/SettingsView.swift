import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var branch = ""
    @State private var gitPath = ""
    @State private var showGit = true
    @State private var showReadme = true
    @State private var hideFromDock = false
    @State private var saved = false
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置").font(.title2).bold()
            Form {
                TextField("默认分支", text: $branch)
                TextField("Git 可执行文件", text: $gitPath)
                Toggle("启用 Git 按钮操作", isOn: $showGit)
                Toggle("启用 README 按钮操作", isOn: $showReadme)
                Toggle("在 Dock 中隐藏应用", isOn: $hideFromDock)
            }
            Text("已有仓库始终使用当前检出的分支及其上游，不会自动切换分支。Finder 工具栏按钮的显示/隐藏由“自定工具栏”管理；关闭设置后对应操作会禁用。")
                .font(.callout).foregroundColor(.secondary)
            Text("隐藏 Dock 图标后，仍可从“应用程序”打开 HappaTools 调整设置。")
                .font(.callout).foregroundColor(.secondary)
            HStack {
                Button("保存设置") { save() }.keyboardShortcut("s", modifiers: .command)
                if saved { Label("已保存", systemImage: "checkmark.circle").foregroundColor(.secondary) }
            }
            if let error = validationError { Text(error).foregroundColor(.red).font(.callout) }
            Spacer()
        }
        .onAppear {
            branch = model.settings.defaultBranch
            gitPath = model.settings.gitExecutablePath
            showGit = model.settings.showGitButton
            showReadme = model.settings.showReadmeButton
            hideFromDock = model.settings.hideFromDock
        }
        .onChange(of: branch) { _ in saved = false }
        .onChange(of: gitPath) { _ in saved = false }
        .onChange(of: showGit) { _ in saved = false }
        .onChange(of: showReadme) { _ in saved = false }
        .onChange(of: hideFromDock) { _ in saved = false }
    }

    private func save() {
        let branch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = gitPath.trimmingCharacters(in: .whitespacesAndNewlines)
        validationError = nil
        guard !branch.isEmpty else { validationError = "默认分支不能为空。"; return }
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            validationError = "请选择有效的 Git 可执行文件绝对路径。"
            return
        }
        model.settings.defaultBranch = branch
        model.settings.gitExecutablePath = path
        model.settings.showGitButton = showGit
        model.settings.showReadmeButton = showReadme
        model.settings.hideFromDock = hideFromDock
        model.applyDockVisibility()
        saved = true
    }
}
