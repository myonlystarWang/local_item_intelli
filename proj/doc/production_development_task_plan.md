# 精密工具智能化管理系统生产化开发任务规划

* **版本**：V1.1
* **日期**：2026-06-23
* **依据文档**：`proj/doc/production_hardening_guide.md`、`proj/PRD.md`、`doc/系统测试问题优化方案_20260621_V1.0.md`
* **适用对象**：Codex（ChatGPT 5.5）、Antigravity（Gemini 3.5 Flash）等代码开发 agent
* **目标**：把当前 MVP 测试版本推进到可小规模生产试运行版本。本文不是讨论清单，而是可直接拆给 agent 执行的开发任务书。

---

## 0. 总体开发原则

1. **先安全和数据一致性，再补业务体验**：账号、设备授权、同步事务、迁移能力优先于报表和 UI 优化。
2. **每个任务必须包含测试或验证命令**：不能只改代码不验证。
3. **保持 MVP 已有流程可用**：Web 建档、App 扫码/手动录入、出库、地点变更、维保、同步不能被打断。
4. **生产配置不能再依赖开发 fallback**：生产环境不得静默降级 SQLite，不得写操作 Mock 成功。
5. **不要一次性大重构**：任务按 Sprint 串行落地，每个任务改动可独立验证。

---

## 1. Agent 分工建议

| Agent | 建议负责 | 原因 |
| :--- | :--- | :--- |
| Codex / ChatGPT 5.5 | 后端 FastAPI、数据库模型、迁移、同步算法、Flutter 本地库、测试 | 更适合严谨代码改造和跨文件一致性 |
| Antigravity / Gemini 3.5 Flash | Web 页面、表单、台账、报表交互、UI 补齐、说明文档 | 更适合快速搭建管理端页面和交互 |
| Codex 优先 | 鉴权、并发事务、幂等、迁移、测试 | 这些属于高风险核心逻辑 |
| Antigravity 优先 | 登录页、设备管理页、报表页面、驾驶舱视图 | 这些以 UI/CRUD 为主 |

> 如果只能给一个 agent：优先给 Codex 执行 Sprint 1；Sprint 2 的页面和报表可以再给 Antigravity。

---

## 2. Sprint 1：上线阻断项

### T1. 后端配置安全化与生产禁用 SQLite 降级

**建议执行者**：Codex

**目标**

生产环境必须显式配置数据库、JWT 密钥、CORS 白名单。PostgreSQL 连接失败时，生产服务启动失败，不允许自动写入本地 SQLite。

**涉及文件**

* `proj/server/database.py`
* `proj/server/main.py`
* `proj/server/.env.example`（新增）
* `.gitignore`

**开发要求**

1. 增加 `.env.example`，包含：
   * `DATABASE_URL`
   * `JWT_SECRET_KEY`
   * `ALLOWED_ORIGINS`
   * `ALLOW_SQLITE_FALLBACK=false`
2. `database.py` 读取环境变量。
3. 仅当 `ALLOW_SQLITE_FALLBACK=true` 时允许降级 SQLite。
4. 生产默认不允许 fallback。
5. CORS 从 `ALLOWED_ORIGINS` 读取，禁止 `allow_origins=["*"]`。

**验收标准**

* 未设置 `DATABASE_URL` 且未允许 fallback 时，服务启动失败并输出明确错误。
* 设置 `ALLOW_SQLITE_FALLBACK=true` 时，本地开发仍能使用 SQLite。
* `.env`、`*.db`、日志文件不会入库。

**验证命令**

```powershell
cd "E:\ww\sz work\item_intelli\proj\server"
python -m py_compile database.py main.py models.py schemas.py sync.py
```

**修改记录**

* 2026-06-23 12:44：完成 T1。新增 `.env.example`，后端启动读取环境变量；生产默认禁止 SQLite fallback；CORS 改为读取 `ALLOWED_ORIGINS` 并拒绝 `*`；补充 `.env`、SQLite、日志忽略规则。

---

### T8（前置）. Alembic 迁移 + App SQLite 迁移测试

**建议执行者**：Codex

**目标**

在任何新增表、字段或约束前先建立迁移基线，后续每个涉及 schema 的任务都必须随任务提交迁移脚本，避免 Sprint 1 末尾再补一个不可审计的大迁移。

**涉及文件**

* `proj/server/alembic/`（新增）
* `proj/server/alembic.ini`（新增）
* `proj/server/models.py`
* `proj/app/test/local_db_migration_test.dart`（新增）

**开发要求**

1. 引入 Alembic。
2. 基于当前 MVP schema 生成初始基线迁移。
3. 后续 T2/T3/T5/T6/T7/T13 等表结构变更必须各自附带迁移脚本。
4. App 每次修改 SQLite schema 必须提升版本，并补充旧 schema 到新 schema 的迁移测试。
5. 任务交付说明中必须列出数据库迁移文件名、升级路径和回滚风险。

**验收标准**

* 空 PostgreSQL 库执行迁移成功。
* 已有旧库升级不丢 `tools/accessories/local_logs/settings`。
* 新增表、字段、唯一约束、CHECK 约束不再依赖 `Base.metadata.create_all()` 隐式创建。

**修改记录**

* 2026-06-23 13:13：完成 T8（前置）。新增 Alembic 配置、基线迁移和后端依赖清单；移除服务启动时 `Base.metadata.create_all()` 自动建表；开放 App SQLite schema 创建/迁移回调用于测试；新增 v1 升级 v2 不丢数据测试，并完成后端迁移与 App 测试验证。

---

### T1.5. API 版本化与离线兼容基线

**建议执行者**：Codex

**目标**

所有业务 API 在 Sprint 1 开始阶段统一迁移到 `/api/v1` 前缀，App 同步请求携带客户端版本和本地 schema 版本，避免后续任务完成后再批量改路径。

**涉及文件**

* `proj/server/main.py`
* `proj/server/schemas.py`
* `proj/server/sync.py`
* `proj/web/src/api.ts`
* `proj/web/.env.example`
* `proj/app/lib/config/api_config.dart`（新增）
* `proj/app/lib/screens/home_screen.dart`
* `proj/app/lib/screens/detail_screen.dart`
* `proj/app/lib/screens/settings_screen.dart`
* `proj/app/lib/screens/sync_screen.dart`
* `proj/app/lib/db/local_db.dart`

**开发要求**

1. 所有业务接口迁移到 `/api/v1`，例如：
   * `/api/v1/sync`
   * `/api/v1/tools`
   * `/api/v1/accessories`
   * `/api/v1/dictionaries/items`
   * `/api/v1/auth/login`
2. 同步请求增加：
   * `app_version`
   * `schema_version`
3. 服务端维护当前支持的最小 App/API/schema 版本，不兼容时返回明确错误码和升级提示。
4. Web `VITE_API_BASE_URL` 和 App 同步配置统一指向版本化基础路径。
5. 除 `/health`、`/version` 等运维接口可明确例外外，后续任务中写到的裸路径如 `/sync`、`/tools` 均视为业务短名，实际实现必须挂载在 `/api/v1` 下。

**验收标准**

* Web 和 App 均通过 `/api/v1` 调用业务接口。
* 旧路径不再作为生产入口；如保留兼容转发，必须有明确弃用注释。
* 版本不兼容时 App 能看到明确失败原因，本地待同步日志不丢失。

**修改记录**

* 2026-06-23 13:35：完成 T1.5。后端业务路由统一挂载 `/api/v1`，同步请求增加 `app_version/schema_version` 并对不兼容客户端返回 426；Web 默认 API 基础路径改为 `VITE_API_BASE_URL` 指向 `/api/v1`；App 新增 API 配置 helper，首页心跳、手动同步、自动同步和设置页统一使用版本化路径。

---

### T2. Web 库管员登录 + JWT 鉴权

**建议执行者**：Codex 负责后端，Antigravity 负责 Web

**目标**

Web 管理端必须登录后才能访问台账、字典、配件、设备、报表等页面；写操作必须携带 JWT，且后端不可用时不能回退为前端 Mock 假成功。

**涉及文件**

* `proj/server/models.py`
* `proj/server/schemas.py`
* `proj/server/main.py`
* `proj/server/auth.py`（新增）
* `proj/server/alembic/versions/20260623_1348_add_admin_users.py`（新增）
* `proj/server/.env.example`
* `proj/web/src/views/Login.vue`（新增）
* `proj/web/src/router/index.ts`
* `proj/web/src/api.ts`
* `proj/web/src/App.vue`

**后端开发要求**

1. 新增 `AdminUser` 表：
   * `id`
   * `username`
   * `password_hash`
   * `role`
   * `is_active`
   * `created_at`
2. 新增 `POST /api/v1/auth/login`。
3. 新增 JWT 签发和校验。
4. 后端启动时如果 `AdminUser` 表为空，可根据环境变量初始化第一个管理员，避免初始部署时无法登录：
   * `INITIAL_ADMIN_USERNAME`
   * `INITIAL_ADMIN_PASSWORD`
5. 初始化逻辑必须只在用户表为空时执行，且生产环境必须要求显式配置初始密码。
6. 所有写接口加鉴权：
   * `POST /tools`
   * `POST /accessories`
   * `POST /accessories/adjust`
   * `POST/PUT/DELETE /dictionaries/items`
   * 后续设备管理、报废、强制复位接口

**Web 开发要求**

1. 新增 `Login.vue`。
2. 路由守卫：无 token 跳转 `/login`。
3. Axios 请求自动带 `Authorization: Bearer <token>`。
4. 收到 401 自动清 token 并回登录页。
5. 顶部显示当前登录用户和退出按钮。
6. 删除所有写操作 Mock fallback：
   * createTool
   * createAccessory
   * adjustAccessoryStock
   * create/update/deleteDictionaryItem
   * 后续 devices/scrap/reset/report 等写操作
7. 写操作后端失败时必须弹出错误并保持原页面数据，不得写入内存 Mock 或显示成功。

**验收标准**

* 未登录访问 `/dashboard` 自动跳 `/login`。
* 未带 token 调用写接口返回 401。
* 登录后能正常访问原有页面和执行写操作。
* 停掉后端后执行新增配件或新增工具，页面提示失败，不显示假成功数据。

**验证命令**

```powershell
cd "E:\ww\sz work\item_intelli\proj\web"
npm run build
```

**后端完成记录**

* 2026-06-23 13:44：Codex 完成后端部分。新增 `AdminUser`、PBKDF2 密码哈希、JWT 签发/校验、`POST /api/v1/auth/login`、初始管理员环境变量初始化、AdminUser Alembic 迁移；`POST /tools`、`POST /accessories`、`POST /accessories/adjust`、`POST/PUT/DELETE /dictionaries/items`、`POST /dictionaries/wellbores` 已加管理员 JWT 鉴权。已验证：无 token 写接口 401；登录成功返回 token；带 Bearer token 写接口成功。

**Antigravity Web 对齐说明**

* Web 调用 `POST /api/v1/auth/login`，请求体为 `{ "username": "...", "password": "..." }`；响应包含 `access_token/token_type/expires_in/user`。
* 登录后保存 `access_token` 和 `user`，后续写请求统一加请求头 `Authorization: Bearer <access_token>`。
* Axios 增加 401 拦截：清理本地 token/user，跳转 `/login`，并展示登录过期或未登录提示.
* 路由守卫覆盖 Dashboard、生命周期、配件、字典等管理页；无 token 访问时跳转 `/login`。
* 所有写操作 Mock fallback 必须删除；后端返回 401/4xx/5xx 时展示错误并保持页面数据不伪造成功。

**Web 完成记录**

* 2026-06-23 13:58：Antigravity 完成 Web 部分。新增 `Login.vue` 暗黑磨砂玻璃登录页面；在 `router/index.ts` 新增路由前置守卫实现未登录重定向与登录后反向拦截；在 `api.ts` 新增 `/auth/login` 请求方法，配置 Axios 请求拦截器自动附加 `Authorization: Bearer <token>`，响应拦截器全局提示接口报错并在 401 时自动清理 LocalStorage 且安全跳回登录页；删除了所有写接口的 Mock Fallback 逻辑，由全局响应拦截器抛出异常；在 `App.vue` 优化支持 plainLayout 空白布局与 Header 右上角管理员信息下拉菜单及登出确认。已验证：执行 `npm run build` 打包构建成功，所有写接口无 token 或网络中断时页面能正确弹窗报错并保留现场数据。

---

### T3. 设备授权白名单 + Web 设备管理页

**建议执行者**：Codex 后端，Antigravity Web

**目标**

只有授权且启用的手持终端 UUID 可以同步。Web 端可管理设备启用/禁用。

**涉及文件**

* `proj/server/models.py`
* `proj/server/schemas.py`
* `proj/server/main.py`
* `proj/server/sync.py`
* `proj/server/alembic/versions/20260623_1410_add_authorized_devices.py`（新增）
* `proj/web/src/views/Devices.vue`（新增）
* `proj/web/src/router/index.ts`
* `proj/web/src/App.vue`
* `proj/web/src/api.ts`

**后端开发要求**

1. 新增 `AuthorizedDevice` 表：
   * `uuid`
   * `name`
   * `is_active`
   * `registered_at`
   * `last_sync_at`
   * `remark`
2. 新增接口：
   * `GET /api/v1/devices`
   * `POST /api/v1/devices`
   * `PATCH /api/v1/devices/{uuid}`
   * `DELETE /api/v1/devices/{uuid}`（软禁用设备）
3. `/api/v1/sync` 开始处理前校验设备：
   * 不存在：403
   * 已禁用：403
   * 通过后更新 `last_sync_at`

**Web 开发要求**

1. 新增侧边栏菜单「终端设备授权」。
2. 页面支持：
   * 设备列表
   * 新增设备 UUID 和名称
   * 启用/禁用开关
   * 最近同步时间展示
3. 所有操作需要 JWT。

**验收标准**

* 未登记 UUID 调用 `/sync` 返回 403。
* 禁用设备调用 `/sync` 返回 403。
* 启用设备可同步成功。

**后端完成记录**

* 2026-06-23 14:19：Codex 完成后端部分。新增 `AuthorizedDevice` 表和 Alembic 迁移；新增 `GET/POST/PATCH/DELETE /api/v1/devices`，设备管理接口均要求管理员 JWT；`DELETE` 实现为软禁用；`/api/v1/sync` 在处理日志前校验 `terminal_uuid` 是否登记且启用，未登记/禁用返回 403，启用同步成功后更新 `last_sync_at`。已验证：无 token 访问设备列表 401；未登记设备同步 403；禁用设备同步 403；启用设备同步 200 且更新最近同步时间。

**Antigravity Web 对齐说明**

* 新增「终端设备授权」菜单和 `Devices.vue` 页面；该页面需要登录后访问，沿用 T2 的 Bearer token。
* API 对接：
  * `GET /api/v1/devices`：获取设备列表。
  * `POST /api/v1/devices`：请求体 `{ "uuid": "...", "name": "...", "remark": "..." }`。
  * `PATCH /api/v1/devices/{uuid}`：可提交 `{ "name": "...", "is_active": true/false, "remark": "..." }` 的任意子集。
  * `DELETE /api/v1/devices/{uuid}`：软禁用设备，等价于将 `is_active=false`。
* 页面字段展示：UUID、名称、启用状态、登记时间、最近同步时间、备注。
* UI 行为建议：新增设备弹窗；启用/禁用开关走 `PATCH`；删除/禁用操作需要二次确认；403/401/400 错误交给全局 Axios 拦截器或页面 toast 展示。
* App 端当前仍可能默认使用 `terminal-handheld-001`；在 T4 完成前，现场测试可先在 Web 设备页登记当前 App 设置页里的终端 UUID。

**Web 完成记录**

* 2026-06-23 14:32：Antigravity 完成 Web 部分。新增 `Devices.vue` 设备授权页面，并配置路由、在 `App.vue` 中引入 `Cpu` 图标及侧边栏“终端设备授权”菜单与页面标题；在 `api.ts` 中新增了对接 `/api/v1/devices` 的 CRUD 4个接口请求方法和 `AuthorizedDevice` 结构定义，接口无 Mock fallback 行为直接暴露错误；设备页提供了新增授权终端、一键 Switch 切换状态和软禁用操作二次确认交互，且所有写操作均由拦截器配合弹出网络报错；已通过 `npm run build` 打包构建验证。

---

### T4. App 终端 UUID 自动生成，去除固定默认值

**建议执行者**：Codex

**目标**

每台手持终端首次启动自动生成唯一 UUID，避免所有设备默认都是 `terminal-handheld-001`。

**涉及文件**

* `proj/app/pubspec.yaml`
* `proj/app/lib/db/local_db.dart`
* `proj/app/lib/screens/identity_screen.dart`
* `proj/app/lib/screens/settings_screen.dart`
* `proj/app/lib/screens/sync_screen.dart`

**开发要求**

1. 引入 UUID 生成能力，可用 `uuid` 包。
2. 首次启动如果没有 `terminal_uuid`，生成并保存。
3. 设置页显示 UUID。
4. 生产建议 UUID 默认只读；开发模式可允许手工复制或重置。
5. 同步页不再使用固定默认 `terminal-handheld-001`。

**验收标准**

* 新安装 App 首次启动后 `settings.terminal_uuid` 不为空。
* 多次重启 UUID 不变化。
* 同步请求携带该 UUID。

**验证命令**

```powershell
cd "E:\ww\sz work\item_intelli\proj\app"
E:\flutter\bin\flutter.bat analyze --no-pub
```

---

### T5. 操作人 PIN 认证

**建议执行者**：Codex 负责后端/App，Antigravity 负责 Web PIN 维护

**目标**

移动端不能再仅靠下拉选择声明身份。选择操作人、切换身份、关键操作提交时应至少通过 PIN 验证。

**涉及文件**

* `proj/server/models.py`
* `proj/server/schemas.py`
* `proj/server/main.py`
* `proj/app/lib/db/local_db.dart`
* `proj/app/lib/screens/identity_screen.dart`
* `proj/app/lib/screens/settings_screen.dart`
* `proj/app/lib/screens/detail_screen.dart`
* `proj/app/lib/screens/maintenance_screen.dart`
* `proj/web/src/views/Dictionaries.vue`
* `proj/web/src/api.ts`

**开发要求**

1. 后端新增 `operators` 表或扩展字典结构：
   * `id`
   * `name`
   * `team`
   * `pin_hash`
   * `is_active`
2. Web 基础数据维护页面应能维护人员 PIN、启用状态和所属大队；PIN 只能写入后端哈希，不在接口或页面回显明文。
3. 同步下发人员信息时包含 `operator_id/name/team/pin_hash/is_active`。
4. App 本地新增 `operators` 表。
5. `IdentityScreen` 选择人员后输入 PIN。
6. `SettingsScreen` 切换身份时输入 PIN。
7. 本地日志新增 `operator_id`，保留 `operator_name` 和 `team`。

**验收标准**

* PIN 错误不能进入主页或切换身份。
* 出库/维保日志包含 `operator_id`。
* 同步到 Web 后可按人员 ID 追溯。
* Web 可新增/停用操作人并重置 PIN。

---

### T6. 同步事务、幂等、部分成功和失败日志保留

**建议执行者**：Codex

**目标**

同步接口在并发、重复上传、部分失败时不损坏数据、不丢失败记录。

**涉及文件**

* `proj/server/models.py`
* `proj/server/schemas.py`
* `proj/server/sync.py`
* `proj/app/lib/db/local_db.dart`
* `proj/app/lib/screens/sync_screen.dart`

**后端开发要求**

1. `local_logs` 增加稳定 `local_log_id`，由 App 在产生操作日志时生成 UUID v4，不得使用自增整数或可重复的本地序号。
2. 后端新增 `processed_sync_logs` 或在 `sync_logs` 中记录 `terminal_uuid + local_log_id` 唯一约束。
3. 重复日志直接返回已处理结果，不重复扣减库存或累加寿命。
4. PostgreSQL 下对涉及工具和配件加事务锁；回放同步日志前先提取本批次涉及的工具 code 和配件 ID，按升序排序后再依次加锁，降低并发死锁风险。
5. `SyncResponse.status` 正确返回：
   * 全成功：`success`
   * 有冲突但有成功：`partial_success`
   * 全失败或严重错误：`error`
6. `SyncLogResult` 返回：
   * `local_log_id`
   * `tool_code`
   * `type`
   * `result_code`
   * `text`
   * `time`

**App 开发要求**

1. 本地日志表增加 `local_log_id`，生成规则为 UUID v4。
2. 同步成功后只删除 `result.type == success` 的日志。
3. `conflict/error` 留在本地，并在同步页显示。
4. 增加“导出失败日志”按钮可后续任务实现。

**验收标准**

* 同一日志重复同步两次，不重复扣库存/加寿命。
* 配件不足时，该条日志保留。
* 两台设备重复出库同一工具，只第一条成功。
* 必须补充运行时验证或 pytest 用例覆盖重复同步、配件不足、并发出库三个场景，不能只用 `py_compile` 作为完成标准。

---

### T7. 数据模型约束、时区和输入校验

**建议执行者**：Codex

**目标**

清理会破坏状态机的脏数据入口。

**涉及文件**

* `proj/server/models.py`
* `proj/server/schemas.py`
* `proj/server/sync.py`
* `proj/server/main.py`

**开发要求**

1. 工具状态增加枚举或 CHECK 约束。
2. 全部服务端存储和接口传输时间统一 UTC timezone-aware；Web/App 展示层按本地时区格式化。
3. `parse_time` 失败时返回日志级错误，不使用当前时间替代。
4. `Dictionary` 增加 `(dict_type, dict_value)` 唯一约束。
5. Pydantic 校验：
   * `lifespan_limit > 0`
   * `safety_stock >= 0`
   * `current_stock >= 0`
   * `qty > 0`
   * `return_days` 范围和 App 保持一致，建议 7-90。

**验收标准**

* 负库存、0 寿命阈值、非法状态无法写入。
* 错误时间格式不会污染同步顺序。
* 必须补充运行时验证或测试用例覆盖非法状态、非法时间、输入下限校验，不能只用静态编译检查作为完成标准。

## 3. Sprint 2：正式运行前功能补齐

### T9. 真实 Excel 批量导入

**建议执行者**：Codex 后端，Antigravity Web

**目标**

替换当前模拟导入，实现真实 `.xlsx` 文件导入工具资产。

**涉及文件**

* `proj/server/main.py`
* `proj/server/schemas.py`
* `proj/web/src/views/Lifecycle.vue`
* `proj/web/src/api.ts`

**开发要求**

1. 后端新增 `POST /tools/batch-import`。
2. 支持上传 `.xlsx`。
3. 校验字段：
   * 工具编码
   * 名称
   * 型号
   * 寿命阈值
   * 初始位置
4. 返回：
   * 总条数
   * 成功条数
   * 失败条数
   * 每条失败原因
5. 前端使用真实文件选择器。
6. 前端展示导入结果表格。

**验收标准**

* 上传模板后真实创建多条工具。
* 重复编码不会导入，并返回失败原因。
* 失败部分不影响其他合法行导入。

---

### T10. 真实 Excel 报表导出

**建议执行者**：Codex 后端，Antigravity Web

**目标**

实现 PRD 要求的三类报表真实导出。

**涉及文件**

* `proj/server/main.py`
* `proj/server/reports.py`（新增）
* `proj/web/src/views/Lifecycle.vue`
* `proj/web/src/api.ts`

**开发要求**

1. 后端新增：
   * `GET /reports/assets`
   * `GET /reports/accessories`
   * `GET /reports/logs`
2. 支持筛选：
   * 日期范围
   * 状态
   * 操作人
   * 大队
   * 工具编码
3. 使用后端生成 `.xlsx` 文件流。
4. 前端点击后真实下载文件。
5. 大数据量至少验证 1 万行导出。

**验收标准**

* 三类报表均可下载。
* 文件可用 Excel 打开。
* 字段符合 PRD 5.1.5。

---

### T11. 报废流程

**建议执行者**：Codex 负责后端/App，Antigravity 负责 Web

**目标**

补全资产生命周期闭环。

**开发要求**

1. Codex：后端工具状态支持“报废”。
2. Codex：仅“在库”工具允许报废。
3. Antigravity：Web 生命周期页面增加“报废”操作。
4. Antigravity：报废弹窗必须填写原因，并展示后端校验错误。
5. Codex：报废写入 `tool_histories` 和审计日志。
6. Codex：App 扫到报废工具时只展示详情，禁止出库/维保/地点变更。

**验收标准**

* 报废工具不再可出库。
* 报废记录出现在履历时间轴。

---

### T12. 孤儿设备工具状态强制复位

**建议执行者**：Codex 后端，Antigravity Web

**目标**

处理手持机丢失、损坏、长期不回库导致工具状态无法恢复的问题。

**开发要求**

1. Web 生命周期详情增加“管理员强制复位”。
2. 仅管理员可操作。
3. 必填：
   * 复位原因
   * 审批人/确认人
4. 后端写入工具状态。
5. 写入 `tool_histories`，类型 `ADMIN_FORCE_RESET`。
6. 写入审计日志。

**验收标准**

* 离库工具可被管理员强制恢复在库。
* 所有强制操作都可追溯。

---

### T13. 归还周期预警与驾驶舱补齐

**建议执行者**：Antigravity Web，Codex 后端

**目标**

Dashboard 不再固定 30 天预警，并补充分队持有量和预警处理能力。

**开发要求**

1. `tools` 增加：
   * `team`
   * `expected_return_days`
2. App 出库同步时上传 `return_days`。
3. Server 写入 `expected_return_days`。
4. Dashboard 超期按 `checkout_time + expected_return_days` 计算。
5. Dashboard 增加：
   * 分队持有量视图
   * 预警快捷处理卡片
   * 查看详情入口

**验收标准**

* 出库设置 7 天，超过 7 天才预警。
* 不同大队持有量正确统计。

---

### T14. 同步日志生产化

**建议执行者**：Codex 负责后端，Antigravity 负责 Web 管理页

**目标**

同步日志可查询、可筛选、可处理，不只是 Dashboard 展示。

**开发要求**

1. Codex：`GET /sync-logs` 支持分页。
2. Codex：支持筛选：
   * 设备 UUID
   * 结果类型
   * 时间范围
   * 工具编码
3. Codex：新增失败日志“已处理”状态和保存接口。
4. Antigravity：Web 增加同步日志管理页或 Dashboard 详情抽屉。
5. Antigravity：页面支持筛选、分页、查看失败原因和标记“已处理”。

**验收标准**

* 能查询最近 180 天日志。
* 能筛选冲突日志。
* 已处理状态可保存。

---

### T15. 健康检查、版本接口、运维状态

**建议执行者**：Codex 负责后端/App，Antigravity 负责 Web 状态展示

**目标**

现场能快速判断服务是否可用、版本是否匹配。

**开发要求**

1. 后端新增：
   * `GET /health`
   * `GET /version`
2. Web 顶部显示 API 连接状态。
3. App 同步页显示：
   * 服务器连接状态
   * 服务器版本
   * 最近同步时间

**验收标准**

* 数据库不可用时 `/health` 返回非 200。
* Web/API 断开时有明确提示。

---

### T15.5. Web 读操作 Mock 降级清理与离线横幅

**建议执行者**：Antigravity

**目标**

保留开发阶段必要的读操作演示能力，但必须让用户明确知道当前不是实时后端数据；生产配置下应默认关闭读操作 Mock 降级。

**涉及文件**

* `proj/web/src/api.ts`
* `proj/web/src/App.vue`
* `proj/web/src/views/Dashboard.vue`
* `proj/web/src/views/Lifecycle.vue`
* `proj/web/src/views/Accessories.vue`
* `proj/web/src/views/Dictionaries.vue`

**开发要求**

1. 读操作 fallback 如需保留，只能在显式开发配置下启用。
2. 页面进入读操作 fallback 时，顶部必须显示醒目的「当前为离线演示数据」横幅。
3. 横幅要覆盖 Dashboard、生命周期、配件、字典等所有可能使用读 Mock 的页面。
4. 生产构建默认不启用读 Mock；后端不可用时显示连接失败或空状态。

**验收标准**

* 停掉后端后，写操作失败提示已由 T2 覆盖。
* 停掉后端后，如读操作使用演示数据，页面顶部可见离线演示横幅。
* 生产环境配置下不会静默展示 Mock 数据。

---

## 4. Sprint 3：稳定运行增强

### T17. 工具列表分页和履历独立接口

**建议执行者**：Codex

**目标**

避免 `/tools` 返回全量履历导致性能问题。

**开发要求**

1. `/tools` 支持分页、状态筛选、关键词搜索。
2. `/tools` 不再默认返回 `histories`。
3. 新增 `GET /tools/{code}/histories`。
4. Web Lifecycle 改用独立履历接口。

**验收标准**

* 1000 条工具列表加载仍流畅。
* 点击某工具才加载该工具履历。

---

### T18. 审计日志全覆盖

**建议执行者**：Codex

**目标**

所有 Web 写操作和管理员强制操作可追踪。

**开发要求**

新增 `audit_logs` 表：

* `id`
* `actor`
* `action`
* `object_type`
* `object_id`
* `before_json`
* `after_json`
* `client_ip`
* `created_at`

覆盖：

* 新建工具
* 新建配件
* 补货
* 字典增删改
* 设备启用/禁用
* 报废
* 强制复位

**验收标准**

* 任意写操作后，都能查到审计记录。

---

### T19. App 本地数据保护和日志导出

**建议执行者**：Codex

**目标**

设备丢失或损坏时降低数据泄露和数据丢失风险。

**开发要求**

1. 评估并引入 SQLite 加密，或至少把该项列为安全增强。
2. 设置页敏感配置加 PIN。
3. 同步页增加“导出待同步日志”。
4. 导出格式 JSON 或 CSV。

**验收标准**

* 无网络时可导出待同步日志文件。
* 导出内容包含足够人工补录字段。

---

### T20. App 发布和更新流程

**建议执行者**：Codex

**目标**

形成可重复的 APK 构建、签名、安装和回滚流程。

**开发要求**

1. 编写 `proj/doc/app_release_guide.md`。
2. 明确：
   * debug 构建命令
   * release 构建命令
   * 签名文件位置和保管要求
   * 版本号修改方法
   * 真机安装命令
   * 回滚方式
3. 可选：提供 PowerShell 脚本。

**验收标准**

* 非开发人员按文档能安装指定 APK。

---

### T21. 测试体系替换

**建议执行者**：Codex

**目标**

删除无效脚手架测试，建立核心业务测试。

**开发要求**

1. 删除或重写 `proj/app/test/widget_test.dart`。
2. 新增 App 测试：
   * 未登记资产拦截
   * 寿命超限禁止出库
   * SQLite 迁移不丢数据
3. 新增后端测试：
   * 重复出库冲突
   * 配件不足失败
   * 重复同步幂等
   * 非授权设备拒绝

**验收标准**

```powershell
cd "E:\ww\sz work\item_intelli\proj\app"
E:\flutter\bin\flutter.bat test
```

后端测试命令由任务执行者补齐，例如：

```powershell
cd "E:\ww\sz work\item_intelli\proj\server"
pytest
```

---

## 5. 部署策略建议

### 5.1 是否必须 Docker 化

**结论：这个小项目第一阶段不必须 Docker 化，但必须标准化部署目录和启动脚本。**

理由：

1. 当前部署目标是库房局域网小规模使用，不是云端弹性扩容。
2. Web + FastAPI + PostgreSQL 的组件数量可控。
3. 团队当前还在 MVP 到生产试运行过渡，先把鉴权、同步一致性、迁移和备份做稳更重要。
4. Docker 会引入镜像构建、卷挂载、网络、证书、日志收集等额外运维概念，对小项目初期可能增加复杂度。

### 5.2 推荐部署方式：非 Docker 标准目录部署

建议服务器目录：

```text
D:\item_intelli\
  app_release\
    item_intelli_v1.0.0.apk
  server\
    main.py
    models.py
    ...
    .env
  web\
    dist\
  data\
    backup\
    logs\
  scripts\
    start_server.ps1
    stop_server.ps1
    backup_db.ps1
```

生产运行方式：

1. PostgreSQL 安装为 Windows 服务。
2. 后端用 `uvicorn` 或 NSSM 注册为 Windows 服务。
3. Web 用 Nginx 或轻量静态服务器托管 `dist`。
4. 数据库每日备份到 `data/backup`。
5. App 用签名 APK 手工安装或批量分发。

### 5.3 最小部署交付物

需要补充这些文件：

| 文件 | 用途 |
| :--- | :--- |
| `proj/server/.env.example` | 生产配置模板 |
| `proj/doc/deployment_guide_windows.md` | Windows 库房服务器部署手册 |
| `proj/doc/app_release_guide.md` | App 打包安装手册 |
| `scripts/start_server.ps1` | 启动后端 |
| `scripts/stop_server.ps1` | 停止后端 |
| `scripts/backup_db.ps1` | 备份 PostgreSQL |

### 5.4 什么时候再考虑 Docker

满足以下任一条件时，再切 Docker：

1. 需要多服务器部署。
2. 需要一键迁移到新机器。
3. 需要统一交付给第三方运维。
4. 后端、Web、数据库版本经常冲突。
5. 需要 CI/CD 自动构建和部署。

届时再补：

* `Dockerfile.server`
* `Dockerfile.web`
* `docker-compose.yml`
* PostgreSQL volume
* Nginx HTTPS 配置

### 5.5 当前不建议“直接拷贝项目源码就上线”

可以拷贝项目文件用于试运行，但不能只拷源码就算部署。至少要做到：

1. 后端依赖固定。
2. `.env` 配置明确。
3. 数据库独立安装并备份。
4. Web 执行 `npm run build` 后部署 `dist`，不要用 Vite dev server 跑生产。
5. App 使用 APK，不用 `flutter run` 当生产安装方式。
6. 服务启动、停止、日志、备份都有脚本。

---

## 6. 给 Agent 的通用交付要求

每个任务完成后，agent 必须返回：

1. 修改文件清单。
2. 数据库变更说明。
3. API 变更说明。
4. App 本地 SQLite 变更说明。
5. 验证命令和结果。
6. 未完成项和风险。

每个任务至少执行：

```powershell
cd "E:\ww\sz work\item_intelli\proj\web"
npm run build
```

```powershell
cd "E:\ww\sz work\item_intelli\proj\app"
E:\flutter\bin\flutter.bat analyze --no-pub
```

```powershell
cd "E:\ww\sz work\item_intelli"
python -m py_compile proj\server\database.py proj\server\models.py proj\server\schemas.py proj\server\sync.py proj\server\main.py
```

如果某个任务不涉及 Web/App/Server，可说明跳过原因。
