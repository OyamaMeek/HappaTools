# 注意事项

- Finder Sync 每个扩展只支持一个工具栏项目；隐藏设置只能禁用对应入口，工具栏移除须由 Finder 自定工具栏操作。
- 不通过普通 home 文件的可读性认定完整磁盘访问权限已授予。
- 不在无效远端配置下先执行 add/commit。
- Finder 菜单传递标准菜单属性，action 必须在 principal class；多行输入用扩展自己显示的提交框。
- 同一目录可能由其他 Finder 扩展控制；targetedURL 为空时用文件夹选择器，不猜测路径。
