# 验证标准

- XCTest 验证 UserDefaults 持久化和默认值、日期格式、AppleScript 编译、Finder 返回值解析。
- 注入命令执行器检查参数顺序和输入校验，同时使用真实本地 bare remote 验证提交、推送和失败后的推送恢复。
- 验证非仓库、无改动、分支不匹配、执行失败、完整大输出及超时。
- README 创建、已存在文件及符号链接保护。
- Debug / Release 构建，部署目标 macOS 12，检查本地签名和启动。
- macOS 12 / 13 的真机验证和 Developer ID 公证需要对应环境与证书，未执行时明确记录。
