# 项目变更日志 (Change Log)

所有代码和设计文档的修改均记录在此。

| 版本号 | 修改日期   | 修改类型 | 修改文件名 | 修改内容描述 |
| :--- | :--- | :--- | :--- | :--- |
| V1.0 | 2026-06-21 | 新增 | doc/警告修复与异步安全重构方案_20260621_V1.0.md | 初始化了关于 Flutter 23 处分析器警告的修复方案与设计文档。 |
| V1.1 | 2026-06-21 | 修改 | app/lib/main.dart, app/lib/screens/detail_screen.dart, app/lib/screens/home_screen.dart, app/lib/screens/maintenance_screen.dart, app/lib/screens/sync_screen.dart | 实施重构：修复了 1 处 BuildContext 异步安全隐患，并消除了 22 处废弃 API 警告。项目经 flutter analyze 检测恢复为 0 警告状态。 |
| V1.2 | 2026-06-21 | 修改 | proj/PRD.md | 根据用户评审反馈修改 PRD：入库建档移至 Web 端、暂缓库存盘点和报废流转、简化扫码描述为基础数字码识别、移除 fl_chart 和今日概览、移动端首页改为 AppBar 设置入口。 |
| V2.0 | 2026-06-21 | 新增 | doc/移动端功能完善设计方案_20260621_V2.0.md | 新增移动手持端摄像头扫码、身份确认、设置页面、归还天数 Slider 控件及 `forEach + async` 本地字典写入 Bug 修复的设计方案。 |
| V2.1 | 2026-06-21 | 新增 | doc/库房端新购建档完善设计方案_20260621_V1.0.md | 新增库房管理端手动录入工具名称解耦、配件手动新购建档、后端 API 扩充等设计方案。 |
| V2.2 | 2026-06-21 | 新增 | doc/项目环境搭建与调试指南_20260621_V1.0.md | 初始化项目环境搭建、启动调试、测试及结束流程上手文档。 |
| V2.3 | 2026-06-21 | 新增 | doc/系统测试问题优化方案_20260621_V1.0.md | 初始化系统测试问题优化方案，涵盖 7 项测试结论分析。 |
| V3.0 | 2026-06-22 | 新增 | doc/手持端UI与同步逻辑优化方案_20260622_V1.0.md | 初始化设计方案，细化静态指示器、缩减扫描按钮尺寸及详情页 Mock 信息卡片任务。 |
| V3.1 | 2026-06-22 | 修改 | app/lib/screens/home_screen.dart, app/lib/screens/detail_screen.dart, app/lib/screens/sync_screen.dart | 重构首页为Sliver大滚动布局并瘦身操作按钮尺寸；顶部网络改为静态指示器并增加5秒连通性心跳监测；只读模式隔离资产预览点击详情；详情页添加Mock设备技术参数；实现出入库后后台自动同步及离线弹窗警示。 |
| V3.2 | 2026-06-23 | 修改 | proj/server/database.py, proj/server/main.py, proj/server/.env.example, .gitignore, proj/doc/production_development_task_plan.md | 完成生产化 T1：后端配置改为环境变量驱动，生产默认禁用 SQLite 自动降级，CORS 改为显式白名单，并补充配置模板、忽略规则和任务记录。 |
| V3.3 | 2026-06-23 | 修改 | proj/server/alembic.ini, proj/server/alembic/, proj/server/requirements.txt, proj/server/main.py, proj/app/lib/db/local_db.dart, proj/app/test/local_db_migration_test.dart, proj/app/pubspec.yaml, proj/app/pubspec.lock, proj/doc/production_development_task_plan.md | 完成生产化 T8（前置）：引入 Alembic 基线迁移，移除后端启动自动建表，补充 App SQLite v1 到 v2 迁移测试并完成验证记录。 |
| V3.4 | 2026-06-23 | 修改 | proj/server/main.py, proj/server/schemas.py, proj/web/src/api.ts, proj/web/.env.example, proj/app/lib/config/api_config.dart, proj/app/lib/screens/home_screen.dart, proj/app/lib/screens/detail_screen.dart, proj/app/lib/screens/sync_screen.dart, proj/app/lib/screens/settings_screen.dart, proj/doc/production_development_task_plan.md | 完成生产化 T1.5：业务 API 统一迁移到 `/api/v1`，同步协议增加 App/schema 版本并返回不兼容提示，Web/App 客户端统一使用版本化 API 基础路径。 |
| V3.5 | 2026-06-23 | 修改 | proj/server/auth.py, proj/server/models.py, proj/server/schemas.py, proj/server/main.py, proj/server/alembic/versions/20260623_1348_add_admin_users.py, proj/server/.env.example, proj/doc/production_development_task_plan.md | 完成生产化 T2 后端部分：新增管理员账号表、PBKDF2 密码哈希、JWT 登录签发和写接口鉴权，并补充 Antigravity Web 登录对齐说明。 |
| V3.6 | 2026-06-23 | 修改 | proj/web/src/api.ts, proj/web/src/router/index.ts, proj/web/src/views/Login.vue, proj/web/src/App.vue, proj/doc/production_development_task_plan.md | 完成生产化 T2 Web部分：新增暗黑磨砂玻璃风格登录页，配置路由守卫未登录跳转，全局 Axios 请求头携带 Bearer Token 并拦截 401 自动清理跳转；更新 App.vue 侧边栏/顶栏布局分支，添加顶部用户信息与登出下拉菜单；清空写操作 API 中所有内存 Mock Fallback 确保异常真实抛出，并通过编译打包校验。 |
| V3.7 | 2026-06-23 | 修改 | proj/server/models.py, proj/server/schemas.py, proj/server/main.py, proj/server/alembic/versions/20260623_1410_add_authorized_devices.py, proj/web/src/api.ts, proj/web/src/router/index.ts, proj/web/src/App.vue, proj/web/src/views/Devices.vue, proj/doc/production_development_task_plan.md | 完成生产化 T3：后端新增授权设备表、管理接口与白名单校验；Web端在 api.ts 对接设备 CRUD 接口，在 router 注册设备管理路由，更新 App.vue 侧边栏菜单与映射，并新增 Devices.vue 设备授权控制界面以支持新增设备、状态开关切换及软禁用，均通过打包校验。 |
| V3.8 | 2026-06-23 | 修改 | doc/项目环境搭建与调试指南_20260621_V1.0.md | 更新环境搭建与调试指南：补充后端环境变量、Alembic 迁移、`/api/v1` 地址、Web 登录和设备授权后的联调测试步骤。 |
