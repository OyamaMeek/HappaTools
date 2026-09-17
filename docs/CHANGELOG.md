## [2026-09-17 13:17] 实现 FinderGitHelper 菜单栏应用

- **需求/问题描述**：
  > 根据 Claude/Claude.md 完成 macOS Finder 快捷 Git 提交推送、README 创建、设置和反馈功能。

- **实际实现的功能与改动**：
  - [应用与界面]：创建无第三方依赖的 SwiftUI macOS 工程，以 NSStatusItem / NSPopover 保留 macOS 12 支持，提供多行提交、设置窗口、进度动画和完整错误详情。
  - [Finder 与文件]：读取最前方 Finder 窗口、处理无窗口/特殊位置/权限错误，提供权限设置入口；排他创建 README，保护已有文件和符号链接，并请求 Finder 刷新。
  - [Git]：参数数组执行暂存、提交、推送；校验消息和分支、保留完整输出、设置命令超时；推送失败保留本地提交并支持只重试 push。
  - [设置与通知]：UserDefaults 持久化分支和按钮可见性，提供操作通知与菜单状态。
  - [测试/验证]：15 项 XCTest 全部通过，包含真实本地仓库与 bare remote 的端到端验证；Debug 和 Release 双架构构建、本地签名及最低系统版本检查通过。应用已启动并确认菜单真实 Finder 路径。完整 UI 操作、演示录制、干净 macOS 12/13 验证及分发公证未完成，原因详见 docs/VERIFICATION.md。
  - [文档]：补充使用、构建、权限、Git 恢复说明及持续开发记录。

- **涉及文件**：
  - `.gitignore`
  - `FinderGitHelper.xcodeproj/project.pbxproj`
  - `FinderGitHelper.xcodeproj/xcshareddata/xcschemes/FinderGitHelper.xcscheme`
  - `Info.plist`
  - `FinderGitHelper/FinderGitHelper.entitlements`
  - `FinderGitHelper/FinderGitHelperApp.swift`
  - `FinderGitHelper/StatusBarController.swift`
  - `FinderGitHelper/Models/AppSettings.swift`
  - `FinderGitHelper/Models/FinderPathResult.swift`
  - `FinderGitHelper/Services/FinderService.swift`
  - `FinderGitHelper/Services/GitService.swift`
  - `FinderGitHelper/Services/ProcessRunner.swift`
  - `FinderGitHelper/Services/ReadmeService.swift`
  - `FinderGitHelper/Services/NotificationService.swift`
  - `FinderGitHelper/Utilities/DateFormatter+Extensions.swift`
  - `FinderGitHelper/ViewModels/MenuBarViewModel.swift`
  - `FinderGitHelper/ViewModels/SettingsViewModel.swift`
  - `FinderGitHelper/Views/MenuBarContentView.swift`
  - `FinderGitHelper/Views/CommitMessageView.swift`
  - `FinderGitHelper/Views/SettingsView.swift`
  - `FinderGitHelper/Views/ErrorDetailsView.swift`
  - `FinderGitHelper/Assets.xcassets/`（图标及资源清单）
  - `FinderGitHelperTests/FinderGitHelperTests.swift`
  - `scripts/generate-icon.swift`
  - `README.md`
  - `docs/VERIFICATION.md`
  - `docs/CHANGELOG.md`
  - `memory/agents.md`、`memory/plan.md`、`memory/progress.md`、`memory/verify.md`、`memory/gotchas.md`

- **Git 提交**：待提交，验证已通过。

---
