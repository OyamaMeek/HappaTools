# HappaTools Implementation Plan

## 2026-10-01 概览介绍与自动 Dock 显示

- 概览介绍改为“Happa自用的小工具集”。Dock 随窗口显示：有窗口时显示，最后一个窗口关闭后隐藏且继续后台运行；最小化保留 Dock，多窗口关闭其中一个仍显示，重新打开恢复。
- 复用 AppModel 与 AppKit 窗口通知，明确 applicationShouldTerminateAfterLastWindowClosed 返回 false；保留主动退出时的 Things3 同步收尾。移除旧 Dock 设置开关及无效配置接口。
- 先扩展 FinderOperationSmoke 并取得失败证据，再实现、验证共享测试及 Release 构建；备份更新本机安装版，记录验证、归档对话并提交推送。

## 2026-10-01 README 无弹窗创建

- 去掉 README 创建前确认和成功提示；复用现有创建、日志、防重入及返回 Finder 流程，保留失败提示和无路径时的目录选择。
- 现有 FinderOperationSmoke 先验证 README 成功零弹窗并取得失败证据，再修改 AppModel、删除无调用的 confirmReadme；验证重复文件不覆盖、Git 取消/失败和无效目录。
- 运行共享测试、PromptSmoke、Release 构建；备份更新本机安装版，沿用已明确的临时签名限制；更新文档、归档对话并提交推送。

## 2026-10-01 提交框光标持续显示

- 用户追加要求去掉提交弹窗顶部图标；只修改该弹窗的 icon，使用原生空图像，保留布局及应用图标。现有 PromptSmoke 先检查图标未移除，再验证修改。
- 用户报告“光标不能长时间显示”；保留已有日期全选及多行输入要求，已询问是否静置后彻底消失或希望取消闪烁。
- 读取 Finder → AppModel → OperationPrompt 调用链；当前仅设置动态文字颜色，短时回归不覆盖静置。
- 用真实 AppKit 主运行循环检查前台窗口、文本焦点与系统插入指示器的静置状态；根据复现及用户答复确定最小修复，先失败测试再修改。
- 运行 PromptSmoke、共享测试及 Release 构建；若更新安装版先备份，保留既有签名限制。归档对话、日志，明确暂存本轮文件并提交、普通推送。

## 2026-10-01 反复请求 App 数据权限

- 系统日志确认 Finder 扩展发起 SystemPolicyAppData 提示；当前临时签名的指定要求绑定二进制 hash，更新会使授权身份变化。启动和概览检查还会读取无业务用途的 Mail 目录。
- 删除 Mail 权限探测，概览只提示用户在系统设置核实；构建支持证书身份并检查在线信任及吊销状态，无证书时明确提示临时签名的限制。本机证书在线验证被撤销，稳定签名依赖用户在 Xcode 重新生成证书；先安装显式临时签名的可运行版本。
- 先运行概览检查和签名身份失败回归，再修复；验证 Debug/Release 互相满足指定要求、共享测试及 Finder 操作。备份并更新安装版，重新注册及重启本应用扩展；不读取或修改 TCC 授权数据库，不代替用户确认权限。

## 2026-10-01 Finder 打开 iTerm2

- 在 Git 工具栏菜单的 README 项之后增加“在当前路径打开 iTerm2”，复用 FinderRequest 和主应用路由；不增加设置开关。
- 主应用校验实际目录，在后台通过系统 osascript 调用 iTerm2，新建默认配置窗口并执行 `cd %PATH%; clear; pwd`。目录作为 argv 传递，AppleScript 的 quoted form 负责 shell 转义；成功后隐藏 HappaTools，保持 iTerm2 前台。
- 菜单和 URL 测试先失败后实现，验证实际 iTerm2 路径与特殊字符；运行共享测试、Finder 操作烟测和 Release 构建，备份更新安装版，记录并提交推送。

## 2026-09-30 Things3 新仓库保存配置

- 已确认用户目标仓库有唯一 origin、main 尚无提交、无 branch.main 上游配置；保存被 hasRemoteTracking 拒绝，随后开关覆盖具体错误。
- 保存阶段只读解析目标：已有上游使用原值；无上游且唯一远端时展示并使用当前同名分支，多远端或不完整配置明确报错。保存不修改仓库、不上传。
- 同步支持无 HEAD 的首次选择性提交；成功推送才建立上游，无可解析上游时直接尝试普通推送，失败保留本地提交并可重试。
- 控制器保留具体保存失败信息，未配置时禁用自动上传入口。真实空仓库及失败保存回归先失败后修复，构建安装、日志和提交推送。

## 2026-09-29 Things3 自动上传

**目标与授权**：在 HappaTools 应用内提供唯一入口；按用户选择保留多个 Markdown 文件及 Projects、Areas、Archived 目录。单向导出，不修改 Things3。沿用当前 main 开发、提交和普通推送授权。

**设计**：Swift 原生 SQLite 只读连接，在同一事务内读取任务、领域、标签和清单；稳定渲染，带所有权标识和版本化清单。使用标题与 UUID 组成容器路径，重命名清理旧托管文件，消失容器的文件进入 Archived。清单最后原子写入；失败后按完整快照收敛。

**Git**：保存所选仓库当前分支、上游及远端地址，每轮重校验；复用 GitExecutor 和仓库锁。明确路径 add、commit --only，保留不相关暂存项；按 HEAD 与上游的差异重试上传，无自动拉取、合并、初始化或强制推送。数据库读取或文件所有权检查失败时不修改导出。

**应用**：Things3 独立页面，选择已有仓库和数据库（可自动发现）、同步间隔、默认关闭的自动上传开关、立即同步、结果状态。应用运行期间定时检查，窗口关闭不停止；应用退出等待进行中的同步结束。配置和历史复用原有设施。

1. Shared/Things 下实现读取、渲染与文件协调；测试读取参考样本，覆盖状态、关系、清单顺序、重命名归档、路径与陌生文件保护。
2. 实现选择性 Git 同步与配置；真实 Git 测试覆盖不相关暂存项、无变化、提交/推送失败重试、分支或远端改变。
3. 接入 AppModel、Things3 页面和日志筛选；应用行为烟测、共享测试、Release 构建与签名校验。
4. 本机真实数据库只读导出至忽略目录，绝不上传个人任务到源码仓库。记录证据、对话、提交和推送。

参考审查：Things3-push 多连接读取缺少一致快照；Git 错误转为布尔值而上层记录成功；项目查询默认只包含未完成项目；自动选择多个数据库中的字典序末项无法证明是当前库。本次采用单事务、抛出错误、完整状态、数据库歧义明确失败。

## 2026-09-29 提交框光标

- 保留默认日期全选；点击或输入后的插入光标随深浅色模式保持清晰。
- 复用 AppKit 的动态文字颜色与现有 PromptSmoke，先验证颜色对比不足，再作最小修复。
- 运行弹窗回归、共享测试、Release 构建与签名校验；记录结果并提交、推送。

> 使用 superpowers:subagent-driven-development 分工实施；用户已授权直接在 main 开发并推送。

**Goal:** 根据 `Claude/Claude.md` 建立 macOS 11+ Finder Git / README 工具及主应用。
**Architecture:** SwiftUI 主应用、Git Finder Sync 扩展、独立 README helper app 中的 README Finder Sync 扩展、Foundation / SQLite3 共享模块。每个扩展提供一个工具栏按钮；同一 App Group 保存设置和数据库。主应用非沙盒，两个扩展和 README helper 保持沙盒。
**Tech Stack:** Swift 5、SwiftUI、AppKit、FinderSync、SQLite3；无第三方依赖。
**Spec:** `Claude/Claude.md`

## 全局约束与裁定

- macOS 11.0 起；Git 在后台执行，UI 回到主线程；每条 Git 命令 30 秒超时。
- 非仓库不初始化；无远端跟踪在暂存/提交前失败；README 必须为空且不得覆盖现有文件。
- 只对当前检出分支提交和推送；默认分支用于空配置展示，不允许向无关分支提交后错误推送。
- 使用原生 SQLite3，需求同时允许 raw C API，无需引入 GRDB。
- Finder Sync 每个扩展仅一个按钮，因此使用 Git extension 和 README extension 两个 target；README extension 通过独立 helper app 嵌入，扩展开关可分别显示。空 directoryURLs 表示不监控，改为卷根目录监控。
- 完整磁盘访问无法通过读取普通 home 文件可靠判断，展示未知/受保护路径探测结果与授权指引，不假报已授权。
- 签名配置可供真实 Developer ID 使用；本机无该证书，禁止声称公证成功。

## Task 1: 共享基础设施

- [x] 在 Tests/HappaToolsSharedTests 编写并运行失败测试，覆盖设置持久化、数据库插入/清理/跨连接读取、Git 校验/本地远端提交推送/失败、README 不覆盖。
- [x] 实现 Shared 下的配置、数据库和 Git 代码以及 Package.swift，使用原生 SQLite3，无第三方依赖。
- [x] 运行 `swift test --scratch-path .build/core`，记录结果；共享层实现已包含在此前的共享提交中。

## Task 2: Finder 与主应用

- [x] 实现 FinderSyncExtension/FinderSync.swift、MenuBuilder.swift、GitOperationHandler.swift；标准菜单打开多行提交框、时间戳、禁用与结果提醒。Finder 不支持跨进程传递自定义菜单视图，修正原文该错误前提。
- [x] 实现 HappaTools/App/HappaToolsApp.swift、AppModel.swift 与四个视图，设置四项、扩展状态、历史和日志搜索/类型/状态/日期过滤及确认清理。
- [x] 建立 HappaTools.xcodeproj，包含 Shared framework、主应用、两个扩展和测试 target。
- [x] 运行 xcodebuild build/test；修复编译与实际行为问题，提交应用单元。Debug scheme 测试通过，Release 构建和临时签名通过。

## Task 3: 分发与交付

- [x] 编写构建/打包/签名公证脚本、使用与权限说明、演示步骤；产出可构建应用与本地 DMG。
- [x] 独立审查改动，运行真实 Git 回归测试、主应用启动检查，记录尚依赖 Finder 系统授权的检查。
- [ ] 更新 docs/CHANGELOG.md 和验证记录，完成原子提交与普通 git push；实现提交和文档提交仍待本轮完成。
