# Things3 自动上传

在 HappaTools 主应用侧边栏打开 **Things3**。Finder 菜单没有 Things3 入口。

## 配置

1. 准备专用的私有 Git 备份仓库，将它克隆到本机。仓库须至少有一个提交，当前分支已配置上游，Git 身份和免交互认证可用。
2. 点击“选择仓库…”。数据库路径可以留空自动查找，也可以选择 Things3 的 `main.sqlite`。检测到多个数据库时须明确选择；数据库不可读时按系统提示授予 HappaTools 所需权限。
3. 选择 1、5、15 或 60 分钟间隔，点击“保存配置”。检查当前仓库和分支后，点击“立即同步”或开启“自动上传”。开关默认关闭。
4. 结果显示在当前页面，历史及错误可在“操作历史”或“日志”按 Things3 类型筛选。

自动上传在应用运行期间工作，启动已启用的应用时先同步一次。关闭窗口后继续运行，退出应用时等待当前操作结束再退出。此功能不安装登录项或独立后台服务。

## 输出与保护

| 路径 | 内容 |
| --- | --- |
| `Inbox.md`、`Anytime.md`、`Someday.md` | 没有所属项目或领域的任务 |
| `Today.md`、`Upcoming.md` | 日期派生视图，允许与主位置重复 |
| `已完成.md`、`已取消.md` | 顶层完成和取消任务 |
| `Projects/<标题>-<UUID>/tasks.md` | 项目信息及活动任务 |
| `Areas/<标题>-<UUID>/tasks.md` | 领域信息及直接属于领域的活动任务 |
| 项目或领域下的 `已完成.md`、`已取消.md` | 对应容器中的结束任务 |
| `Archived/Projects/…`、`Archived/Areas/…` | 从可见快照中消失的容器导出 |
| `.happatools-things3.json` | 版本化所有权清单及历史路径 |

任务包含 UUID、状态、日期、提醒时间、标签、备注、项目/领域/标题分组和按 Things 顺序排列的 Checklist；有值时保留 Checklist 完成/取消时间。项目自身的说明和状态也导出。标题中的非法路径字符会替换，UUID 避免重名碰撞。仅大小写或 Unicode 表示变化时沿用已有目录拼写，正文使用新标题。

同一 SQLite 只读事务读取完整数据，包含 WAL 中已提交的变化；所有读取成功后才协调文件。生成文件带精确所有权标识，内容相同不重写。单个文件原子替换、清单最后更新；整个目录并非一次原子替换，中途失败会留下已写文件供下次完整同步恢复。

应用只覆盖或删除自己的生成文件，拒绝陌生同名文件、符号链接和无效清单。不移动含个人文件的整个目录。原 Things3-push 的生成标识不同，现有同名文件会阻止导出；请使用独立备份仓库，或先妥善保存旧导出再处理冲突文件。

## Git 行为

- 每轮校验保存的仓库、分支、上游和唯一远端地址；配置变化后须重新保存。合并、变基或其他 Git 操作未完成时停止。
- 明确路径暂存并使用 `git commit --only`，保留不相关的用户暂存内容。每条 Git 命令限时 30 秒；复用与 Finder Git 操作一致的仓库锁。
- 没有内容变化不创建提交。提交失败会留下导出和暂存内容；推送失败保留本地提交，下次无变化同步也会重试。
- 普通推送当前分支到保存的上游，因此也会包含该分支其他已提交但尚未推送的提交。使用专用仓库可避免混用。
- 不初始化仓库、不配置远端、不切换分支、不自动拉取或解决冲突、不强制推送。

## 导出范围

单向读取，不会更新 Things3。回收站、重复任务模板和附件不导出；已经生成的重复任务实例可以导出。Today/Upcoming 沿用参考读取库的日期语义，Things 未运行时不会替它生成新重复任务。本功能提供可读任务历史，不能直接导入 Things3 恢复数据库。

日期转换和表关系参考用户提供的 thingsapi/things.py；数据库格式属于 Things 私有实现，未来变化可能触发兼容性错误。测试样本及原许可证保留于 `Tests/Fixtures/Things/`。技术依据见 [SQLite 快照隔离](https://www.sqlite.org/isolation.html)、[Git 指定路径提交](https://git-scm.com/docs/git-commit)、[Things 官方数据导出说明](https://culturedcode.com/things/support/articles/2982272/)。

## 验证命令

```bash
swift test --scratch-path .build/core
bash scripts/build.sh Release
swiftc -F .build/xcode/Build/Products/Release -framework HappaToolsShared \
  -Xlinker -rpath -Xlinker "$PWD/.build/xcode/Build/Products/Release" \
  HappaTools/App/ThingsController.swift Tests/ThingsAppSmoke/main.swift \
  -o .build/things-app-smoke
.build/things-app-smoke
```

应用行为检查使用真实 SQLite 样本和本地 bare Git 远端。可显式设置 `THINGS_LIVE_DATABASE` 执行本机数据库只读导出，该部分只写入被忽略的 `.build` 目录，绝不推送个人任务。
