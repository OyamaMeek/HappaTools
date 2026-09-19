import SwiftUI
import FinderSync

struct OverviewView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("HappaTools", systemImage: "leaf.fill").font(.largeTitle)
                Text("在 Finder 中提交与推送 Git 更改，或创建空白 README.md。")
                    .font(.title3).foregroundColor(.secondary)
                Divider()
                Label(model.extensionEnabled ? "Git 扩展已启用" : "Git 扩展尚未启用", systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle")
                Text("在系统设置 → 通用 → 登录项与扩展 → 文件提供程序中启用 HappaTools 和 HappaTools README，再通过 Finder → 显示 → 自定工具栏添加两个按钮。README 状态请在系统设置中单独确认。")
                    .foregroundColor(.secondary)
                Button("管理 Finder 扩展") { FIFinderSyncController.showExtensionManagementInterface() }
                Divider()
                Text("目录访问").font(.headline)
                Text(model.accessStatus).foregroundColor(.secondary)
                HStack {
                    Button("打开完整磁盘访问设置", action: model.openPrivacySettings)
                    Button("重新检查", action: model.refreshStatus)
                }
                Divider()
                Text("使用前准备").font(.headline)
                Text("在终端配置 Git 用户名、邮箱和当前分支的上游。SSH 密钥或凭据必须允许后台 Git 使用；本应用不会弹出终端密码提示。")
                Text("操作失败时可在“日志”查看原因。推送失败会保留本地提交；修复网络或认证后再次执行即可推送。已有 README.md 会保留原样。")
                    .foregroundColor(.secondary)
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
