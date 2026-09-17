# 当前进度

- [x] 阅读完整需求和项目约定，核实工具链。
- [x] 识别 macOS API 兼容性及 Git 仓库缺失。
- [x] Xcode 工程与测试。
- [x] 服务和模型。
- [x] SwiftUI 菜单、提交、设置和通知。
- [x] 服务测试、Debug / Release 构建与启动验证。
- [x] README、开发日志、交付记录。
- [ ] Git 提交和推送：已检测到 `origin/main`，待完成验证。

## 验证进展

- 15 项 XCTest 全部通过；真实 Git 工作区和本地 bare remote 完成提交、推送及恢复验证。
- 测试使用 GIT_CEILING_DIRECTORIES 隔离父项目仓库。
- Debug / Release 构建通过；Release 包含 arm64 和 x86_64，最低版本均为 macOS 12。
- Debug / Release 本地签名校验通过。
- 应用已运行，真实菜单显示 Finder 路径及操作按钮；后续 UI 自动化出现 timeoutReached，进程采样未观察到主线程阻塞。
- 完整 UI 操作、演示截图/视频、干净 macOS 12/13 验证、Developer ID 公证尚未完成，详见 docs/VERIFICATION.md。
- 命令行构建需沙箱外访问 Xcode 系统缓存，已通过自动审批。
