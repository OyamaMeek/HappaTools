# HappaTools

macOS Finder 工具：提交并推送 Git 更改、创建 `README.md`，并在主应用中管理设置、操作历史和运行日志。

要求 macOS 11 或更高版本；工程使用 Xcode 16 的目录同步功能，开发需要 Xcode 16 或更新版本。原生 SwiftUI、AppKit、FinderSync、SQLite3，无第三方依赖。

## 构建与测试

```bash
bash scripts/build.sh Debug
open .build/xcode/Build/Products/Debug/HappaTools.app
swift test --scratch-path .build/core
xcodebuild -project HappaTools.xcodeproj -scheme HappaTools \
  -destination 'platform=macOS' -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO test
swiftc FinderSyncExtension/MenuBuilder.swift Tests/MenuSmoke/main.swift -o .build/menu-smoke
.build/menu-smoke
swiftc HappaTools/Views/OperationPrompt.swift Tests/PromptSmoke/main.swift -o .build/prompt-smoke
.build/prompt-smoke
```

`build.sh` 生成本机临时签名构建，不代表 Developer ID 签名或公证。正式签名需要自己的开发者团队、App Group 和描述文件；见[安装与分发说明](docs/SETUP.md)。

```bash
bash scripts/package.sh
```

生成 `dist/HappaTools-local.dmg`，包含应用、Applications 链接和使用说明。

## 行为

- Git：输入多行提交信息，默认当地时间 `yyyy-MM-dd HH:mm`；打开提交框时全选日期，直接输入即可替换。校验仓库和上游后，暂存**整个仓库**的所有更改，提交并推送当前分支到配置的上游。无新更改时仍可推送已有提交。
- 不自动初始化仓库，不自动设置远端，不切换分支，不强制推送。推送失败会保留本地提交。
- README：在 Git 按钮菜单的“提交并推送”下方选择“创建 README.md”。原子创建空文件，已有文件、目录或符号链接均不覆盖。
- 设置：默认分支、Git 路径、Git / README 操作开关、在 Dock 中隐藏应用。Dock 设置保存后立即生效，重启后保留；隐藏后仍可从“应用程序”打开 HappaTools。已检出的分支优先于默认分支。
- 历史与日志：显示最近 100 条结果，支持文本、日期、操作类型、状态筛选；每 3 秒刷新；主应用启动和每次执行操作时清理 30 天前记录。
- Git 在后台运行，每条命令限时 30 秒，日志中每个输出流最多保留 1 MiB；同仓库操作用跨进程锁避免重复提交。

## Finder 平台限制

Finder Sync 每个扩展提供一个工具栏按钮。Git 按钮菜单同时提供提交和 README 操作，无需启用独立 README 扩展；应用也保留可选的独立 README 按钮。菜单使用标准菜单项，由扩展的主类响应动作；Git 多行编辑器位于弹出的提交框中。Finder 不提供可靠的菜单内自定义文本编辑器支持。

Finder 的“自定工具栏”负责按钮显示和隐藏；应用设置负责启用和禁用操作。扩展注册已挂载卷及 home 目录，系统目录、虚拟视图、云盘或其他 Finder 扩展可能使 `targetedURL()` 返回空；此时明确要求选择文件夹，不猜测当前路径。

这些差异对应原需求的平台错误前提，详见 [Apple Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)、[目标目录 API](https://developer.apple.com/documentation/findersync/fifindersynccontroller/targetedurl())、[Apple DTS 关于目录归属的说明](https://developer.apple.com/forums/thread/756711)。

## 当前打包结构

外层 `HappaTools.app` 是非沙盒主应用，负责访问仓库、执行 Git、创建 README 和保存日志。Git Finder Sync 扩展嵌在主应用中；README Finder Sync 扩展放在独立的 `Contents/Helpers/HappaTools README.app` 中。两个 Finder Sync 扩展及 README helper 都保持沙盒，helper 只用于让系统发现 README 扩展，不启动主应用状态。

在 macOS 15 上，可从“系统设置 → 通用 → 登录项与扩展 → 扩展 → 文件提供程序”启用 `HappaTools`，再在 Finder 的“显示 → 自定工具栏”中加入 Git 按钮，即可使用两项操作。如需独立 README 按钮，可另外启用 `HappaTools README` 并添加其按钮。完整磁盘访问权限只需要按需授予外层 `HappaTools.app`，不能把沙盒扩展当作主应用授权。

验证范围和未完成的系统级验证见 [VALIDATION.md](docs/VALIDATION.md)。
