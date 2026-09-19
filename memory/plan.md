# HappaTools Implementation Plan

> 使用 superpowers:subagent-driven-development 分工实施；用户已授权直接在 main 开发并推送。

**Goal:** 根据 `Claude/Claude.md` 建立 macOS 11+ Finder Git / README 工具及主应用。
**Architecture:** SwiftUI 主应用、Git Finder Sync 扩展、独立 README helper app 中的 README Finder Sync 扩展、Foundation / SQLite3 共享模块。每个扩展提供一个工具栏按钮；同一 App Group 保存设置和数据库。主应用非沙盒，两个扩展和 README helper 保持沙盒。
**Tech Stack:** Swift 5、SwiftUI、AppKit、FinderSync、SQLite3；无第三方依赖。
**Spec:** `Claude/Claude.md`

## 全局约束与裁定

- macOS 11.0 起；Git 在后台执行，UI 回到主线程；每条 Git 命令 30 秒超时。
- 非仓库不初始化；无远端跟踪在暂存/提交前失败；README 必须为空且不得覆盖现有文件。
- 只对当前检出分支提交和推送；默认分支用于空配置展示，不允许向无关分支提交后错误推送。
- 使用原生 SQLite3，需求同时允许 raw C API，无需引入 GRDB。
- Finder Sync 每个扩展仅一个按钮，因此使用 Git extension 和 README extension 两个 target；README extension 通过独立 helper app 嵌入，扩展开关可分别显示。空 directoryURLs 表示不监控，改为卷根目录监控。
- 完整磁盘访问无法通过读取普通 home 文件可靠判断，展示未知/受保护路径探测结果与授权指引，不假报已授权。
- 签名配置可供真实 Developer ID 使用；本机无该证书，禁止声称公证成功。

## Task 1: 共享基础设施

- [x] 在 Tests/HappaToolsSharedTests 编写并运行失败测试，覆盖设置持久化、数据库插入/清理/跨连接读取、Git 校验/本地远端提交推送/失败、README 不覆盖。
- [x] 实现 Shared 下的配置、数据库和 Git 代码以及 Package.swift，使用原生 SQLite3，无第三方依赖。
- [x] 运行 `swift test --scratch-path .build/core`，记录结果；共享层实现已包含在此前的共享提交中。

## Task 2: Finder 与主应用

- [x] 实现 FinderSyncExtension/FinderSync.swift、MenuBuilder.swift、GitOperationHandler.swift；标准菜单打开多行提交框、时间戳、禁用与结果提醒。Finder 不支持跨进程传递自定义菜单视图，修正原文该错误前提。
- [x] 实现 HappaTools/App/HappaToolsApp.swift、AppModel.swift 与四个视图，设置四项、扩展状态、历史和日志搜索/类型/状态/日期过滤及确认清理。
- [x] 建立 HappaTools.xcodeproj，包含 Shared framework、主应用、两个扩展和测试 target。
- [x] 运行 xcodebuild build/test；修复编译与实际行为问题，提交应用单元。Debug scheme 测试通过，Release 构建和临时签名通过。

## Task 3: 分发与交付

- [x] 编写构建/打包/签名公证脚本、使用与权限说明、演示步骤；产出可构建应用与本地 DMG。
- [x] 独立审查改动，运行真实 Git 回归测试、主应用启动检查，记录尚依赖 Finder 系统授权的检查。
- [ ] 更新 docs/CHANGELOG.md 和验证记录，完成原子提交与普通 git push；实现提交和文档提交仍待本轮完成。
