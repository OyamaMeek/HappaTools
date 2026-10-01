# 安装与使用

1. 将 HappaTools.app 放入 Applications 后打开。
2. 在“系统设置 → 通用 → 登录项与扩展 → 扩展 → 文件提供程序”中启用 **HappaTools**。主应用概览提供入口；较旧 macOS 版本的入口名称可能不同。
3. 在 Finder 的“显示 → 自定工具栏”中添加 Git 按钮，菜单中“提交并推送”下方即可创建 README。如需独立 README 按钮，可另外启用 **HappaTools README** 并添加其按钮。关闭某项功能后，对应菜单操作禁用；移除按钮仍需使用 Finder 的自定工具栏。
4. 如需操作受保护位置，在“隐私与安全性 → 完整磁盘访问权限”中按需授权外层 **HappaTools.app**。Finder Sync 扩展和 README helper 必须保持沙盒，不要给它们单独配置完整磁盘访问权限。授权终端不等于授权应用；更改权限后重新启动主应用/扩展。

概览提示在系统设置核实权限，不读取其他 App 的数据来探测完整磁盘访问。首次访问 Things3 数据或受保护的目标目录时，macOS 仍可能请求授权；共享容器访问失败会显示错误，不会将数据静默存到另一处。

显示 HappaTools 窗口时自动显示 Dock 图标，关闭全部窗口后隐藏图标并继续后台运行。可从“应用程序”重新打开窗口；最小化时保留 Dock 图标。提交框默认全选日期，直接输入提交说明即可替换；不输入则保留日期。

## Git 准备

先在终端配置 Git 用户名、邮箱、远端和当前分支上游。以下是已有仓库的示例，请把名称换成实际值：

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
git remote -v
git push -u origin main
```

应用按 `/opt/homebrew/bin/git`、`/usr/local/bin/git`、`/usr/bin/git` 顺序选择可执行文件，可在设置中覆盖。使用当前分支实际配置的上游，包括非 `origin` 远端及名称不同的远端分支。

后台 Git 不等待终端密码提示。请先配置可用于非交互进程的 SSH agent 或凭据助手；GPG 签名、hooks、SSH 等也受 30 秒超时限制。超时后请查看日志及仓库状态，再重试。

提交会执行 `git add -A`，包括删除和新文件。应用遵循仓库的 `.gitignore`；提交前请确保密钥和本地配置已正确忽略。

## 故障处理

- **当前目录不是 Git 仓库**：进入已有仓库，应用不会自动执行 `git init`。
- **未配置远程仓库**：检查当前分支 upstream；应用在暂存和提交前检查配置。
- **推送失败，本地提交已保留**：修复网络、认证或远端冲突后重试。应用不会重置或强制推送。
- **Finder 未提供当前路径**：通过菜单选择文件夹。虚拟目录、系统目录或其他 Finder 扩展可能影响目标路径。
- **README 已存在**：保留原文件，不会覆盖，也不会沿符号链接写入。
- **共享目录不可用**：检查外层主应用、Git extension、README extension 和 README helper 的 App Group entitlement、签名与描述文件是否匹配。

历史与日志可能包含本机路径、提交信息及 Git 输出，保存在 App Group 容器的 `happatools.db` 中。清空日志需要确认；清空不会改变 Git 仓库。

## 开发与分发签名

`scripts/build.sh` 默认选择钥匙串列出的首个有效 Apple Development 身份，签署主应用和所有嵌套代码，并在线检查证书信任及吊销状态；证书已撤销或无法确认有效性时明确失败，不允许安装该产物。同一有效证书下的更新保留签名身份。可用 `CODE_SIGN_IDENTITY` 指定证书名称或 SHA-1；指定身份无法使用时构建失败。没有开发证书时明确提示并使用临时签名，更新后可能重新请求隐私权限；可通过 `CODE_SIGN_IDENTITY=-` 明确选择临时签名。`HappaTools-local.dmg` 未公证，不能当作可公开分发版本。

证书检查显示 `CSSMERR_TP_CERT_REVOKED` 时，在 Xcode → Settings → Accounts → Apple ID → Manage Certificates 重新生成 Apple Development 证书，再重新构建。钥匙串的本地身份列表不能替代在线吊销检查。

从临时签名切换到证书签名时，macOS 可能需要重新授权一次。若原有完整磁盘访问条目失效，请在系统设置移除旧 HappaTools 条目，重新添加 `/Applications/HappaTools.app` 并开启，再重启应用。后续更新保持同一签名证书，不使用临时签名产物覆盖安装版。签名身份与授权关系见 [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。

开发版直接访问其他 App 容器时，macOS 的允许结果可能仅对本次运行有效；稳定签名不能单独替代完整磁盘访问授权。容器访问与 App Group 的系统限制见 [Apple 文件访问说明](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)。

正式发布时：

1. 在 Xcode 的 HappaTools、FinderSyncExtension、ReadmeFinderSyncExtension 和 ReadmeExtensionHost 四个 target 配置自己的 Apple 开发者团队，必要时将 bundle ID / App Group ID 更改为自己注册的标识，并同步 `AppGroupConfig.identifier`。
2. 为外层主应用、Git Finder Sync 扩展、README Finder Sync 扩展和 README helper 配置匹配的 App Group capability 与 provisioning profile，启用 Hardened Runtime；保持主应用关闭 App Sandbox，保持两个 Finder Sync 扩展及 README helper 开启 App Sandbox。
3. Archive 后通过 Developer ID Application 身份导出。证书、描述文件和凭据不得提交到仓库。
4. 使用 `xcrun notarytool store-credentials` 将公证凭据保存在 Keychain，然后执行：

```bash
bash scripts/notarize.sh /absolute/path/HappaTools.app YOUR_KEYCHAIN_PROFILE
```

脚本检查 Developer ID 和 Hardened Runtime，再提交 Apple 公证、装订票据并使用 Gatekeeper 验证。将已装订的应用制作成分发 DMG；不要用本机临时签名包替换它。

当前开发环境缺少 Developer ID Application 证书和公证凭据，未执行公开分发公证。
