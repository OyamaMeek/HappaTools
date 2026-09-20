# 验证记录

更新时间：2026-09-21。以下结果来自当前工作区和本机已安装的 `/Applications/HappaTools.app`。

## 2026-09-21 窗口收尾与 Dock 修复

- `Tests/FinderOperationSmoke/main.swift`：真实 AppKit 弹窗检查通过，覆盖启动时恢复 Dock 设置、Git / README 取消、README 创建成功、Git 失败、目录失效和结果弹窗期间防重入。取消后窗口未关闭、目录失效未走统一弹窗两项均先复现断言失败，再修复并验证通过；2026-09-21 重新运行通过。编译命令见 README。
- `swift test --scratch-path .build/core`：23/23 通过。`bash scripts/build.sh Release` 通过，签名校验通过。构建日志中的 Simulator 服务和 AppIntents 元数据提示未阻止 macOS 构建。
- 已更新 `/Applications/HappaTools.app`；2026-09-21 签名校验通过，主程序 SHA-256 与 Release 构建一致。原应用备份为 `.build/HappaTools-before-finder-return-fix.zip`。本次未重制 DMG。
- 实机只读检查显示安装版激活策略为 accessory（1），保存的隐藏 Dock 设置生效；主窗口关闭后可重新打开，Finder 菜单能再次唤起 Git 弹窗。
- 实机 README 已在隔离测试目录创建。Git 验收遇到 `git rev-parse --is-inside-work-tree` 超时，因此不计为实机完整提交/推送成功。底层 Git 工作流由共享测试中的临时仓库和本地 bare remote 验证。
- 桌面自动化曾多次超时；进程采样显示一次启动在等待 macOS 配置服务，随后恢复响应。针对已关闭应用调用界面查询会重新唤起主窗口，收尾验证应使用回归检查和不激活应用的状态读取。
- Dock 使用系统 [accessory 激活策略](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory)；窗口收尾仅激活已有 Finder，不打开目录 URL，避免额外创建访达窗口或改变目录。

## 2026-09-19 验证记录

## 已完成

- `bash scripts/build.sh Release`：通过；外层应用、Git extension、README helper、README extension 和共享 framework 均生成，构建脚本按 framework → extension → helper → 外层应用顺序临时签名。
- `swift test --scratch-path .build/core`：23/23 通过。覆盖真实临时 Git 仓库、本地 bare remote、custom upstream、同名 tag、无 upstream、推送失败、并发锁、超时输出、SQLite 跨连接读取、设置持久化、README 覆盖和符号链接边界。
- 此前已通过 `xcodebuild -project HappaTools.xcodeproj -scheme HappaTools -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`。本次共享测试使用上列 `swift test` 命令。scheme 的 TestAction 使用 Debug 配置；直接指定 Release 测试会因共享 framework 未开启 `ENABLE_TESTABILITY` 而失败，这不是默认测试命令的配置。
- `swiftc FinderSyncExtension/MenuBuilder.swift Tests/MenuSmoke/main.swift -o .build/menu-smoke && .build/menu-smoke`：通过 Git 菜单中的 README 顺序、独立 selector、独立开关、忙碌和无路径共 32 种状态检查。
- `swiftc HappaTools/Views/OperationPrompt.swift Tests/PromptSmoke/main.swift -o .build/prompt-smoke && .build/prompt-smoke`：真实 NSAlert 验证默认日期全选、中文多行输入替换、保留默认值和取消；修复前断言失败，修复后通过。
- 此前运行 `bash scripts/package.sh` 生成的 `dist/HappaTools-local.dmg` 已通过 `hdiutil verify` 和签名验证；该旧 DMG 不包含本次三项修改。它是临时签名开发包，未使用 Developer ID，也未公证。
- 已启动 `/Applications/HappaTools.app` 烟测，进程正常存活。主应用 entitlement 为非沙盒并包含 App Group；README helper entitlement 为沙盒并包含同一 App Group。
- 此前的 `pluginkit -m -A -D -vv` 检查显示两个 HappaTools 扩展均来自 `/Applications/HappaTools.app`，当时未发现本项目 `.build` 旧注册项。
- 本次修改重新通过 Debug/Release 构建，已更新 `/Applications/HappaTools.app` 并验证签名；替换前应用备份到 `.build/HappaTools-before-ui-update.app`。本次未重新制作 DMG。
- Dock 实机验证：设置保存后运行策略为 accessory（1），关闭窗口后可从 Finder 的“应用程序”重新打开，取消勾选保存后恢复 regular（0）；测试后保留原先显示 Dock 图标的偏好。跨实例偏好持久化由共享测试覆盖。
- Finder 实机验证：Git 工具栏菜单显示“提交并推送…”和下方“创建空白 README.md”；点击 README 后确认路径正确，并在 `.build/finder-readme-smoke-20260919` 成功创建 0 字节文件。
- 本次完整共享测试最终 23/23 通过。此前两次运行中，既有并发测试的 2 秒 hook 等待曾超时；带 Git 时间追踪的单独运行及随后的完整复跑通过，未修改 Git 逻辑或放宽断言。环境存在这项时序波动。

## 尚待手动完成

- 使用一次性 Git 仓库，在真实 Finder 中完成 README 不覆盖、整仓提交、多行提交消息、推送、无新更改推送和推送失败保留本地提交。相关底层行为已有共享测试覆盖。
- 验证非 Git 目录、无 upstream 目录、忙碌状态和主应用退出后的重新唤起。
- 受保护目录访问取决于用户对外层主应用的完整磁盘访问授权。
- Developer ID 签名、公证、Gatekeeper 和公开分发 DMG 需要未提供的证书与公证凭据。
