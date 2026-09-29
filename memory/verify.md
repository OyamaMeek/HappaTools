# 验证标准

## 2026-09-29 Things3 自动上传

- 先运行缺失功能的失败测试，再运行 Swift 共享测试；测试使用 SQLite 参考样本与真实本地 bare Git 远端。
- 数据库：只读完整事务、WAL 中已提交内容、完成/取消状态、项目/分组/领域关系、原始 checklist 顺序；读取失败不修改导出。
- 文件：重复导出无变化、重命名/归档、原子写入、拒绝陌生文件/符号链接/非法清单路径，失败恢复可再次提交。
- Git：仅托管路径进入提交，不相关暂存内容保留；无变化不提交，失败推送后无数据变化仍可重试；切换分支/远端先失败。
- 应用：配置保存与定时同步、禁止重入、关闭自动上传停止后续调度、退出等待同步；Release 构建及签名检查。未授权截图，不执行视觉验收。
- 本机 Things3 只读导出至 .build，记录数量和校验结果，不提交任务内容；源码 Git diff 检查后明确文件提交和推送。
- 已执行：31/31 共享测试通过；ThingsAppSmoke 配置、启用、禁止重入、上传、关闭、重载、日志、幂等检查通过；本机只读导出188个任务、32个托管路径。独立审查4项核心问题已通过失败→通过的测试修复。

## 2026-09-29 提交框光标

- PromptSmoke：保留日期全选、直接替换、多行、默认值与取消；深浅色模式下插入光标与背景具有明确亮度差。
- 运行共享测试、Release 构建与签名校验、`git diff --check`；不截图，不声称完成视觉验收。
- 结果：PromptSmoke 先失败后通过，23 项共享测试通过，Release 构建及安装版签名、主程序一致性校验通过。测试临时文件放入 `.build/test-tmp`；SwiftPM 因嵌套沙盒失败后获准在沙盒外运行通过。

## 既有验证标准

- Swift shared tests：真实临时 Git 仓库及本地 bare 远端；非仓库/无 upstream 不修改仓库；无更改可继续推送；非法输入与超时有错误。当前 23/23 通过。
- SQLite：参数绑定、两个连接间读取、30 天保留、过滤与清空。当前 shared tests 覆盖通过。
- 设置：新实例读取同 suite 数据及默认值；README：空文件、不覆盖/不跟随现有符号链接。当前 shared tests 覆盖通过。
- Xcode：macOS 11 部署目标下主应用、两个扩展、共享框架构建成功；Debug scheme 测试 target 可运行。Release 测试未作为验证命令，因为该配置未开启 `ENABLE_TESTABILITY`。
- 菜单 smoke test：Git、README、忙碌、关闭和无路径契约通过。
- 打包：本地 DMG 生成，`hdiutil verify` 和 `codesign --verify --deep --strict` 通过；构建脚本按由内到外顺序签名。仅为临时签名，未公证；公证脚本会逐层检查外层应用、helper、两个 extension 和两份 framework 的 Developer ID / Hardened Runtime。
- 主应用启动和 pluginkit 注册检查已完成；系统扩展启用、Finder 工具栏、受保护目录授权、Developer ID 公证状态仍需单独记录，不以构建通过代替。
- 提交前检查：`git diff --check`、明确暂存文件、密钥与调试文件；提交后普通推送 main。
