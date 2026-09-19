import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection = "概览"
    private let pages = [("概览", "square.grid.2x2"), ("设置", "gearshape"), ("操作历史", "clock"), ("日志", "text.alignleft")]

    var body: some View {
        NavigationView {
            List {
                ForEach(pages, id: \.0) { page in
                    Button { selection = page.0 } label: {
                        Label(page.0, systemImage: page.1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(selection == page.0 ? Color.accentColor.opacity(0.16) : Color.clear)
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 160, idealWidth: 180)
            Group {
                switch selection {
                case "设置": SettingsView().padding(28)
                case "操作历史": HistoryView(showDetails: false)
                case "日志": HistoryView(showDetails: true)
                default: OverviewView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("HappaTools · \(selection)")
        .overlay(Group {
            if model.operationRunning {
                HStack { ProgressView().scaleEffect(0.6); Text("正在执行，请稍候…") }
                    .padding(12).background(Color(NSColor.windowBackgroundColor))
            }
        }, alignment: .bottom)
        .sheet(isPresented: $model.showOnboarding) {
            VStack(alignment: .leading, spacing: 18) {
                Text("让 Finder 准备就绪").font(.title2).bold()
                Text("1. 在系统设置的文件提供程序中启用 HappaTools。")
                Text("2. 在 Finder 的“自定工具栏”中拖入 Git 按钮，菜单提供提交与创建 README 两项操作。")
                Text("3. 如需处理受保护目录，请为 HappaTools 授予完整磁盘访问权限。Git 和文件操作由主应用执行。")
                Text("Git 操作会暂存当前仓库的全部更改，提交后推送到当前分支配置的上游。请预先配置身份、远端和免交互认证。")
                    .foregroundColor(.secondary)
                HStack {
                    Button("打开隐私设置", action: model.openPrivacySettings)
                    Spacer()
                    Button("我知道了", action: model.finishOnboarding).keyboardShortcut(.defaultAction)
                }
            }.padding(28).frame(width: 530)
        }
        .alert(isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Alert(title: Text("操作失败"), message: Text(model.errorMessage ?? ""), dismissButton: .default(Text("好")))
        }
    }
}
