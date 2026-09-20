# 验证记录

更新时间：2026-09-19。以下结果来自当前工作区和本机已安装的 `/Applications/HappaTools.app`。

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
