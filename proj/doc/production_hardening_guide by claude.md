# 精密工具智能化管理系统 — 生产加固优化建议

> **文档版本**：v2.0（整合版）· 生成日期：2026-06-22
> **审查范围**：`/proj/server/`（FastAPI 后端）、`/proj/web/`（Vue3 前端）、`/proj/app/`（Flutter 移动端）、PRD.md、implementation_plan.md、task.md，以及 `doc/` 目录下全部过程文档
> **定性结论**：当前代码库已完成功能原型闭环，各端核心业务路径跑通，同步冲突解析算法逻辑自洽。但若直接推向生产，存在 **安全、身份与责任认定、数据完整性、产品功能完整性、可靠性、性能** 六个维度的系统性风险，以下按优先级从高到低逐一展开。

---

## 0. 版本变更说明（v1.0 → v2.0）<a name="0"></a>

### 0.1 本次新增 / 更正一览

本版本在 v1.0 的代码级审查基础上，补充了两类内容：

1. **新增发现**：v1.0 主要聚焦"代码已写但有缺陷"的问题（安全配置、并发、时区等）。v2.0 补充了"PRD 要求但代码里其实是假实现/未实现"的**产品功能缺口**（如 Excel 导入导出是纯前端模拟、操作人身份无真实认证、库管员账号体系缺失等），以及移动端分发、孤儿设备处理等运营层面的缺口。
2. **更正撤回一项**：v1.0 §5.2 报告"字典 CRUD 的 PUT/DELETE URL 缺少 id 参数"，经与当前 `proj/web/src/api.ts` 源码逐行核对，`updateDictionaryItem` / `deleteDictionaryItem` 实际已正确携带 `${id}`，**该问题不成立，特此更正**（详见 §5.2）。
3. **核实四项"已实现"功能**：早期测试问题文档（`系统测试问题优化方案`）和审查报告中标记为"待开发/未实现"的四个功能点，经核对当前代码仓库内容，**实际已经实现**（详见 §0.2）。建议团队优先核实这是否与当前生产分支/部署环境一致，而不是重新排期开发，避免重复劳动。

### 0.2 ✅ 经核对，当前代码中已实现的功能（无需重新排期，只需核实部署一致性）

| 功能 | 早期文档中的描述 | 代码证据 | 仍需注意的风险 |
| --- | --- | --- | --- |
| 配件库存台账主表页 | `系统测试问题优化方案 §1.3a`：标记"待开发" | `proj/web/src/views/Accessories.vue` 已存在：列表、低库存徽章、手动建档、补货弹窗均已实现；路由已挂载在 `router/index.ts` | 仍受 §5.1（写操作静默降级 Mock）风险影响 |
| 基础数据维护（井号/大队/人员 CRUD） | `系统测试问题优化方案 §1.3b`：标记"待开发" | `proj/web/src/views/Dictionaries.vue` 已存在，前端调用 `createDictionaryItem`/`updateDictionaryItem`/`deleteDictionaryItem`/`getDictionaryItems`；后端 `main.py` 对应的 `POST/PUT/DELETE /dictionaries/items` 均已实现 | 同上；另外这些写接口目前**无鉴权**（见 §1.2） |
| 真实同步日志（SyncLog）+ 查询接口 | `系统测试问题优化方案 §1.5`：标记"Web 仍是写死假数据" | `server/models.py` 已有 `SyncLog` 表，`sync.py` 在每次同步后真实写入，`main.py` 提供 `GET /sync-logs`，前端 `api.getSyncLogs()` 优先调用真实接口 | 网络异常时仍会**静默**回退到内存 Mock（见 §5.1），库管员无法分辨当前看到的是真实日志还是假数据 |
| App 设置页（服务器 IP / 操作人 / 终端 UUID） | `移动端 App 代码 vs PRD 功能对照审查报告 V2`：标记"❌ 未实现" | `proj/app/lib/screens/settings_screen.dart` 已存在，包含操作人/大队下拉切换、`sync_server_url`、`terminal_uuid` 两个可编辑文本框，保存逻辑完整 | terminal_uuid 默认值仍为固定字符串（见 §6.1），缺少首次启动自动生成机制 |

> **结论**：这四项不需要再立项开发，建议改为"验收测试"任务——确认现在跑在用户手机/服务器上的版本，确实是包含上述代码的那个版本，而不是更早的快照。

---

## 目录

1. [🔴 P0 — 安全加固（上线前必须修复）](#1)
2. [🔴 P0 — 数据完整性加固](#2)
3. [🟠 P1 — 可靠性与容错加固](#3)
4. [🟠 P1 — 性能优化](#4)
5. [🟡 P2 — 前端工程加固](#5)
6. [🟡 P2 — 移动端加固](#6)
7. [🟢 P3 — 工程化与部署基础设施](#7)
8. [🟢 P3 — 可观测性与运维](#8)
9. [🔵 P4 — 测试体系建设](#9)
10. [🔵 P4 — 业务逻辑与产品功能完整性](#10)
11. [优先级汇总路线图](#11)
12. [推荐迭代节奏](#12)

---

## 1. 🔴 P0 — 安全加固（上线前必须修复）<a name="1"></a>

> 本节所有问题属于**上线阻断项**，任意一条被利用都可能导致资产数据泄漏、被篡改，或责任无法追溯到具体人。

### 1.1 CORS 配置过度开放

**位置**：`server/main.py:15-21`

**当前问题**：
```python
# 危险！允许任意来源跨域访问，且与 credentials=True 组合本身不合规
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, ...)
```

**风险**：任何第三方网页均可跨域调用本系统 API，读取全量资产数据。叠加下方"无鉴权"问题，几乎等同于完全公开接口。另外，`allow_origins=["*"]` 与 `allow_credentials=True` 同时出现属于浏览器规范不允许的组合（规范要求二者不能同时生效），目前代码恰好"赖"在没有真正使用 Cookie/Session 鉴权才没暴露出明显故障，一旦后续接入基于 Cookie 的会话鉴权会直接失效，建议现在就修正。

**修复建议**：
```python
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://192.168.120.107").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,      # 从环境变量注入，收缩至库房局域网 IP
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
)
```

---

### 1.2 所有 API 端点无任何鉴权（最高危）

**位置**：`server/main.py` — 全量路由无 `Depends(verify_*)` 依赖注入

**风险**：任何能接入局域网的设备均可无障碍地：
- 读取全部资产和操作历史（`GET /tools`）
- 篡改配件库存（`POST /accessories/adjust`）
- 伪造同步包污染全局总账（`POST /sync`）
- 增删改字典参数（`POST/PUT/DELETE /dictionaries/items`，包括 §0.2 中确认已实现的那一组接口）

**修复建议（最轻量方案 — API Key 静态令牌，用于设备/服务间调用）**：
```python
# server/auth.py
from fastapi import Header, HTTPException
import os, secrets

API_KEY = os.environ["API_SECRET_KEY"]   # 强制从环境变量读取，不允许缺失

async def verify_api_key(x_api_key: str = Header(...)):
    if not secrets.compare_digest(x_api_key, API_KEY):
        raise HTTPException(status_code=401, detail="Unauthorized")
```
```python
# 写操作路由强制鉴权
@app.post("/sync", dependencies=[Depends(verify_api_key)])
def sync_offline_data(...): ...

@app.post("/tools", dependencies=[Depends(verify_api_key)])
def create_tool(...): ...
```

**中期升级方案**：引入 JWT + 库管员账号密码登录（即面向"人"的鉴权，区别于上面面向"设备"的 API Key）。完整落地方案见 **§1.7**。

---

### 1.3 数据库凭证硬编码

**位置**：`server/database.py:8-9`

```python
# 危险！默认弱密码写入源码
"postgresql://postgres:postgres@localhost:5432/item_intelli"
```

**风险**：代码进入版本控制后，任何有仓库权限的人都可直连数据库。

**修复建议**：
```bash
# .env（加入 .gitignore，不提交到 git）
DATABASE_URL=postgresql://app_user:StrongPassword_2026@localhost:5432/item_intelli
API_SECRET_KEY=randomly-generated-32-char-string
ALLOWED_ORIGINS=http://192.168.120.107
```
```python
# database.py — 移除所有默认硬编码
from dotenv import load_dotenv
load_dotenv()
DATABASE_URL = os.environ["DATABASE_URL"]  # 缺失时启动失败，强制配置
```
同时提供 `.env.example` 模板文件供团队参考，但不含真实密码。

---

### 1.4 HTTP 明文通信（无 TLS）

**风险**：局域网内抓包即可获取 terminal_uuid、操作人姓名、工具全量状态，且可以重放同步包伪造数据。

**修复建议**：通过 Nginx 反代开启 HTTPS，内网使用自签名证书：
```nginx
server {
    listen 443 ssl;
    ssl_certificate     /etc/ssl/item_intelli.crt;
    ssl_certificate_key /etc/ssl/item_intelli.key;
    location / { proxy_pass http://127.0.0.1:8000; }
}
```
Flutter 侧将 http:// 改为 https://，高安全要求时配置证书 pin。

---

### 1.5 移动端设备身份无服务端校验 + 设备授权管理页缺失

**位置**：`server/sync.py:14` — `terminal_uuid` 仅由移动端自报，后端完全不验证；PRD §5.1.3 设计的"设备授权管理"页面在 Web 端没有任何对应实现。

**风险**：
- 任何人构造合法格式的 JSON 包即可向同步接口投毒，伪造出库/维保记录。
- 即便补上了白名单表，库管员也没有界面可以**看到**有哪些设备、**启用/禁用**某台设备、查看某台设备**最近同步时间**——这正是 PRD 5.1.3 节明确要求、但目前完全没有落地的功能。

**修复建议 — 分两层落地**：

**① 后端：设备白名单表 + 校验**
```python
# models.py — 新增设备授权白名单表
class AuthorizedDevice(Base):
    __tablename__ = "authorized_devices"
    uuid = Column(String(100), primary_key=True)
    label = Column(String(100))
    is_active = Column(Boolean, default=True)
    registered_at = Column(DateTime, default=datetime.utcnow)
    last_sync_at = Column(DateTime, nullable=True)

# sync.py — 在处理前校验设备，并更新最近同步时间
def process_offline_sync(db, sync_data):
    device = db.query(AuthorizedDevice).filter_by(
        uuid=sync_data.terminal_uuid, is_active=True
    ).first()
    if not device:
        raise HTTPException(status_code=403, detail="未授权设备，拒绝同步")
    device.last_sync_at = utcnow()
    ...
```

**② 后端：管理接口**
```python
@app.get("/devices", response_model=List[schemas.DeviceResponse])
def list_devices(db: Session = Depends(get_db)): ...

@app.post("/devices", dependencies=[Depends(verify_api_key)])
def register_device(item: schemas.DeviceCreate, db: Session = Depends(get_db)): ...

@app.patch("/devices/{uuid}", dependencies=[Depends(verify_api_key)])
def toggle_device(uuid: str, payload: schemas.DeviceToggle, db: Session = Depends(get_db)):
    """启用/禁用设备"""
    ...
```

**③ Web：新增「设备管理」页面 `DeviceManagement.vue`**
- 列表列：UUID、备注名称、状态（启用/禁用开关）、最近同步时间、累计同步次数。
- 操作：新增设备（预登记 UUID + 备注名）、启用/禁用、删除。
- 路由挂载到侧边导航，与现有「配件库存台账」「基础数据维护」并列。

---

### 1.6 无请求频率限制

**修复建议**：
```bash
pip install slowapi
```
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/sync")
@limiter.limit("10/minute")
async def sync_offline_data(request: Request, ...): ...
```

---

### 1.7 🆕 库管员账号体系与登录页缺失

**问题背景**：当前 Web 管理端没有任何登录页（`App.vue` 进入即直达 Dashboard），`§1.2` 提到的 API Key 方案只解决"设备/服务调不调得通"的问题，并不能回答"是谁在操作 Web 后台、做了什么"——这对一个会执行库存调拨、字典增删、设备启停的管理系统而言是不可接受的缺口，也是把 PRD 中"库管员"角色真正落地为可审计身份的前提。

**风险**：任何接入 Web 服务的人都拥有与库管员完全相同的权限；§10.3 提到的审计日志即便补上，`operator` 字段也无从填写（因为系统不知道当前是谁登录的）。

**修复建议（最小可用版本）**：

```python
# models.py
class AdminUser(Base):
    __tablename__ = "admin_users"
    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="warehouse_admin")  # 为后续角色扩展预留
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
```
```python
# auth.py — 密码哈希 + JWT
from passlib.hash import bcrypt
from jose import jwt
from datetime import datetime, timedelta, timezone

SECRET_KEY = os.environ["JWT_SECRET_KEY"]

def create_access_token(username: str) -> str:
    payload = {"sub": username, "exp": datetime.now(timezone.utc) + timedelta(hours=8)}
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

@app.post("/auth/login")
def login(form: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(models.AdminUser).filter_by(username=form.username, is_active=True).first()
    if not user or not bcrypt.verify(form.password, user.password_hash):
        raise HTTPException(status_code=401, detail="用户名或密码错误")
    return {"access_token": create_access_token(user.username), "token_type": "bearer"}
```
```python
# 受保护路由的依赖
async def get_current_admin(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    except JWTError:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录")
    user = db.query(models.AdminUser).filter_by(username=payload["sub"]).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")
    return user
```

**Web 端**：
- 新增 `views/Login.vue`，提交后将 `access_token` 存入内存态（避免 localStorage 被 XSS 窃取，可用 Pinia store，配合短期 token + 刷新机制）。
- `router/index.ts` 增加全局前置守卫，未登录强制跳转 `/login`。
- `axios` 请求拦截器统一注入 `Authorization: Bearer <token>`；收到 401 自动跳转登录页。
- 所有写操作接口（建档、补货、字典增删、设备启停）改为 `Depends(get_current_admin)`，并在审计日志中记录 `user.username`（呼应 §10.3）。

> 即便第一版只支持"一个库管员账号"，也要把账号体系的骨架（表结构、哈希存储、token 校验、登录页、路由守卫）先搭好，后续扩展多角色成本很低；反之现在不做，后续要补审计追溯会非常痛苦。

---

### 1.8 🆕 操作人身份认证缺失（移动端"裸选择，无认证"）

**问题背景**：PRD §3.1 设计的"身份声明"机制，目的是离线环境下也能做到"操作可追溯到具体人"。但当前 `IdentityScreen` / `SettingsScreen` 的实现是**纯下拉选择**——任何人都可以打开 App，选择"张建国"作为当前操作人，此后所有出库、维保记录都会被记成张建国所做，且没有任何验证手段证明操作者真的是张建国本人。这意味着 PRD 反复强调的"责任界定"和"按人员维度统计分析"在当前实现下其实是可以被任意伪造的，一旦发生资产丢失或寿命超期下井等事故，系统记录的"责任人"不具备证据效力。

**风险**：现场多人共用一台终端时，故意或无意选错身份的成本几乎为零；离线场景下也无法靠网络二次确认。

**修复建议（轻量级 PIN 码方案，兼容离线约束）**：

1. **服务端**：在 `operator` 字典基础上扩展为独立的 `Operator` 实体，库管员在 Web「基础数据维护」页为每位操作人设置初始 PIN（如手机号后 4 位，要求首次登录强制修改）：
   ```python
   class Operator(Base):
       __tablename__ = "operators"
       id = Column(Integer, primary_key=True)
       name = Column(String(50), unique=True, nullable=False)
       team = Column(String(100))
       pin_hash = Column(String(255), nullable=False)  # 仅哈希值，绝不下发明文
       is_active = Column(Boolean, default=True)
   ```
2. **同步下发**：`/sync` 响应中追加 `operators` 列表（仅含 `name`/`team`/`pin_hash`/`is_active`），写入移动端本地 SQLite 新表 `operators`。
3. **移动端**：`IdentityScreen` 在选择姓名后增加 4 位 PIN 输入框，本地用同一哈希算法（如 PBKDF2，可用 `dart:crypto`/`pointycastle`）比对 `pin_hash`，通过后才允许写入 `settings.operator_name`。连续 3 次错误锁定 5 分钟并在本地日志中留痕。
4. **高敏感操作二次确认（可选）**：寿命超限尝试出库、批量维保核销等场景，可要求再次输入 PIN 才能提交，进一步强化责任认定的证据链。

> 这不是要做完整的账号密码登录（PRD 明确反对，因为离线环境下没法做服务端实时校验），而是用"本地可验证的轻量凭证"补上当前"纯自报身份、零验证"的漏洞，与 PRD 的设计初衷一致，改动成本可控。

---

### 1.9 🆕 PostgreSQL 连接失败时静默降级为本地 SQLite

**位置**：`server/database.py:16-30`

**当前问题**：
```python
try:
    ...
    with engine.connect() as conn:
        pass
    print(f"成功连接到 PostgreSQL 数据库: {SQLALCHEMY_DATABASE_URL}")
except Exception as e:
    print(f"PostgreSQL 数据库连接不可用 ({e})。自动降级切换至本地 SQLite 数据库...")
    SQLALCHEMY_DATABASE_URL = "sqlite:///./item_intelli.db"
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
```

**风险**：这个设计在本地开发时非常友好（不用先装 PostgreSQL 也能跑），但在生产环境下极其危险：
- 如果后端以多实例/容器方式部署（例如重启时数据库连接尚未就绪、或网络抖动），每个实例会**各自降级到自己容器内的 SQLite 文件**，彼此数据完全割裂，但对外表现仍是"服务正常运行"。
- 唯一的提示只是一行 `print`，生产环境下大概率没人盯着 stdout，故障会在"看起来一切正常"的状态下持续发生，直到某天发现两台服务器的总账不一致才被发现，此时数据已经不可调和。

**修复建议**：
```python
ALLOW_SQLITE_FALLBACK = os.getenv("ALLOW_SQLITE_FALLBACK", "false").lower() == "true"

try:
    engine = create_engine(SQLALCHEMY_DATABASE_URL, pool_pre_ping=True, ...)
    with engine.connect() as conn:
        pass
    logger.info("成功连接到 PostgreSQL 数据库")
except Exception as e:
    if not ALLOW_SQLITE_FALLBACK:
        logger.critical("PostgreSQL 连接失败且未允许降级，服务启动中止: %s", e)
        raise SystemExit(1)   # 生产环境下宁可拒绝启动，也不要静默切库
    logger.warning("PostgreSQL 连接失败，已降级至本地 SQLite（仅限开发环境）: %s", e)
    ...
```
生产部署的 `.env` 中显式设置 `ALLOW_SQLITE_FALLBACK=false`（或直接不设置该变量，使用上面的默认值），让"连不上数据库"变成一次响亮的启动失败，而不是一次安静的状态分裂。

---

## 2. 🔴 P0 — 数据完整性加固<a name="2"></a>

> 本节问题会导致**数据永久错误或丢失**，在并发场景下尤为严重。

### 2.1 同步引擎缺乏原子事务边界（并发双写风险）

**位置**：`server/sync.py:30-186`

**当前问题**：`process_offline_sync` 在循环内逐条操作数据库，最后统一 `db.commit()`。若两台设备**并发**发起同步，两个请求的循环会交错执行，导致：
- 配件库存 `current_stock -= qty` 非原子操作，产生 Lost Update
- 工具 `use_count += 1` 被覆盖，寿命计数丢失

**修复建议**：对本次同步涉及的工具加行级悲观锁：
```python
from sqlalchemy import select

def process_offline_sync(db: Session, sync_data):
    tool_codes = list({log.tool_code for log in sync_data.logs})
    with db.begin():                         # 显式事务
        tools_locked = db.execute(
            select(models.Tool)
            .where(models.Tool.code.in_(tool_codes))
            .with_for_update()               # SELECT ... FOR UPDATE 行锁
        ).scalars().all()
        tool_map = {t.code: t for t in tools_locked}
        # 后续循环使用 tool_map，不再重新查询
        ...
```

---

### 2.2 工具状态字段无数据库枚举约束

**位置**：`server/models.py:12`

```python
# 当前：VARCHAR 无约束，任意字符串均可写入
status = Column(String(20), nullable=False, default="在库")
```

**风险**：Bug 或脏同步包可将 status 写为非法值（含尾空格、英文大写等），导致状态机判断全部失效。

**修复建议**：
```python
import enum
from sqlalchemy import Enum as SAEnum

class ToolStatus(str, enum.Enum):
    IN_STOCK = "在库"
    OUT_STOCK = "离库"
    LOCATION_CHANGED = "地点变更"
    SCRAPPED = "报废"

class Tool(Base):
    status = Column(SAEnum(ToolStatus), nullable=False, default=ToolStatus.IN_STOCK)
```

---

### 2.3 时区不一致导致时序错乱

**位置**：`server/models.py:61`（`datetime.utcnow`）vs `server/main.py` 多处（`datetime.now()`）

**风险**：sync.py 按时间戳排序重演离线日志的核心逻辑依赖时序正确性。混用本地时间和 UTC 时间，在时区不同的设备间同步时会产生错误排序，正确操作被误判为冲突。

**修复建议**：全系统统一使用 UTC timezone-aware datetime：
```python
from datetime import datetime, timezone

def utcnow():
    return datetime.now(timezone.utc)

# 全部替换 datetime.now() 和 datetime.utcnow()
last_update_time = Column(DateTime(timezone=True), nullable=False, default=utcnow)
```
Flutter 端统一使用 UTC 毫秒时间戳：
```dart
"timestamp": DateTime.now().toUtc().millisecondsSinceEpoch,
```

---

### 2.4 时间解析失败静默回退当前时间

**位置**：`server/sync.py:12`

```python
def parse_time(time_str: str) -> datetime:
    ...
    return datetime.now()   # 解析失败时静默返回当前时间，破坏时序
```

**风险**：时钟漂移或异常格式的时间戳会被悄悄替换为服务器当前时间，污染整个排序链，导致原本正确的操作被作为"最晚操作"错误地覆盖其他记录。

**修复建议**：
```python
def parse_time(time_str: str) -> datetime:
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S"):
        try:
            return datetime.strptime(time_str, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    raise ValueError(f"无法解析时间格式: {time_str!r}")   # 明确抛出，上层处理
```
在调用处捕获此异常，将该条日志标记为 `error` 并跳过，保留其他日志继续同步。

---

### 2.5 Dictionary ORM 模型缺少唯一约束声明

**位置**：`server/models.py:49-54`

SQL Schema 中定义了 `UNIQUE(dict_type, dict_value)`，但 SQLAlchemy ORM 模型未声明，`create_all` 时约束可能缺失（取决于 pg 版本行为），且 ORM 层无法利用此约束进行 upsert。这也是当前 `create_dictionary_item` 只能依赖"先查后插"这种存在竞态条件的应用层校验的根本原因——并发请求下仍可能产生重复字典项。

**修复建议**：
```python
from sqlalchemy import UniqueConstraint

class Dictionary(Base):
    __tablename__ = "dictionaries"
    __table_args__ = (UniqueConstraint("dict_type", "dict_value", name="uq_dict_type_value"),)
    ...
```

---

### 2.6 无数据库 Schema 迁移管理

**当前问题**：仅靠 `Base.metadata.create_all()` 建表，无法追踪和安全应用后续字段变更，生产环境升级只能手工执行 DDL，极易遗漏或出错。

**修复建议**：引入 Alembic：
```bash
pip install alembic
alembic init alembic
# 配置 alembic/env.py 指向 models.Base.metadata
alembic revision --autogenerate -m "initial_schema"
alembic upgrade head
```
后续每次修改 models.py，通过 `alembic revision --autogenerate` 生成迁移脚本，code review 后执行。

---

### 2.7 🆕 同步接口缺乏幂等性保护

**位置**：`server/schemas.py` 的 `SyncLogEntry` / `server/sync.py`

**当前问题**：每条离线日志没有任何全局唯一标识（仅有 `timestamp` + `tool_code` 等业务字段），`/sync` 也没有做任何"这批日志是否已经处理过"的判断。

**风险**：野外网络环境下，App 端的 HTTP 请求超时重试是大概率事件（尤其叠加 §3.4 当前 5 秒超时过短的问题）。一旦客户端因为没收到响应而重发同一批日志，服务端会把它们当成全新操作再处理一遍——配件库存被多扣一次、工具寿命 `use_count` 被多加一次，且因为这些"重复操作"在内容上完全合法（不是冲突，是字面意义上的重复），不会被现有的状态锁机制拦截。

**修复建议**：
1. 移动端为每条 `local_logs` 生成一个全局唯一 `log_id`（如 `Uuid().v4()`），随日志一起持久化和上报。
2. 服务端 `SyncLog`（或新增 `processed_log_ids` 表）记录已处理过的 `log_id`，`/sync` 处理前先用 `WHERE log_id IN (...)` 批量查重，已处理过的日志直接跳过并在 `report` 中标记为 `duplicate_skipped`，不重复执行业务逻辑。
3. 同步响应需要把"哪些 log_id 已确认入账"返回给客户端，客户端仅清除这些 id 对应的本地记录（与 §3.2 的修复结合）。

---

### 2.8 🆕 关键接口缺少输入下限校验

**位置**：`server/schemas.py` 的 `ToolCreate` / `AccessoryCreate`

**当前问题**：
```python
class ToolBase(BaseModel):
    code: str
    name: str
    model: str
    lifespan_limit: int = 30        # 无下限约束，可传 0 甚至负数
    location: str = "基地总库"

class AccessoryBase(BaseModel):
    ...
    safety_stock: int = 20          # 无下限约束
    current_stock: int = 0          # 无下限约束，可传负数
```
只有 `AccessoryAdjustment.qty` 用了 `Field(..., gt=0)`，其余涉及库存/寿命语义的字段都没有约束。

**风险**：Web 端表单目前靠前端 `type="number"` 弱约束，一旦绕过前端（直连 API、或未来接入第三方系统）传入负数或 0，会直接破坏"寿命已达上限即拦截出库"（`use_count >= lifespan_limit`，若 `lifespan_limit` 为 0 或负数则永远拦截或永远不拦截）和库存预警（负库存）的业务语义。

**修复建议**：
```python
from pydantic import Field

class ToolBase(BaseModel):
    code: str
    name: str
    model: str
    lifespan_limit: int = Field(30, ge=1)
    location: str = "基地总库"

class AccessoryBase(BaseModel):
    ...
    safety_stock: int = Field(20, ge=0)
    current_stock: int = Field(0, ge=0)
```

---

## 3. 🟠 P1 — 可靠性与容错加固<a name="3"></a>

### 3.1 同步响应 status 永远返回 "success"

**位置**：`server/sync.py:197`

```python
return schemas.SyncResponse(status="success", ...)  # 即使有冲突/错误也如此
```

**修复建议**：
```python
has_error = any(r.type == "error" for r in report)
has_conflict = any(r.type == "conflict" for r in report)
final_status = "error" if has_error else ("partial_success" if has_conflict else "success")
return schemas.SyncResponse(status=final_status, ...)
```

---

### 3.2 同步后清空全部本地日志（含失败记录）

**位置**：`app/lib/db/local_db.dart:199`

```dart
await txn.delete('local_logs');  // 包括 conflict/error 的日志也一并清除
```

**风险**：同步报告中为 `conflict` 或 `error` 的操作被静默抹去，操作员无从追溯，也无法人工补录。

**修复建议**：服务端 `SyncLogResult` 补充 `tool_code` / `log_id` 字段（呼应 §2.7），App 侧仅清除服务端确认 success 的日志，保留失败记录供人工审核。

---

### 3.3 `@app.on_event("startup")` 已废弃

**位置**：`server/main.py:24`

**修复建议**：
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    populate_initial_data()       # 启动逻辑移至此处
    yield
    # 关闭清理逻辑（如需要）

app = FastAPI(lifespan=lifespan, ...)
```

---

### 3.4 同步超时过短且无重试机制

**位置**：`app/lib/screens/sync_screen.dart:75`

```dart
.timeout(const Duration(seconds: 5))  // 野外积累的日志包可能较大，5秒极易超时
```

**修复建议**：根据待同步条数动态调整超时，配合指数退避重试：
```dart
final timeoutSecs = (15 + pendingLogs.length * 2).clamp(15, 120);

for (int attempt = 1; attempt <= 3; attempt++) {
    try {
        final resp = await http.post(url, headers: headers, body: body)
            .timeout(Duration(seconds: timeoutSecs));
        if (resp.statusCode == 200) { /* 处理成功 */ break; }
    } catch (e) {
        if (attempt == 3) { _showErrorDialog("同步失败，请检查网络后重试。错误：$e"); return; }
        await Future.delayed(Duration(seconds: attempt * 2));  // 指数退避
    }
}
```

---

### 3.5 缺少健康检查端点

**修复建议**：
```python
from sqlalchemy import text

@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ok", "db": "connected", "ts": utcnow().isoformat()}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"DB unavailable: {e}")
```
供 Docker HEALTHCHECK、Nginx upstream 探活和运维巡检脚本使用。

---

## 4. 🟠 P1 — 性能优化<a name="4"></a>

### 4.1 GET /tools 触发 N+1 查询且无分页

**位置**：`server/main.py:173`、`server/schemas.py:86`

**当前问题**：`ToolResponse` 包含 `histories: List[HistoryResponse]`，SQLAlchemy 对每个 Tool 发起一次独立的 `SELECT * FROM tool_histories`。100 台工具 = 101 次 SQL。

**修复建议**：拆分为列表精简视图（无 histories）和详情端点（含历史）：
```python
class ToolListResponse(BaseModel):
    code: str; name: str; model: str; status: str
    use_count: int; lifespan_limit: int
    location: str; operator: str; last_update_time: datetime
    checkout_time: Optional[datetime] = None
    class Config: from_attributes = True

@app.get("/tools", response_model=List[ToolListResponse])
def get_tools(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status: Optional[str] = None,
    db: Session = Depends(get_db)
):
    q = db.query(models.Tool)
    if status:
        q = q.filter(models.Tool.status == status)
    return q.offset(skip).limit(limit).all()

@app.get("/tools/{tool_code}/histories", response_model=List[HistoryResponse])
def get_tool_histories(tool_code: str, limit: int = Query(50), db: Session = Depends(get_db)):
    return (db.query(models.ToolHistory)
        .filter(models.ToolHistory.tool_code == tool_code)
        .order_by(models.ToolHistory.timestamp.desc())
        .limit(limit).all())
```

---

### 4.2 同步接口返回全量数据

**位置**：`server/sync.py:189-195`

**当前问题**：同步完成后将所有工具（含全量历史）和所有配件一次下发。随着数据量增加，响应包体将超 MB 级，局域网传输和 App 解析都会出现性能问题。

**修复建议**：改为增量返回（仅本次同步涉及的工具和配件），全量拉取改为独立接口按需触发：
```python
return schemas.SyncResponse(
    status=final_status,
    report=report,
    updated_tools=[tool_map[code] for code in affected_codes],
    updated_accessories=updated_acc_list,   # 仅本次扣减过的配件
    updated_dicts=updated_dicts,
)
```

---

### 4.3 前端获取工具历史效率极低

**位置**：`web/src/api.ts:253-272`

```typescript
// 请求全量工具再 .find()，每次查询返回 MB 级数据只为找一条记录
const res = await axios.get('/tools')
const tool = res.data.find((t: any) => t.code === toolCode)
```

**修复建议**：调用独立历史记录端点（见 4.1）：
```typescript
async getToolHistories(toolCode: string) {
    const res = await axios.get(`/tools/${toolCode}/histories?limit=100`)
    return res.data
}
```

---

### 4.4 补充关键数据库索引

```sql
CREATE INDEX idx_tools_status ON tools(status);
CREATE INDEX idx_tools_checkout ON tools(checkout_time) WHERE status != '在库';
CREATE INDEX idx_histories_tool_code ON tool_histories(tool_code, timestamp DESC);
CREATE INDEX idx_sync_logs_uuid ON sync_logs(terminal_uuid, timestamp DESC);
```

---

## 5. 🟡 P2 — 前端工程加固<a name="5"></a>

### 5.1 写操作 API 失败静默降级到 Mock 数据

**位置**：`web/src/api.ts` — 所有 catch 块

**当前问题**：任何 API 错误被 `console.warn` 消化，返回内存 Mock。库管员可能在"看起来正常"的界面上操作已过期数据，提交时才发现数据丢失。这一问题同时影响 §0.2 中确认已实现的「配件台账」「基础数据维护」「同步日志」三个功能页——它们的真实接口已经打通，但一旦后端临时不可用，用户完全无法察觉自己正在看的是假数据。

**修复建议**：读操作允许展示降级横幅（提示数据可能非最新），写操作绝对不允许静默降级：
```typescript
// main.ts — 全局拦截器统一弹错
axios.interceptors.response.use(
    response => response,
    error => {
        ElMessage.error(`操作失败：${error.response?.data?.detail ?? error.message}`)
        return Promise.reject(error)
    }
)
```
删除所有写操作 catch 块内的 Mock 逻辑，让异常自然冒泡到拦截器。

---

### 5.2 ⚠️ 更正（撤回）：字典 PUT/DELETE URL 参数问题

**v1.0 原描述**（已撤回）：曾报告 `web/src/api.ts` 中 `updateDictionaryItem`/`deleteDictionaryItem` 的请求 URL 缺少 `id` 参数。

**核对结论**：经与当前 `proj/web/src/api.ts` 源码逐行比对，实际代码为：
```typescript
async updateDictionaryItem(id: number, dictValue: string) {
    const res = await axios.put(`${API_BASE}/dictionaries/items/${id}`, { dict_value: dictValue })
    ...
},
async deleteDictionaryItem(id: number) {
    await axios.delete(`${API_BASE}/dictionaries/items/${id}`)
    ...
},
```
两处均已正确携带 `${id}`，**该 Bug 不存在**，特此更正撤回，避免团队浪费时间排查一个已经不存在的问题。保留本条记录仅作为版本变更追溯。

---

### 5.3 API_BASE 硬编码

**位置**：`web/src/api.ts:3` — `const API_BASE = 'http://127.0.0.1:8000'`

**修复建议**：
```typescript
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000'
```
```bash
# web/.env.production
VITE_API_BASE_URL=http://192.168.120.107:8000
```

---

### 5.4 Pinia 状态管理引入未使用

当前所有状态存放在 `api.ts` 的普通 `localState` 对象中（非响应式，Vue DevTools 无法追踪）。`package.json` 中的 `pinia` 依赖目前是"装了但没用"的状态。建议：
- **方案 A（轻量）**：将 `localState` 改为 `reactive()`，移除 Pinia 依赖
- **方案 B（推荐）**：将 `localState` 迁移至 Pinia Store，支持持久化、DevTools 调试；§1.7 的登录态（token）也建议放在 Pinia store 中统一管理

---

## 6. 🟡 P2 — 移动端加固<a name="6"></a>

### 6.1 terminal_uuid 默认值造成多设备身份冲突

**位置**：`app/lib/screens/sync_screen.dart:60`、`app/lib/screens/settings_screen.dart`

```dart
final currentUuid = await LocalDatabase.instance.getSetting('terminal_uuid')
    ?? 'terminal-handheld-001';   // 多台设备相同默认值，服务端无法区分
```

**修复建议**：首次启动时自动生成唯一 UUID 并持久化，设置页仅展示、不强制要求手填：
```dart
// identity_screen.dart 首次启动时执行
import 'package:uuid/uuid.dart';
final existing = await LocalDatabase.instance.getSetting('terminal_uuid');
if (existing == null) {
    await LocalDatabase.instance.saveSetting('terminal_uuid', const Uuid().v4());
}
```
配合 §1.5 的设备授权管理页，新设备首次同步时以"待审批"状态出现在 Web 端列表中，库管员手动启用后才能正常同步——比"靠人记得去改默认值"更可靠。

---

### 6.2 detail_screen 绕过 LocalDatabase 抽象直接操作 DB

**位置**：`app/lib/screens/detail_screen.dart:93-105`

```dart
final db = await LocalDatabase.instance.database;  // 绕过抽象层
await db.update('tools', {...}, where: 'code = ?', whereArgs: [barcode]);
```

**风险**：状态机前置校验被跳过，寿命拦截逻辑可能在 App 侧失效，业务逻辑散落在 UI 层难以维护。`maintenance_screen.dart` 中的归库保养提交也存在同样模式。

**修复建议**：在 `LocalDatabase` 中封装含前置校验的业务方法：
```dart
// local_db.dart
Future<void> checkoutTool(String toolCode, Map<String, dynamic> info) async {
    final tool = await getTool(toolCode);
    if (tool == null) throw Exception('工具不存在');
    if (tool['status'] != '在库') throw Exception('当前状态不允许出库：${tool['status']}');
    if (tool['use_count'] >= tool['lifespan_limit']) throw Exception('寿命已达上限，禁止出库');
    final db = await database;
    await db.transaction((txn) async {
        await txn.update('tools', {...info, 'status': '离库'}, where: 'code = ?', whereArgs: [toolCode]);
        await txn.insert('local_logs', {...});
    });
}
```

---

### 6.3 SQLite 本地数据未加密

**风险**：防爆手持终端若丢失，本地数据库文件可被直接读取，暴露工具资产信息和人员身份。

**修复建议**：使用 `sqflite_sqlcipher` 替代 `sqflite`，从 `flutter_secure_storage` 加载设备密钥：
```yaml
dependencies:
  sqflite_sqlcipher: ^2.2.0
  flutter_secure_storage: ^9.0.0
```
```dart
final key = await secureStorage.read(key: 'db_encryption_key') ?? _generateKey();
final db = await openDatabase(path, version: 2, password: key, onCreate: _createDB);
```

---

### 6.4 扫码类型识别逻辑脆弱

**位置**：`app/lib/screens/detail_screen.dart:38` — 仅凭 `ACC-` 前缀区分工具与配件

**修复建议**：先查工具表再查配件表，根据实际查询结果路由，不依赖编码规范假设：
```dart
final tool = await LocalDatabase.instance.getTool(widget.barcode);
if (tool != null) {
    // 走工具流程
} else {
    final accs = await LocalDatabase.instance.getAccessories();
    final acc = accs.firstWhere((a) => a['barcode'] == widget.barcode, orElse: () => {});
    if (acc.isNotEmpty) { /* 走配件流程 */ } else { /* 未知编码处理 */ }
}
```

---

### 6.5 硬编码备用服务器 IP 和字典值

**位置**：`sync_screen.dart:66`（IP）、`detail_screen.dart:64`（字典回退值）

**修复建议**：移除所有硬编码回退，配置缺失时引导用户进入设置页：
```dart
final serverUrl = await LocalDatabase.instance.getSetting('sync_server_url');
if (serverUrl == null) {
    _showErrorDialog('未配置同步服务器地址，请前往"设置 → 网络配置"填写库房服务器 IP。');
    return;
}
```

---

### 6.6 🆕 iOS `Info.plist` 缺少摄像头权限说明（`NSCameraUsageDescription`）

**位置**：`proj/app/ios/Runner/Info.plist`

**当前问题**：`mobile_scanner` 插件在 iOS 上首次调用摄像头前，系统强制要求 `Info.plist` 中声明 `NSCameraUsageDescription`（向用户解释为何需要摄像头权限）。当前文件中没有这个 key。

**风险**：
- 真机运行时，首次进入扫码页可能直接崩溃，或权限弹窗完全不出现导致摄像头黑屏，用户无法授权。
- 即便规避了崩溃，App Store 审核会因缺少使用说明而直接驳回提交——如果 iOS 是目标分发平台之一（PRD 未明确排除 iOS），这是一个会卡住整条发布流程的硬性问题。

**修复建议**：
```xml
<!-- proj/app/ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>需要使用摄像头扫描工具与配件的识别码，用于现场资产出入库登记</string>
```

---

### 6.7 🆕 本地待同步日志无离线备份/导出能力

**问题背景**：`local_logs` 表是现场操作记录在同步之前的唯一存储——一旦发生设备故障、误触"清除应用数据"、应用被卸载重装等情况，所有尚未同步的出库/维保记录会永久丢失，且无法重建（现场操作过程是不可逆的真实事件）。

**风险**：野外作业可能连续多天不联网，`local_logs` 累积量可能不小，一旦设备在回库同步前损坏或丢失，相关履历将彻底消失，无法补录。

**修复建议**：
- 设置页增加"导出本地待同步日志"按钮，将 `local_logs` 表导出为 JSON 文件保存到设备本地存储（或通过系统分享面板发送给库管员作为应急备份）。
- 同步成功前，App 可定期（如每次新增日志后）自动写一份快照到设备文档目录，作为数据库本身损坏时的最后一道防线。
- 长期看，可考虑多台终端之间通过蓝牙/局域网互相"搭桥"转发未同步日志，减少单点故障影响（此项作为后续增强项，非必须）。

---

## 7. 🟢 P3 — 工程化与部署基础设施<a name="7"></a>

### 7.1 缺少依赖声明文件

```toml
# server/pyproject.toml
[project]
name = "item-intelli-server"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.110.0",
    "uvicorn[standard]>=0.29.0",
    "sqlalchemy>=2.0.0",
    "psycopg2-binary>=2.9.9",
    "pydantic>=2.6.0",
    "alembic>=1.13.0",
    "python-dotenv>=1.0.0",
    "slowapi>=0.1.9",
    "python-jose[cryptography]>=3.3.0",
    "passlib[bcrypt]>=1.7.4",
]

[project.optional-dependencies]
dev = ["pytest>=8.0.0", "httpx>=0.27.0", "pytest-asyncio>=0.23.0"]
```

---

### 7.2 缺少容器化配置

```yaml
# docker-compose.yml（库房服务器一键启动）
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: item_intelli
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s

  server:
    build: ./server
    restart: unless-stopped
    depends_on: { postgres: { condition: service_healthy } }
    env_file: .env
    ports: ["8000:8000"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s

  web:
    build: ./web
    restart: unless-stopped
    ports: ["443:443"]

volumes: { pgdata: {} }
```

---

### 7.3 数据库定期备份策略

```bash
# /etc/cron.d/item_intelli_backup
# 每天凌晨 2 点执行增量备份
0 2 * * * root pg_dump -U app_user item_intelli | gzip > /backup/item_intelli_$(date +"%Y%m%d").sql.gz
# 保留最近 30 天备份
5 2 * * * root find /backup -name "*.sql.gz" -mtime +30 -delete
```

---

### 7.4 补充 .gitignore

```gitignore
.env
*.db
*.sqlite
__pycache__/
*.pyc
.venv/
node_modules/
dist/
build/
*.log
server/item_intelli.db
```

---

### 7.5 🆕 缺少 API 版本管理策略

**问题背景**：本系统的核心架构前提就是"野外终端离线工作、回库后才同步"——这意味着手持设备上跑的 App 版本，与库房服务器上跑的后端版本，**天然不会同时升级**。一台设备可能数周不联网，期间服务端 API 已经迭代了好几版（比如 §2.7 给 `SyncLogEntry` 加了 `log_id` 字段、§1.8 给 operator 加了 PIN 校验）。当前接口完全没有版本概念，服务端任何一次"破坏性"字段调整，都可能导致仍在用旧版 App 的设备同步失败甚至崩溃。

**修复建议**：
- 接口路径加版本前缀：`/v1/sync`、`/v1/tools`；新增不兼容变更时开 `/v2/...`，旧版本至少保留一个"宽限期"（如 3 个月）后才下线。
- 服务端对请求体做宽松校验（新增字段给默认值，不强制要求旧版客户端提供），避免新增非空字段直接拒绝旧版本请求。
- App 端在 `/sync` 请求头中携带 `X-App-Version`，服务端记录下来，方便后续统计现场到底有多少台设备还在用哪个版本，作为下线旧接口前的依据。

---

## 8. 🟢 P3 — 可观测性与运维<a name="8"></a>

### 8.1 结构化日志替代 print()

**位置**：`server/database.py:26,28`

```python
# 当前：裸 print，无级别、无时间戳、无模块标识
print(f"成功连接到 PostgreSQL 数据库: {SQLALCHEMY_DATABASE_URL}")
```

**修复建议**：
```python
import logging, sys

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler("/var/log/item_intelli/app.log")]
)
logger = logging.getLogger("item_intelli")

logger.info("成功连接到 PostgreSQL")
logger.warning("降级到 SQLite，原因: %s", str(e))
```

---

### 8.2 请求追踪中间件

```python
import uuid
from starlette.middleware.base import BaseHTTPMiddleware

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        rid = str(uuid.uuid4())[:8]
        request.state.request_id = rid
        response = await call_next(request)
        response.headers["X-Request-ID"] = rid
        return response

app.add_middleware(RequestIDMiddleware)
```

---

### 8.3 扩展审计日志覆盖全部写操作

现有 `sync_logs` 表仅记录同步操作，建议扩展覆盖 Web 端人工建档、库存调整等操作，字段包含：`action_type`（CREATE_TOOL / ADJUST_STOCK / SYNC 等）、`operator`（谁操作，来自 §1.7 的登录态）、`client_ip`（来自哪里）、`request_payload`（JSON）、`result`。

---

## 9. 🔵 P4 — 测试体系建设<a name="9"></a>

### 9.1 后端核心场景单元测试

```python
# server/tests/test_sync.py
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_double_checkout_rejected():
    """同一工具两台设备同时离线出库，第二条应被冲突拦截"""
    payload = {
        "terminal_uuid": "DEV-A",
        "logs": [
            {"timestamp": 1000, "time_str": "2026-06-18 10:00:00", "type": "CHECKOUT",
             "tool_code": "TL-MT-056-K", "operator": "张建国",
             "detail": {"wellbore": "川科1井", "team": "一队", "return_days": 30}},
            {"timestamp": 2000, "time_str": "2026-06-18 10:01:00", "type": "CHECKOUT",
             "tool_code": "TL-MT-056-K", "operator": "李志刚",
             "detail": {"wellbore": "深地塔科1井", "team": "二队", "return_days": 30}},
        ]
    }
    res = client.post("/sync", json=payload)
    data = res.json()
    assert data["status"] == "partial_success"
    assert len([r for r in data["report"] if r["type"] == "success"]) == 1
    assert len([r for r in data["report"] if r["type"] == "conflict"]) == 1

def test_lifespan_limit_blocks_checkout():
    """累计使用次数已达上限的工具，出库应被硬拦截"""
    ...  # 准备 use_count == lifespan_limit 的工具，断言返回 conflict
```

### 9.2 Flutter 状态机集成测试

```dart
// test/state_machine_test.dart
void main() {
    group('离线状态机', () {
        test('在库工具可以出库', () async {
            await LocalDatabase.instance.checkoutTool('TL-001', {...});
            final tool = await LocalDatabase.instance.getTool('TL-001');
            expect(tool!['status'], equals('离库'));
        });
        test('已离库工具不可重复出库', () async {
            expect(() => LocalDatabase.instance.checkoutTool('TL-OUT', {...}), throwsException);
        });
    });
}
```

### 9.3 🆕 现有 `widget_test.dart` 已与当前业务完全脱节

**位置**：`proj/app/test/widget_test.dart`

**当前问题**：该文件是 `flutter create` 脚手架自带的"计数器 Demo"测试，断言的是点击 `Icons.add` 按钮后页面文字从 `'0'` 变成 `'1'`：
```dart
testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ItemIntelliApp());
    expect(find.text('0'), findsOneWidget);
    ...
    await tester.tap(find.byIcon(Icons.add));
    ...
});
```
但当前 `ItemIntelliApp` 启动后进入的是 `IdentityScreen`/`HomeScreen`，**整个应用里没有任何计数器或 `Icons.add` 按钮**。这意味着这个测试如果真的被执行，会直接失败；而如果 CI 里跑了它却没人管，说明测试形同虚设、长期未被维护，团队对"测试是否通过"已经没有真实反馈。

**修复建议**：删除该文件，按 §9.2 的方向替换为真实覆盖核心状态机和关键页面渲染的 widget test（例如：未登记码进入详情页应展示拦截文案、寿命超限工具的出库按钮应不可点击等）。

---

## 10. 🔵 P4 — 业务逻辑与产品功能完整性<a name="10"></a>

> ⚠️ 提醒：本节虽然按惯例归类为"P4"，但其中 **§10.6 / §10.7**（Excel 批量导入与报表导出）属于 PRD 第 5.1.1 / 5.1.5 节明确要求的核心交付物，目前是**完全没有真实后端实现的纯前端模拟**，建议团队按 **P1 优先级**安排，不要等到其他项目都做完才处理——这两个功能直接关系到库管员能否真正"用起来"这个系统。

### 10.1 工具表缺少作业队字段

`tools` 表无 `team` 字段，驾驶舱"分队持有量视图"需从历史记录推算。建议：
```sql
ALTER TABLE tools ADD COLUMN team VARCHAR(100);
```
`CHECKOUT` 同步时写入 `team`，归库时清空。

### 10.2 配件无累计消耗统计

```sql
ALTER TABLE accessories ADD COLUMN total_consumed INTEGER NOT NULL DEFAULT 0;
-- 每次维保扣减时同步更新
UPDATE accessories
SET current_stock = current_stock - qty, total_consumed = total_consumed + qty
WHERE barcode = :barcode;
```
避免报表导出时每次聚合 `tool_histories` 计算。

### 10.3 Web 端 CRUD 操作缺少审计历史

`POST /tools`（新建）、`POST /accessories/adjust`（补货）改变数据但未记录审计日志，建议在每个写路由补充 `AuditLog` 记录，操作人通过 §1.7 的登录态自动注入。

### 10.4 报废流程未实现

PRD 状态机注释了"报废流转暂不实现"，建议下一版本补全：
```python
elif log.type == "SCRAP":
    if db_tool.status != "在库":
        # 离库工具需先归库才可报废
        ...
    db_tool.status = ToolStatus.SCRAPPED
    db_tool.last_update_time = log_time
    # 写入履历，不再允许出库
```

### 10.5 🆕 库存盘点功能未实现

PRD 在用户评审后明确标注"库存盘点（扫码核对）暂不需要"，但这意味着账实差异（实物丢失、误报损耗等）长期只能靠人工对账，没有任何系统化的定期核对机制。建议作为生产运行半年后的下一版本需求重新评估，至少先支持"按位置/按大队"筛选出当前应在某处的工具清单，供人工现场核对使用。

### 10.6 🆕 Excel 批量导入是纯前端模拟，没有真实文件解析

**位置**：`proj/web/src/views/Lifecycle.vue` 的 `mockSelectFile` / `triggerBatchImport`

**当前问题**：
```typescript
const mockSelectFile = () => {
  importingFile.value = 'precision_tools_batch_2026.xlsx';   // 只是赋值一个固定文件名，没有真实文件选择
};

const triggerBatchImport = () => {
  ...
  // 进度条纯靠 setInterval 计时模拟，最终随机生成一个编码插入一条工具记录
  const code = 'TL-MT-' + Math.floor(Math.random() * 900 + 100) + '-W';
  await api.createTool({ code, name: '电动坐封工具', model: 'E-Setter 3.0', lifespan_limit: 30, location: '基地总库' });
};
```
点击"选择文件"不会真正弹出文件选择器，"导入进度"是纯前端计时器，最终也并不会读取、解析任何 Excel 内容，只是插入一条写死参数的假记录。**PRD §4.2 和 §5.1.1 明确要求的"批量 Excel 导入"功能目前 0% 真实实现。**

**修复建议**：
- 前端使用真实文件选择 `<input type="file" accept=".xlsx">`，结合 `xlsx`/`SheetJS` 或后端解析。
- 后端新增 `POST /tools/batch-import` 接口，接收上传的 Excel，解析后批量校验（编码唯一性、必填字段）并批量写入，返回成功/失败明细供前端展示真实结果（成功 N 条、失败 M 条及原因），而不是一个固定的"导入成功"弹窗。

### 10.7 🆕 Excel 审计报表导出是纯前端模拟，没有真实文件生成

**位置**：`proj/web/src/views/Lifecycle.vue` 的 `triggerExport`

**当前问题**：
```typescript
const triggerExport = (type: string) => {
  exportMenuVisible.value = false;
  alert(`【报表导出】成功触发 ${type} 报表导出模拟，Excel 文件已准备下载。`);   // 仅弹窗提示，无任何文件生成
};
```
PRD §5.1.5 要求的"工具资产报表 / 配件库存报表 / 操作日志报表"三类 Excel 一键导出，目前点击后只会弹出一个 `alert()`，**没有调用任何接口，没有生成任何真实文件**，库管员实际上完全无法导出报表。

**修复建议**：
- 后端新增 `GET /reports/{type}` 接口（`type` 为 `assets`/`accessories`/`logs`），用 `openpyxl`/`pandas.to_excel` 真实生成 `.xlsx` 并以文件流形式返回。
- 前端改为真实下载（`window.open` 或 `<a download>` 触发浏览器下载对话框）。
- **大数据量场景需额外验证**：尤其是"操作日志报表"如果要导出全量历史履历，数据量可能达到数万行，需要验证导出耗时、内存占用，建议加上日期范围/工具编码筛选条件，而非无条件全量导出，避免一次请求拖垮服务端内存。

### 10.8 🆕 归还超期预警固定写死 30 天，未按工具品类区分默认归还周期

**位置**：`proj/web/src/views/Dashboard.vue` 的 `isOverdue` 函数

```typescript
const isOverdue = (t: Tool) => {
  // 如果离库且领用时间超过 30 天则算超期（当前写死 30 天）
  if (t.status === '离库' && t.checkout_time) {
    const diffDays = (now - checkTime) / (1000 * 60 * 60 * 24);
    return diffDays > 30;
  }
  return false;
};
```
代码注释里已经承认这是写死值，而 PRD §5.1.4 明确要求"基于不同工具品类配置的默认归还周期"（如 App 端出库表单里 `returnDays` 实际是 7-90 天可调的滑块，但服务端/Web 端的预警判断完全没有读取这个值，只用固定 30 天）。

**修复建议**：在出库同步时把 `return_days`（App 表单中用户实际填写的归还周期）写入 `tools` 表的新增字段 `expected_return_days`，Dashboard 超期判断改为 `diffDays > (tool.expected_return_days ?? 30)`。

### 10.9 🆕 驾驶舱"分队持有量视图"与"预警快捷处理窗口"未实现

PRD §5.1.5 明确列出这两个驾驶舱子功能，但当前 `Dashboard.vue` 只有 KPI 卡片 + 工具网格 + 配件水位 + 同步日志，没有按大队聚合持有量的视图，也没有"一键发起校验/查看详情"的预警快捷处理入口。这两项依赖 §10.1（工具表补充 `team` 字段）先落地，建议放在同一迭代里一起完成。

### 10.10 🆕 App 分发与版本更新机制缺失

**问题背景**：现场使用的是防爆手持终端，数量可能是几台到几十台，目前文档（`README.md`、环境搭建指南）描述的全部是"USB 连接电脑、`flutter run` 调试运行"的开发者工作流，没有任何面向"批量分发 + 后续版本更新"的方案。生产环境下不可能让库管员一台一台用 USB 连电脑跑 `flutter run`。

**修复建议（按野外/离线场景特点选择，无需一步到位）**：
- 短期：建立标准化的 `flutter build apk --release` 签名打包流程 + 内部文档化的"回库时连接 Wi-Fi 手动安装新 APK"操作手册，至少把"怎么升级"这件事流程化、可重复。
- 中期：评估接入企业级 MDM（移动设备管理）方案或 Android 的"受管理 Google Play"功能，实现批量推送更新。
- 同时建议接入轻量崩溃上报（如 Sentry 的 Flutter SDK），否则现场出现的崩溃问题，团队完全没有任何感知渠道。

### 10.11 🆕 孤儿设备的工具状态人工强制复位通道缺失

**问题背景**：当前状态机设计中，工具一旦被某台设备标记为"离库"，只能通过该工具后续的"归库保养"操作流转回"在库"。如果操作该次出库的手持终端在回库同步前丢失、损坏或被弃用（即数据永远无法上传），这台工具会在全局总账里**永久停留在"离库"状态**，没有任何途径能把它正常流转回来——因为系统里根本没有"该设备已经无法再提供后续日志"这件事的处理预案。

**风险**：随着使用时间增长，"事实上已经回库但系统里显示离库"的工具会越积越多，台账可信度持续下降，最终需要人工逐条排查才能纠正，而当前 Web 端没有任何手工干预入口（只能直接改数据库，既不安全也不留痕）。

**修复建议**：
- Web 端「工具生命周期管理」详情抽屉中新增"管理员强制复位"按钮（建议限制为 §1.7 鉴权后的库管员角色才可见）。
- 操作时强制要求填写复位原因（如"原终端遗失，现场口头确认已归还基地总库"），写入 `tool_histories`，类型标记为 `ADMIN_FORCE_RESET`，确保即便是例外操作也有完整审计轨迹，不破坏可追溯性这一核心设计目标。

---

## 11. 优先级汇总路线图<a name="11"></a>

| 优先级 | 端 | 问题 / 功能 | 状态 | 改动成本 | 影响 |
|--------|-----|------|------|---------|------|
| 🔴 P0 | 后端 | CORS 开放 + 无鉴权 | 待修复 | 中 | 系统安全根基 |
| 🔴 P0 | 后端 | 数据库密码硬编码 | 待修复 | 低 | 生产合规 |
| 🔴 P0 | 后端 | 设备身份无校验 + 设备管理页缺失 | 待开发 | 中 | 防伪造同步包 |
| 🔴 P0 | Web | 库管员账号体系与登录页 | 待开发 | 中 | 责任界定根基 |
| 🔴 P0 | App | 操作人身份认证（PIN/绑定） | 待开发 | 中 | 责任界定根基 |
| 🔴 P0 | 后端 | PostgreSQL 静默降级 SQLite | 待修复 | 低 | 防数据分裂 |
| 🔴 P0 | 后端 | 同步并发双写（无行锁） | 待修复 | 中 | 数据永久损坏 |
| 🔴 P0 | 后端 | status 无枚举约束 | 待修复 | 低 | 状态机失效 |
| 🔴 P0 | 后端 | 全系统时区不一致 | 待修复 | 低 | 时序错乱 |
| 🔴 P0 | 后端 | parse_time 失败静默回退 | 待修复 | 低 | 排序错乱 |
| 🔴 P0 | 后端 | 同步接口无幂等性 | 待修复 | 中 | 重复扣减/计数 |
| 🔴 P0 | 后端 | 关键字段无输入下限校验 | 待修复 | 低 | 状态机语义破坏 |
| 🟠 P1 | 后端 | 同步 status 永远 success | 待修复 | 低 | 错误无感知 |
| 🟠 P1 | App | 同步后清空全部日志 | 待修复 | 低 | 数据丢失 |
| 🟠 P1 | 后端 | on_event("startup") 废弃 | 待修复 | 低 | 升级阻断 |
| 🟠 P1 | 后端 | 无健康检查端点 | 待修复 | 低 | 运维盲区 |
| 🟠 P1 | 后端 | GET /tools N+1 + 无分页 | 待修复 | 中 | 性能瓶颈 |
| 🟠 P1 | 后端 | 同步返回全量数据 | 待修复 | 中 | 超时风险 |
| 🟠 P1 | Web | Excel 批量导入纯模拟 | 待开发 | 高 | PRD 核心功能缺失 |
| 🟠 P1 | Web | Excel 报表导出纯模拟 | 待开发 | 高 | PRD 核心功能缺失 |
| 🟡 P2 | Web | 写操作静默降级 Mock | 待修复 | 低 | 数据混乱 |
| ✅ | Web | 字典 PUT/DELETE URL Bug | **已更正撤回**（代码无此问题） | — | — |
| 🟡 P2 | App | terminal_uuid 默认值重复 | 待修复 | 低 | 设备混淆 |
| 🟡 P2 | App | 直接操作 DB 绕过抽象 | 待修复 | 中 | 状态机被绕过 |
| 🟡 P2 | App | 同步超时 5s + 无重试 | 待修复 | 低 | 野外失败率高 |
| 🟡 P2 | App | iOS 缺少摄像头权限说明 | 待修复 | 低 | 崩溃/审核驳回 |
| 🟡 P2 | App | 本地日志无离线备份 | 待开发 | 中 | 现场数据丢失风险 |
| 🟢 P3 | 工程 | 无 requirements / Docker | 待开发 | 低 | 部署标准化 |
| 🟢 P3 | 工程 | 无 Alembic 迁移 | 待开发 | 中 | 可维护性 |
| 🟢 P3 | 工程 | 无数据库备份 | 待开发 | 低 | 灾难恢复 |
| 🟢 P3 | 工程 | 无 API 版本管理 | 待开发 | 中 | 离线设备兼容性 |
| 🟢 P3 | 观测 | print 替代结构化日志 | 待修复 | 低 | 运维效率 |
| 🔵 P4 | 测试 | 无测试覆盖 + widget_test 已脱节 | 待开发 | 高 | 质量保障 |
| 🔵 P4 | 业务 | tools 无 team 字段 | 待开发 | 低 | 驾驶舱准确性 |
| 🔵 P4 | 业务 | 报废流程未实现 | 待开发 | 中 | PRD 完整性 |
| 🔵 P4 | 业务 | 库存盘点未实现 | 待评估 | 高 | PRD 完整性 |
| 🔵 P4 | 业务 | 归还周期写死 30 天 | 待修复 | 低 | 预警准确性 |
| 🔵 P4 | 业务 | 驾驶舱视图未补全 | 待开发 | 中 | PRD 完整性 |
| 🔵 P4 | 运营 | App 分发/更新机制缺失 | 待评估 | 中 | 批量运维 |
| 🔵 P4 | 运营 | 孤儿设备状态人工复位缺失 | 待开发 | 中 | 台账长期可信度 |
| ✅ | Web | 配件库存台账主表页 | **已实现**（需核实部署一致性） | — | — |
| ✅ | Web | 基础数据维护 CRUD | **已实现**（需核实部署一致性） | — | — |
| ✅ | 后端/Web | 真实同步日志 + 查询接口 | **已实现**（需核实部署一致性） | — | — |
| ✅ | App | 设置页（IP/操作人/UUID） | **已实现**（需核实部署一致性） | — | — |

---

## 12. 推荐迭代节奏<a name="12"></a>

### Sprint 0 — 核对清单（建议 0.5 天，正式排期前先做）

- [ ] 核对 §0.2 四项"已实现"功能在当前要上线的分支/部署环境中确实存在且工作正常，避免重复开发或误判为缺失
- [ ] 与团队确认 §5.2 的撤回结论（字典 PUT/DELETE 无 Bug），从待办列表中移除

### Sprint 1 — 上线前必须完成（建议 6-9 天）

- [ ] 1.1 收缩 CORS 来源至局域网 IP
- [ ] 1.2 同步接口与写操作接口添加 API Key 鉴权
- [ ] 1.3 数据库密码通过 .env 注入，移除硬编码
- [ ] 1.5 设备授权白名单表 + 同步前校验（设备管理页 UI 可放 Sprint 2）
- [ ] 1.7 库管员账号体系最小可用版本（单角色登录 + JWT + Login.vue）
- [ ] 1.8 操作人 PIN 码最小可用方案
- [ ] 1.9 PostgreSQL 连接失败时改为启动失败而非静默降级
- [ ] 2.1 同步引擎添加 SELECT FOR UPDATE 行级锁
- [ ] 2.2 status 字段改为 SQLAlchemy Enum 类型
- [ ] 2.3 全系统统一 UTC timezone-aware datetime
- [ ] 2.4 parse_time 失败时抛出异常而非静默回退
- [ ] 2.8 关键字段补充输入下限校验
- [ ] 6.1 App 首次启动自动生成唯一 terminal_uuid
- [ ] 6.6 补充 iOS NSCameraUsageDescription
- [ ] 7.4 补充 .gitignore，确保 .env 和 *.db 不入库

### Sprint 2 — 正式运行前（建议 1.5-2 周）

- [ ] 2.7 同步接口幂等性（log_id 去重）
- [ ] 3.1 同步响应区分 success / partial_success / error
- [ ] 3.2 同步后仅清除成功日志
- [ ] 3.3 startup 事件改为 lifespan
- [ ] 3.5 添加 /health 端点
- [ ] 4.1 GET /tools 分页 + 历史记录独立端点
- [ ] 5.1 写操作全面移除静默 Mock 降级
- [ ] 6.2 detail_screen 业务逻辑收敛到 LocalDatabase 方法
- [ ] 6.7 本地待同步日志离线导出能力
- [ ] 7.2 提供 docker-compose.yml 一键部署
- [ ] 7.3 配置数据库定期备份 cron
- [ ] 10.6 Excel 批量导入真实实现
- [ ] 10.7 Excel 报表导出真实实现
- [ ] 10.11 孤儿设备工具状态人工强制复位通道（Web UI）

### Sprint 3 — 稳定运行后迭代

- [ ] 1.5 设备管理页完整 UI（启用/禁用/列表）
- [ ] 完整 RBAC 角色权限扩展（库管员细分角色）
- [ ] HTTPS/TLS 证书部署
- [ ] SQLite 加密（App 端）
- [ ] Alembic Schema 迁移管理
- [ ] 结构化日志框架接入
- [ ] 7.5 API 版本管理策略落地
- [ ] 单元测试 + E2E 测试覆盖核心场景，替换已脱节的 widget_test.dart
- [ ] 10.1/10.2/10.8/10.9 业务字段与驾驶舱视图补全
- [ ] 10.10 App 分发/更新机制评估与落地
- [ ] 10.4/10.5 报废流程、库存盘点纳入下一版本 PRD

---

*本文档由代码审查整合生成，覆盖 `/proj/server/`、`/proj/web/src/`、`/proj/app/lib/`、PRD.md、implementation_plan.md 及 `doc/` 目录下全部过程文档。v2.0 在 v1.0 代码级审查基础上补充了产品功能完整性核查（含一项问题更正、四项功能核实为已实现），建议与开发团队逐条评审后按优先级排入迭代计划。*
