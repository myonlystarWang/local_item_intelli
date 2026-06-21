# 项目变更日志 (Change Log)

所有代码和设计文档的修改均记录在此。

| 版本号 | 修改日期   | 修改类型 | 修改文件名 | 修改内容描述 |
| :--- | :--- | :--- | :--- | :--- |
| V1.0 | 2026-06-21 | 新增 | doc/警告修复与异步安全重构方案_20260621_V1.0.md | 初始化了关于 Flutter 23 处分析器警告的修复方案与设计文档。 |
| V1.1 | 2026-06-21 | 修改 | app/lib/main.dart, app/lib/screens/detail_screen.dart, app/lib/screens/home_screen.dart, app/lib/screens/maintenance_screen.dart, app/lib/screens/sync_screen.dart | 实施重构：修复了 1 处 BuildContext 异步安全隐患，并消除了 22 处废弃 API 警告。项目经 flutter analyze 检测恢复为 0 警告状态。 |
| V1.2 | 2026-06-21 | 修改 | proj/PRD.md | 根据用户评审反馈修改 PRD：入库建档移至 Web 端、暂缓库存盘点和报废流转、简化扫码描述为基础数字码识别、移除 fl_chart 和今日概览、移动端首页改为 AppBar 设置入口。 |
| V2.0 | 2026-06-21 | 新增 | doc/移动端功能完善设计方案_20260621_V2.0.md | 新增移动手持端摄像头扫码、身份确认、设置页面、归还天数 Slider 控件及 `forEach + async` 本地字典写入 Bug 修复的设计方案。 |
| V2.1 | 2026-06-21 | 新增 | doc/库房端新购建档完善设计方案_20260621_V1.0.md | 新增库房管理端手动录入工具名称解耦、配件手动新购建档、后端 API 扩充等设计方案。 |
