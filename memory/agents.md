# 开发环境

- 2026-10-01 README 无弹窗创建：仅主代理；复用 Swift / AppKit 和既有 FinderOperationSmoke、PromptSmoke、共享测试，无新增依赖；测试产物放在 .build，不截图。

- 2026-10-01 光标持续显示排查：仅主代理；AppKit 原生窗口、现有 PromptSmoke 和 Apple 文档，测试产物放在忽略的 .build；未授权截图，不进行视觉检查。

- 2026-10-01 权限弹窗：仅主代理；系统 log 和 codesign 定位，复用本机 Apple Development 身份签名，不导出私钥、不改 TCC 数据库；既有 AppKit 与跨构建签名烟测验证。

- 2026-10-01 iTerm2 菜单：仅主代理实施；Swift / AppKit、系统 osascript 和 iTerm2 AppleScript 接口，不增加依赖。验证使用真实 iTerm2、既有 Swift 测试和 AppKit 烟测，不截图。

- 2026-09-29 Things3 功能：主代理在当前 main 实施；参考目录仅用于研究，不打包 Python 运行时。使用 Swift、SQLite3、既有 GitExecutor；验证使用真实 SQLite 样本和本地 bare Git 远端。

- 主代理：工程集成、Finder 扩展、SwiftUI 主应用、交付。
- 共享层子代理：配置、SQLite、Git 工作流及对应测试；独立文件范围。
- Xcode 16.4 / Swift 6.1.2，以 Swift 5 模式构建，最低 macOS 11。
- 原生 Foundation、SwiftUI、AppKit、FinderSync、SQLite3；不引入依赖。
