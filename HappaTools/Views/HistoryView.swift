import SwiftUI
import HappaToolsShared

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    let showDetails: Bool
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(showDetails ? "运行日志" : "操作历史").font(.title2).bold()
                Spacer()
                if model.loading { ProgressView().scaleEffect(0.6).frame(width: 20) }
                Button("刷新", action: model.refresh)
                Button("清空日志") { confirmClear = true }
            }
            TextField("搜索路径、提交信息或输出", text: $model.search)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            HStack {
                Picker("类型", selection: $model.operationType) {
                    Text("全部").tag("")
                    Text("提交").tag("git_commit")
                    Text("推送").tag("git_push")
                    Text("README").tag("create_readme")
                }
                Picker("状态", selection: $model.status) {
                    Text("全部").tag("")
                    Text("成功").tag("success")
                    Text("失败").tag("failure")
                }
            }
            HStack {
                Toggle("起始日期", isOn: $model.filterDate)
                DatePicker("", selection: $model.since, displayedComponents: .date)
                    .labelsHidden().disabled(!model.filterDate)
                Spacer()
                Text("最近 100 条 · 保留 30 天").font(.caption).foregroundColor(.secondary)
            }
            if model.records.isEmpty {
                Spacer()
                Text("没有符合条件的记录").foregroundColor(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(model.records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(title(record.operationType), systemImage: record.status == "success" ? "checkmark.circle" : "xmark.circle")
                                .foregroundColor(record.status == "success" ? .green : .red)
                            Spacer()
                            Text(record.timestamp, style: .date)
                            Text(record.timestamp, style: .time)
                        }
                        Text(record.targetPath).font(.caption).foregroundColor(.secondary)
                        if let message = record.commitMessage { Text(message) }
                        if showDetails {
                            if !record.stdout.isEmpty { output("标准输出", record.stdout) }
                            if !record.stderr.isEmpty { output("错误输出", record.stderr) }
                            Button("复制日志") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(record.stdout + "\n" + record.stderr, forType: .string)
                            }.font(.caption)
                        }
                    }.padding(.vertical, 8)
                }
            }
        }.padding(24)
        .onAppear(perform: model.refresh)
        .onChange(of: model.search) { _ in model.refresh() }
        .onChange(of: model.operationType) { _ in model.refresh() }
        .onChange(of: model.status) { _ in model.refresh() }
        .onChange(of: model.filterDate) { _ in model.refresh() }
        .onChange(of: model.since) { _ in model.refresh() }
        .alert(isPresented: $confirmClear) {
            Alert(title: Text("清空全部日志？"), message: Text("此操作会删除所有操作历史和运行日志，无法撤销。"), primaryButton: .destructive(Text("清空"), action: model.clearLogs), secondaryButton: .cancel(Text("取消")))
        }
    }

    private func title(_ type: String) -> String {
        switch type {
        case "git_commit": return "Git 提交"
        case "git_push": return "Git 推送"
        default: return "创建 README"
        }
    }

    private func output(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
