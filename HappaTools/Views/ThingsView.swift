import SwiftUI
import AppKit

struct ThingsView: View {
    @ObservedObject var controller: ThingsController
    @State private var repository = ""
    @State private var database = ""
    @State private var minutes = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Things3 自动上传").font(.title2).bold()
                Text("把 Things3 任务导出为 Markdown，并上传到已有 Git 仓库。")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("本地 Git 仓库", text: $repository)
                        Button("选择仓库…") { choose(directory: true) }
                    }
                    HStack {
                        TextField("Things3 main.sqlite（留空自动查找）", text: $database)
                        Button("选择数据库…") { choose(directory: false) }
                    }
                    Picker("同步间隔", selection: $minutes) {
                        ForEach([1, 5, 15, 60], id: \.self) { Text("\($0) 分钟").tag($0) }
                    }.frame(maxWidth: 280)
                    Button("保存配置") { controller.save(repository: repository, database: database, minutes: minutes) }
                }.disabled(controller.isWorking)
                if let target = controller.configuration.target {
                    Text("当前仓库：\(target.root.path)\n分支：\(target.branch) → \(target.remote)/\(target.destination.replacingOccurrences(of: "refs/heads/", with: ""))")
                        .font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                Toggle("自动上传", isOn: Binding(get: { controller.configuration.enabled }, set: controller.setAutomatic))
                HStack {
                    Button("立即同步", action: controller.syncNow)
                        .disabled(controller.isWorking || controller.configuration.target == nil)
                    if controller.isWorking { ProgressView().scaleEffect(0.6).frame(width: 20) }
                }
                Text(controller.status).foregroundColor(controller.failed ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let date = controller.lastSync {
                    HStack { Text("最近检查"); Text(date, style: .date); Text(date, style: .time) }
                        .font(.caption).foregroundColor(.secondary)
                }
                Text("应用运行时定时上传，关闭窗口后继续，退出应用后停止。任务按列表、项目和领域保存；消失的项目或领域移入 Archived。生成文件由应用维护，请将自己的笔记放在其他文件中。")
                    .font(.callout).foregroundColor(.secondary)
                Text("请选择专用的私有备份仓库，并预先设置 Git 上游和免交互认证。推送会包含当前分支已有的待推送提交；分支或远端改变后须重新保存配置。")
                    .font(.callout).foregroundColor(.secondary)
                Text("仅读取 Things3，不会回写任务。重复任务模板和附件不导出，已生成的重复任务会导出。")
                    .font(.caption).foregroundColor(.secondary)
            }.padding(28)
        }.onAppear {
            repository = controller.configuration.target?.root.path ?? ""
            database = controller.configuration.databasePath
            minutes = controller.configuration.minutes
        }
    }

    private func choose(directory: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = directory
        panel.canChooseFiles = !directory
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        panel.prompt = "选择"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if directory { repository = url.path } else { database = url.path }
    }
}
