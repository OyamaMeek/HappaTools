# 验证标准

- Swift shared tests：真实临时 Git 仓库及本地 bare 远端；非仓库/无 upstream 不修改仓库；无更改可继续推送；非法输入与超时有错误。当前 23/23 通过。
- SQLite：参数绑定、两个连接间读取、30 天保留、过滤与清空。当前 shared tests 覆盖通过。
- 设置：新实例读取同 suite 数据及默认值；README：空文件、不覆盖/不跟随现有符号链接。当前 shared tests 覆盖通过。
- Xcode：macOS 11 部署目标下主应用、两个扩展、共享框架构建成功；Debug scheme 测试 target 可运行。Release 测试未作为验证命令，因为该配置未开启 `ENABLE_TESTABILITY`。
- 菜单 smoke test：Git、README、忙碌、关闭和无路径契约通过。
- 打包：本地 DMG 生成，`hdiutil verify` 和 `codesign --verify --deep --strict` 通过；构建脚本按由内到外顺序签名。仅为临时签名，未公证；公证脚本会逐层检查外层应用、helper、两个 extension 和两份 framework 的 Developer ID / Hardened Runtime。
- 主应用启动和 pluginkit 注册检查已完成；系统扩展启用、Finder 工具栏、受保护目录授权、Developer ID 公证状态仍需单独记录，不以构建通过代替。
- 提交前检查：`git diff --check`、明确暂存文件、密钥与调试文件；提交后普通推送 main。
