# 实现计划

1. 建立 Xcode macOS 应用、共享 scheme 和 XCTest target；先添加服务行为检查。
2. 实现设置持久化、Finder AppleScript、Git 操作与超时、README 排他创建。
3. 实现 SwiftUI 菜单、提交输入、设置、错误详情、通知和失败后的单独推送重试。
4. 执行服务测试、真实临时 Git 仓库端到端测试、Debug / Release 构建与本机启动验证。
5. 编写使用说明、验证记录和开发日志。

## 已知约束

- `MenuBarExtra` 最低 macOS 13；统一使用 NSStatusItem / NSPopover 承载 SwiftUI，保留 SwiftUI App 生命周期及 macOS 12 支持，不使用 AppDelegate。
- `.symbolEffect` 和独立 `Window` scene 同样不能覆盖 macOS 12；采用 NSProgressIndicator 和原生设置窗口。
- Git 提交包含仓库中已暂存的内容，界面明确说明；校验当前分支与设置一致，避免推送另一分支。
- 通过参数数组传递路径、分支和提交信息，输出写入临时文件避免管道写满导致挂起；超时结束 Git 进程。
- README 使用排他创建，保证已有文件不被覆盖。
- 开发中已检测到用户配置的 `.git`、`main` 分支和 `origin`（`https://github.com/OyamaMeek/HappaTools.git`）；按既有授权在验证后提交、普通推送。
