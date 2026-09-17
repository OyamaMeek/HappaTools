# FinderGitHelper

一个 macOS 菜单栏工具，对最前方 Finder 窗口中的文件夹执行 Git 提交和推送，或创建空白 `README.md`。

## 运行

需要 macOS 12 或更新版本、Xcode 14 或更新版本，以及 `/usr/bin/git`。没有第三方依赖。

```bash
open FinderGitHelper.xcodeproj
```

选择 `FinderGitHelper` scheme，按 `⌘R`。应用以终端图标出现在菜单栏，不显示 Dock 图标。

也可以从命令行构建并运行：

```bash
xcodebuild -project FinderGitHelper.xcodeproj \
  -scheme FinderGitHelper -configuration Debug \
  -derivedDataPath .build/DerivedData build
open .build/DerivedData/Build/Products/Debug/FinderGitHelper.app
```

## 使用

1. 在 Finder 中打开目标文件夹，再点击菜单栏中的终端图标。每次打开菜单都会重新读取路径及 README 状态。
2. 点击 **Commit & Push…**，确认目录、分支和提交信息。提交信息默认是当前本地时间，格式为 `yyyy-MM-dd HH:mm`，支持多行。`⌘Return` 提交，取消不执行 Git。
3. 应用依次执行 `git add .`、`git commit -m <message>`、`git push origin <branch>`。运行中显示进度，结束后发送通知；失败时显示可滚动、可复制的完整错误详情。
4. **Create README.md** 创建零字节文件并刷新 Finder。文件已存在时隐藏按钮，遇到并发创建或符号链接也不会覆盖内容。
5. **Settings…** 修改默认分支及两个操作按钮的可见性，设置立即保存。默认值是 `main`、显示 Git 按钮、显示 README 按钮。

提交窗口打开后固定使用窗口中显示的目录和分支，切换 Finder 窗口不会使已经确认的操作转向其他目录。没有 Finder 窗口时显示 `No Finder window`，文件操作禁用。网络浏览等无法转换为文件系统路径的位置会显示错误；有本地路径且可访问的 iCloud 文件夹可以使用。

### Git 行为

- 目标必须位于 Git 工作区中，当前分支必须与设置一致。应用不会切换分支，也不会初始化仓库、自动拉取或强制推送。
- `git add .` 暂存当前文件夹及其子目录中的非忽略文件。Git 提交还会包含仓库其他位置已经暂存的内容。使用前检查 `.gitignore`，排除密钥和私密文件。
- 首次使用前，在 Terminal 中配置 Git 身份、`origin`、HTTPS credential helper 或 SSH 密钥；应用没有交互式密码输入窗口。现有 SSH 配置保持有效。
- 没有变更时提示 `No changes to commit.`。未初始化的目录提示 `Not a git repository. Run 'git init' first.`。
- 每条 Git 命令最多等待 60 秒。超时、认证错误、远端拒绝等都会保留输出，应用不会丢弃本地改动。
- 推送失败后本地提交仍然存在。**Retry Push** 只重试推送，不重复提交；远端冲突需要先在 Terminal 解决。菜单保留本次运行中最近一次失败的推送目标，重启应用后可在原目录执行 `git push origin <branch>` 恢复。
- 暂存、提交或 Git hook 失败后，已完成的暂存状态会保留，方便检查和修正。

## 权限

首次启动会请求通知权限，并通过 AppleScript 读取 Finder。Finder 自动化权限由系统管理：

1. macOS 13 及更新版本进入“系统设置 → 隐私与安全性 → 自动化”；macOS 12 进入“系统偏好设置 → 安全性与隐私 → 隐私 → 自动化”。
2. 找到 `FinderGitHelper`，允许访问 Finder。
3. 回到应用刷新路径。如果权限被拒绝，错误窗口提供 **Open Automation Settings** 入口。

如果系统另外询问受保护文件夹的访问权限，请根据你需要操作的目录授权。通知被关闭时仍可在菜单查看操作结果；横幅或提醒样式由 macOS 的通知设置决定。

## 测试

```bash
xcodebuild test -project FinderGitHelper.xcodeproj \
  -scheme FinderGitHelper -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData
```

15 项 XCTest 覆盖设置持久化、日期格式、AppleScript 编译、路径验证、README 防覆盖、参数传递、分支检查、完整输出、超时以及真实本地仓库的提交和推送恢复。测试使用 `.build/test-data` 内的独立工作区和 bare remote，不连接 GitHub；通过 Git 搜索边界避免访问父项目仓库。

实际验证结果及未完成的系统交互检查见 [验证记录](docs/VERIFICATION.md)。

## Release 构建

```bash
xcodebuild -project FinderGitHelper.xcodeproj \
  -scheme FinderGitHelper -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .build/DerivedData \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
codesign --verify --deep --strict \
  .build/DerivedData/Build/Products/Release/FinderGitHelper.app
```

产物位于 `.build/DerivedData/Build/Products/Release/FinderGitHelper.app`。工程默认使用本地 ad-hoc 签名，可以本机运行；对外分发需要自己的 Developer ID、Hardened Runtime 签名及 Apple 公证。本次没有分发证书，也未执行公证。

## 实现说明

SwiftUI `App` 管理生命周期，`NSStatusItem` / `NSPopover` 承载菜单，视图使用 SwiftUI。Apple 的 [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) 需要 macOS 13，因此这里采用能覆盖 macOS 12 的 AppKit 状态栏和进度指示器，没有 AppDelegate。

Git 使用 `Process` 参数数组运行，不拼接 shell 命令。Finder AppleScript 在 actor 中串行执行，Git 和文件操作在后台任务中执行，界面状态统一由 `@MainActor` 更新。进程输出写入临时文件，避免管道写满导致进程挂起。

图标资源已包含在工程中；需要重新生成时执行 `swift scripts/generate-icon.swift`。
