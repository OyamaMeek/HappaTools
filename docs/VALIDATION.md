# 验证记录

更新时间：2026-10-01。以下结果来自当前工作区和本机已安装的 `/Applications/HappaTools.app`。

## 2026-10-01 提交弹窗顶部图标及光标排查

- 提交弹窗用原生空图像代替顶部应用图标；PromptSmoke 的实际视图树检查失败→通过，日期全选、直接替换、多行、默认值、取消及深浅色光标颜色保持通过。
- 共享33/33测试、FinderOperationSmoke、Release构建、签名完整性及diff检查通过。SwiftPM在沙盒中被拒绝、Finder操作烟测在沙盒中停滞，均在沙盒外重跑通过。已备份至 `.build/HappaTools-before-prompt-icon-20261001.zip` 并校验 ZIP，更新启动安装版，主程序与构建产物逐字节一致。继续使用既有临时签名；未执行截图或视觉检查。
- 光标检查使用真实 AppKit 主运行循环；前10秒应用及窗口活动且指示器存在，30/65秒窗口失去活动后系统隐藏指示器。未复现活动窗口中静置后彻底消失，尚未修改光标行为，正常闪烁或持续可见的偏好待用户确认。

## 2026-10-01 App 数据权限弹窗

- TCC 日志明确记录旧授权 code requirement 与安装版 cdhash 不匹配；主应用与 Git 扩展均曾触发 SystemPolicyAppData。概览启动时还会探测无关的 Mail 目录，现已删除该读取。
- 概览状态断言先失败后通过；33/33 共享测试及 FinderOperationSmoke 通过，Debug/Release 构建完成，脚本语法及 diff 检查通过。未执行视觉检查。
- 签名烟测可验证两版主应用、helper、扩展及 framework 的身份兼容，但实际签名证书在线验证返回 CSSMERR_TP_CERT_REVOKED，另一身份在本地列表中也显示撤销。AMFI 同样拒绝实际启动；构建新增在线信任及吊销检查，明确指定撤销证书时返回失败。稳定签名检查尚未通过，需用户在 Xcode 重新生成有效开发证书。
- 已安装可运行的临时签名修复版，主应用及 Git 扩展真实启动，两个扩展注册路径正确；安装主程序、Git 扩展与 Release 产物一致，签名完整性通过。旧版备份 `.build/HappaTools-before-privacy-fix-20261001.zip` 已校验。
- 未修改系统 TCC 授权或钥匙串。临时签名更新仍会改变授权身份，开发版访问其他 App 容器也可能在重启后重新询问；未证明长期无弹窗。系统权限须由用户确认。

## 2026-10-01 Finder 打开 iTerm2

- 菜单和 iterm 请求回归先失败后通过；共享测试33/33、菜单32种状态检查通过，覆盖顺序、独立动作、开关、忙碌与无路径。
- ITermSmoke 调用实际启动器，新建真实 iTerm2 会话；会话将 pwd 写入项目测试文件，普通目录及包含中文、空格、单双引号、命令替换和分号的目录均与输入完全一致。
- FinderOperationSmoke 通过既有 Git/README 取消、成功与失败、Dock 设置、结果防重入及新增 iTerm2 无效目录检查。烟测使用独立无上游仓库；测试共享状态已恢复。
- Release 构建及签名通过，安装版主程序与 Git 扩展逐字节一致。旧版备份为 `.build/HappaTools-before-iterm-20261001.zip`；已重新注册并重启 Git 扩展。构建仍有原有 AppIntents/扩展版本号警告。
- 未截图验收，未将会话历史文本当作 clear 屏幕效果的证据；首次使用 HappaTools 控制 iTerm2 的系统自动化授权由用户按提示选择。

## 2026-09-30 Things3 空仓库配置保存

- 空仓库回归先因 `noRemote` 失败，修复后共享测试32/32通过；覆盖无远端/多远端拒绝、保存不修改仓库、首次提交保留用户暂存文件、首次推送失败后无变化重试并建立上游。
- ThingsAppSmoke 通过保存失败原因保留、空仓库配置保存、自动上传及幂等检查。独立审查发现测试目录会向上识别源码仓库，已改为独立无远端仓库并重新通过。
- 设置 `THINGS_CONFIG_REPOSITORY` 后，对截图中的实际目标成功验证配置保存和数据库自动发现，仅使用隔离 UserDefaults；目标保持无提交、无上游，未上传个人任务。
- Release 构建、签名校验通过，安装版已备份至 `.build/HappaTools-before-things-save-20260930.zip` 并更新、启动；安装版主程序与构建产物逐字节一致。未截图验收，未重制 DMG。

## 2026-09-29 Things3 自动上传

- `swift test --scratch-path .build/core`：31/31 通过，其中8项 Things3 测试使用真实 SQLite 参考样本及本地 bare Git 远端。覆盖只读/WAL、状态和 Checklist、归档、陌生文件及符号链接保护、坏清单、大小写重命名、提交失败后的删除重试、断网重试、分支和远端改变。
- 独立核心审查发现4项边界问题，均使用失败→通过的测试验证修复；应用控制器、设置、退出等待和入口审查未发现可行动问题。
- `ThingsAppSmoke` 在最终 Release 上通过配置保存、自动同步启动、禁止重入、真实上传、关闭、设置重载、历史记录和重复同步无提交检查。未通过等待真实分钟间隔来验收长期后台运行。
- 本机 Things3 数据库只读导出188个任务、32个托管路径，个人任务只写到 `.build`，没有上传至源码仓库或任何网络远端。网络 GitHub 备份目标尚未由用户配置；上传行为通过本地 bare remote 验证。
- 最终 Release 构建、签名校验和 FinderOperationSmoke 通过。构建存在原有 AppIntents/扩展版本号警告；未执行截图或视觉验收。
- 已更新并启动 `/Applications/HappaTools.app`，签名及主程序逐字节一致性检查通过。旧版备份：`.build/HappaTools-before-things3-20260929.zip`。采用临时签名，未公证；本次未重制 DMG。

## 2026-09-29 提交框光标

- 真实 AppKit PromptSmoke 先复现深色光标亮度差不足，设置 `insertionPointColor = .textColor` 后通过深浅色检查；日期全选、直接替换、中文多行、默认值及取消继续通过。未进行截图或视觉验收。
- `swift test --scratch-path .build/core`：23/23 通过；首次运行受到嵌套沙盒限制，获准在沙盒外重新运行后通过。测试临时目录为 `.build/test-tmp`。
- `bash scripts/build.sh Release` 及签名校验通过。构建仍有 Simulator 服务、AppIntents 元数据及扩展版本号警告；未修改这些无关配置。
- 已更新 `/Applications/HappaTools.app`，签名校验及主程序逐字节比对通过；SHA-256 为 `88f58f120398ce0fde772de7553890d9c6afc23f710a632d9199db4877a0598e`。旧版备份为 `.build/HappaTools-before-cursor-fix-20260929.zip`。

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
