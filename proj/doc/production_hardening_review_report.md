# 生产落地加固指南与任务规划评审报告（修订版）

* **初版评审者**：Antigravity / Gemini 3.5 Flash
* **修订评审者**：Claude Opus 4.6
* **评审对象**：[production_hardening_guide.md](file:///e:/ww/sz work/item_intelli/proj/doc/production_hardening_guide.md)、[production_development_task_plan.md](file:///e:/ww/sz work/item_intelli/proj/doc/production_development_task_plan.md)

---

## 0. 总体评价

两份原始文档的质量相当高。加固指南对 MVP 到生产之间的差距做了系统性的覆盖，任务规划则把加固指南中的每一项 P0/P1/P2 要求准确地转化成了可执行的开发任务书，Agent 分工大方向（Codex 负责后端核心/App 逻辑，Antigravity 负责 Web/UI）也是合理的。

以下仅指出**确实需要修改或补充**的问题，不再重复原文已经做对的部分。

---

## 1. 任务排序问题（确认需要调整）

### 1.1 ✅ Alembic 迁移（T8）必须提前到 T1 之后

> [!IMPORTANT]
> 这是 Gemini 评审报告中最正确、最重要的一条建议。

**问题**：当前 T8 排在 Sprint 1 末尾。但 T2（AdminUser 表）、T3（AuthorizedDevice 表）、T5（operators 表）、T6（processed_sync_logs / local_log_id 唯一约束）总共引入了至少 4 张新表和多个字段变更。如果在这些全部完成后才引入 Alembic，就需要把所有变更补写成一个巨大的初始迁移脚本，既容易遗漏又无法逐步回滚。

**调整**：将 T8 移到 T1 之后、T2 之前。先对当前 MVP 的 schema 生成 Alembic 基线迁移，后续每个涉及数据库变更的任务（T2/T3/T5/T6/T7）各自附带 Alembic 迁移脚本，形成"一个任务一个迁移"的纪律。

### 1.2 ⚠️ 移除 Web 写操作 Mock（T16）应提前，但不必完全合并到 T2

**问题**：Gemini 评审建议把 T16 整体合并到 T2。这个方向对，但过于激进——Sprint 1 开发期间 Antigravity 可能需要在后端尚未完全稳定时独立开发 Web 页面，读操作的 Mock 降级在开发阶段仍有价值。

**调整**：
* **写操作 Mock 降级**：在 T2 完成时就必须移除。新增工具、修改库存、字典维护等写操作在后端报错时必须弹出错误，不能静默假成功。这一点并入 T2 的 Web 开发要求。
* **读操作 Mock 降级**：保留到 Sprint 2 末尾，但必须在页面顶部显示醒目的「⚠ 当前为离线演示数据」横幅。这项可作为 Sprint 2 中一个小任务处理。
* T16 作为独立任务从 Sprint 3 删除，拆分后分别并入 T2 和 Sprint 2 收尾。

---

## 2. 遗漏任务（Gemini 评审也未发现）

### 2.1 🔴 API 版本化（加固指南 P0）没有对应的开发任务

> [!CAUTION]
> 这是最严重的遗漏：加固指南第 2.6 节和 Sprint 1 路线图均将「API 版本化」列为 P0 上线阻断项，但 [production_development_task_plan.md](file:///e:/ww/sz work/item_intelli/proj/doc/production_development_task_plan.md) 的 T1~T21 中**没有任何一个任务**覆盖了 API 版本化的工作。

**具体缺失内容**：
1. 将所有 API 路径从 `/sync`、`/tools`、`/accessories` 等迁移到 `/api/v1/sync`、`/api/v1/tools`、`/api/v1/accessories`。
2. 同步请求携带 `app_version` / `schema_version`。
3. 服务端对不兼容版本返回明确错误和升级提示。
4. Web 前端和 App 端同步更新 API 基础路径。

**建议**：新增 **T1.5（API 版本化）** 或并入 T1 的开发要求。这个改动影响所有端的 API 路径，越早做越好——如果等到 Sprint 2 再改路径，前面所有任务写好的接口调用全部要改一遍。

---

## 3. 技术实现细节补充（值得采纳但非架构性问题）

以下是 Gemini 评审提出的技术建议，我逐条给出是否采纳的判断：

### 3.1 ⚠️ `local_log_id` 应强制为 UUID — 采纳，作为 T6 实现细节明确

**Gemini 原文**：担心 `local_log_id` 如果用自增整数，会在 App 重装或数据库损坏后产生 ID 碰撞。

**我的判断**：方向正确。T6 原文已经说"由 App 生成"但没指定格式。建议在 T6 的开发要求中明确补一句：

> `local_log_id` 使用 UUID v4 格式，由 App 在产生操作日志时即时生成，不得使用自增整数。

这不改变任务结构，只是在 T6 中增加一条实现约束。

### 3.2 ⚠️ 并发锁排序防死锁 — 采纳，作为 T6 实现细节明确

**Gemini 原文**：多设备并发 `SELECT ... FOR UPDATE` 无序可能死锁。

**我的判断**：技术上正确，但在这个项目的实际场景下（库房局域网、几台手持机、同步频率低）死锁概率极低。不过加一条排序规则的实现成本也极低，值得作为防御性编程纳入。建议在 T6 后端开发要求中补充：

> 回放同步日志前，先提取本批次涉及的所有工具 code 和配件 ID，按升序排序后再依次加锁。

### 3.3 ❌ 设备授权引入 Device Token — 不采纳

**Gemini 原文**：UUID 明文可被抓包伪造，应引入 Device Secret Token。

**我的判断**：**在当前部署场景下不建议采纳**。理由如下：

1. **部署环境是库房局域网**，不是公网。威胁模型是内部员工，不是外部攻击者。
2. Device Token 本质上也是一个静态密钥随每次请求发送——如果攻击者能抓包拿到 UUID，同样能抓到 Token。两者在没有 TLS 的明文 HTTP 下安全等级相同。
3. 加固指南 2.7 节已经建议了正确的解法：「正式部署建议加 HTTPS/TLS；至少内网 Nginx 反代」。**TLS 才是正道**，Device Token 是额外的复杂度但不能替代 TLS。
4. 引入 Token 会增加设备激活流程的复杂度（生成、展示、扫码/录入、存储、轮换），对库房一线操作人员不友好。

**替代建议**：维持当前 T3 的 UUID 白名单设计。在部署指南中强调：生产环境必须启用 Nginx + TLS 反代（即使是自签名证书），确保同步包不在局域网明文传输。

### 3.4 ℹ️ 时区显示规范 — 无需单独列出

**Gemini 原文**：应明确"存储和传输用 UTC，展示用本地时区"。

**我的判断**：这是正确的，但属于常规工程实践，不算是原文档的"漏洞"。T7 已经写了"全部服务端时间统一 UTC timezone-aware"，前端按本地时区展示是任何前端框架的默认行为。如果要加，在 T7 中补一句即可，不需要作为独立评审项。

---

## 4. Agent 分工细化（部分采纳）

Gemini 评审对跨端任务的分工划界做了一些有价值的细化，我逐条确认：

### 4.1 ✅ T2（Web 登录 + JWT）分工划界 — 采纳

原任务已经标注"Codex 负责后端，Antigravity 负责 Web"，但 Gemini 补充了两个有用的细节：
* Codex 在后端启动时应判断用户表为空则根据 `.env` 自动初始化管理员（避免初始部署时的鸡生蛋问题）。
* Antigravity 负责全局 401 拦截器。

这些属于原任务开发要求的合理补充。

### 4.2 ✅ T5（操作人 PIN）分工补充 — 采纳

**Gemini 指出了一个真实的遗漏**：T5 把全部工作都分给了 Codex，但 Web 端的基础数据维护页面（`Dictionaries.vue`）也需要支持人员 PIN 的设置和维护。这部分 UI 工作应该明确分配给 Antigravity。

### 4.3 ✅ T11（报废）、T14（同步日志）分工细化 — 采纳

原任务只写了"Codex + Antigravity"但没有划界。Gemini 的划分方式（Codex 负责后端逻辑和 App 端拦截，Antigravity 负责 Web 页面和交互）是合理的，与整体分工原则一致。

---

## 5. 验证命令偏弱（原评审未提及）

> [!WARNING]
> 两份文档都没提到这个问题。

Task Plan 中多个任务的验证命令仅包含**静态编译检查**，例如：

```powershell
python -m py_compile database.py main.py models.py schemas.py sync.py
```

```powershell
npm run build
```

这些只能验证语法正确，无法验证业务逻辑。对于 T6（同步幂等/并发）这样的核心任务，仅靠 `py_compile` 是不够的。

**建议在 T6、T7 等高风险任务中补充运行时验证**，例如：
* 启动后端后 `curl` 测试重复同步是否幂等。
* 或者在 T21（测试体系）中明确要求：T6/T7 完成后，必须先编写对应的 `pytest` 测试用例，再标记任务完成。

这不需要改变任务结构，只需要在相关任务的"验收标准"小节补充说明。

---

## 6. 修订后的 Sprint 路线图

基于以上评审，建议对 [production_development_task_plan.md](file:///e:/ww/sz work/item_intelli/proj/doc/production_development_task_plan.md) 做以下调整：

### Sprint 1：上线阻断项（调整后顺序）

| 顺序 | 任务 | 调整说明 | 执行者 |
| :---: | :--- | :--- | :--- |
| 1 | **T1：后端配置安全化 + 禁用 SQLite 降级** | 不变 | Codex |
| 2 | **T8：引入 Alembic 迁移管理** | 🔥 **从末尾提前至此** | Codex |
| 3 | **T-新：API 版本化** | 🔴 **新增任务**，所有路径迁移到 `/api/v1/`，App 同步携带 `app_version` | Codex |
| 4 | **T2：Web 登录 + JWT 鉴权**（含写操作 Mock 移除） | ⚠️ **并入 T16 的写操作部分** | Codex（后端）+ Antigravity（Web） |
| 5 | **T3：设备授权白名单 + Web 设备管理页** | 不变，维持 UUID 白名单方案 | Codex（后端）+ Antigravity（Web） |
| 6 | **T4：App 终端 UUID 自动生成** | 不变 | Codex |
| 7 | **T5：操作人 PIN 认证** | ⚠️ **补充 Antigravity 负责 Web 端 PIN 维护** | Codex（后端/App）+ Antigravity（Web PIN 表单） |
| 8 | **T6：同步事务、幂等、部分成功** | ⚠️ **补充 local_log_id 必须 UUID v4，加锁前按 code 升序排序** | Codex |
| 9 | **T7：数据模型约束、时区、输入校验** | 不变 | Codex |

### Sprint 2：正式运行前（基本不变）

| 顺序 | 任务 | 调整说明 | 执行者 |
| :---: | :--- | :--- | :--- |
| 10 | **T9：真实 Excel 批量导入** | 不变 | Codex（后端）+ Antigravity（Web） |
| 11 | **T10：真实 Excel 报表导出** | 不变 | Codex（后端）+ Antigravity（Web） |
| 12 | **T11：报废流程** | ⚠️ **细化分工边界** | Codex（后端/App）+ Antigravity（Web 报废页） |
| 13 | **T12：孤儿设备工具状态强制复位** | 不变 | Codex（后端）+ Antigravity（Web） |
| 14 | **T13：归还周期预警与驾驶舱补齐** | 不变 | Antigravity（Web）+ Codex（后端） |
| 15 | **T14：同步日志生产化** | ⚠️ **细化分工边界** | Codex（后端）+ Antigravity（Web 管理页） |
| 16 | **T15：健康检查、版本接口** | 不变 | Codex（后端）+ Antigravity（Web 状态） |
| 17 | **读操作 Mock 降级清理 + 离线横幅** | ⚠️ **T16 拆分后的剩余部分** | Antigravity |

### Sprint 3：稳定运行增强（不变）

| 顺序 | 任务 | 执行者 |
| :---: | :--- | :--- |
| 18 | **T17：工具列表分页与履历独立接口** | Codex |
| 19 | **T18：审计日志全覆盖** | Codex |
| 20 | **T19：App 本地数据保护与日志导出** | Codex |
| 21 | **T20：App 发布和更新流程** | Codex |
| 22 | **T21：测试体系替换** | Codex |

---

## 7. 总结：需要对原文档做的修改清单

| 编号 | 修改内容 | 影响文档 | 紧迫度 |
| :---: | :--- | :--- | :---: |
| 1 | **T8（Alembic）移到 T1 之后** | task_plan | 🔴 高 |
| 2 | **新增 API 版本化任务**（加固指南 P0 遗漏项） | task_plan | 🔴 高 |
| 3 | **T16 写操作 Mock 移除并入 T2**，读操作部分降到 Sprint 2 末尾 | task_plan | 🟡 中 |
| 4 | **T5 补充 Antigravity 负责 Web 端 PIN 维护** | task_plan | 🟡 中 |
| 5 | **T6 补充 local_log_id 必须 UUID v4 + 加锁排序** | task_plan | 🟡 中 |
| 6 | **T11/T14 细化 Agent 分工边界** | task_plan | 🟢 低 |
| 7 | 高风险任务验证命令补充运行时测试说明 | task_plan | 🟢 低 |
| 8 | 加固指南无需修改 | hardening_guide | — |

> [!NOTE]
> **加固指南（hardening_guide）整体质量很好，无需修改。** 所有调整集中在 task_plan 上——主要是排序优化、一个遗漏任务的补充、以及若干任务内部实现细节的澄清。原文档的架构设计、优先级划分和总体开发原则都是正确的。
