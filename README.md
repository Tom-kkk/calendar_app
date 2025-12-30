# calendar_app

一个使用 Flutter 构建的轻量日程管理示例，演示本地存储与通知能力。

- 基于 Flutter 3 与 Material 3，使用 Riverpod 管理日/周/月视图状态。
- Hive 本地存储保存日程与提醒配置，支持持久化读取。
- 集成本地通知（timezone + flutter_local_notifications），附带测试入口。
- 国际化日期显示（zh_CN），展示周次与常用日历视图切换。
