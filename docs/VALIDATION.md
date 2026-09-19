# 验证记录

更新时间：2026-09-19。以下结果来自当前工作区和本机已安装的 `/Applications/HappaTools.app`。

## 已完成

- `bash scripts/build.sh Release`：通过；外层应用、Git extension、README helper、README extension 和共享 framework 均生成，构建脚本按 framework → extension → helper → 外层应用顺序临时签名。
- `swift test --scratch-path .build/core`：23/23 通过。覆盖真实临时 Git 仓库、本地 bare remote、custom upstream、同名 tag、无 upstream、推送失败、并发锁、超时输出、SQLite 跨连接读取、设置持久化、README 覆盖和符号链接边界。
- `xcodebuild -project HappaTools.xcodeproj -scheme HappaTools -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`：通过。scheme 的 TestAction 使用 Debug 配置；直接指定 Release 测试会因共享 framework 未开启 `ENABLE_TESTABILITY` 而失败，这不是默认测试命令的配置。
- `swiftc FinderSyncExtension/MenuBuilder.swift Tests/MenuSmoke/main.swift -o .build/menu-smoke && .build/menu-smoke`：通过 Git、README、忙碌、关闭和无路径菜单契约检查。
- `bash scripts/package.sh`：生成 `dist/HappaTools-local.dmg`；`hdiutil verify` 和 `codesign --verify --deep --strict` 均通过。该 DMG 是临时签名开发包，未使用 Developer ID，也未公证。
- 已启动 `/Applications/HappaTools.app` 烟测，进程正常存活。主应用 entitlement 为非沙盒并包含 App Group；README helper entitlement 为沙盒并包含同一 App Group。
- `pluginkit -m -A -D -vv` 当前显示两个 HappaTools 扩展均来自 `/Applications/HappaTools.app`，未发现本项目 `.build` 旧注册项。

## 尚待手动完成

- 系统设置中启用 `HappaTools` 与 `HappaTools README`，并在 Finder 自定工具栏加入 Git、README 按钮。
- 使用一次性 Git 仓库，在真实 Finder 中完成 README 创建、不覆盖、整仓提交、多行提交消息、推送、无新更改推送和推送失败保留本地提交。
- 验证非 Git 目录、无 upstream 目录、忙碌状态和主应用退出后的重新唤起。
- 受保护目录访问取决于用户对外层主应用的完整磁盘访问授权。
- Developer ID 签名、公证、Gatekeeper 和公开分发 DMG 需要未提供的证书与公证凭据。
