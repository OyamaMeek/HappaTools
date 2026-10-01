# 开发环境

- 2026-10-01 iTerm2 菜单：仅主代理实施；Swift / AppKit、系统 osascript 和 iTerm2 AppleScript 接口，不增加依赖。验证使用真实 iTerm2、既有 Swift 测试和 AppKit 烟测，不截图。

- 2026-09-29 Things3 功能：主代理在当前 main 实施；参考目录仅用于研究，不打包 Python 运行时。使用 Swift、SQLite3、既有 GitExecutor；验证使用真实 SQLite 样本和本地 bare Git 远端。

- 主代理：工程集成、Finder 扩展、SwiftUI 主应用、交付。
- 共享层子代理：配置、SQLite、Git 工作流及对应测试；独立文件范围。
- Xcode 16.4 / Swift 6.1.2，以 Swift 5 模式构建，最低 macOS 11。
- 原生 Foundation、SwiftUI、AppKit、FinderSync、SQLite3；不引入依赖。
