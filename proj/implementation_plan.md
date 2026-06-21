# 精密工具智能化管理系统：数据库建模与系统框架搭建计划

本项目在完成 UI 交互原型确认后，进入**系统详细设计与纯软部分框架搭建**阶段。本计划涵盖了双端数据库表结构设计、近场同步接口数据契约设计，以及后端、Web端和App端的工程骨架搭建步骤。

## User Review Required

请用户对以下技术选型及数据库 Schema 关键设计进行评审：
1. **数据库选型**：库房服务端采用 **PostgreSQL**，移动端本地采用 **SQLite**。两者表结构高度映射，以利于无网状态下边缘状态机计算。
2. **同步日志机制**：App 离线操作通过 `local_logs` 表记录操作时序，同步时按时间戳回放并进行状态锁校验，避免状态冲突。
3. **脚手架目录结构**：我们将在项目根目录下创建三个独立目录：
   - `/server` (FastAPI 后端服务与同步网关)
   - `/web` (Vue3 + Element Plus 管理端前端)
   - `/app` (Flutter 3.x 移动手持端)

> [!IMPORTANT]
> 库表设计中引入了 `checkout_time` 与 `lifespan_limit` 字段，用以在数据库层直接支撑“归还超期预警”和“寿命达到上限状态拦截”的核心产品需求。

---

## 1. 数据库设计 (Database Schema)

### 1.1 库房端主数据库 (PostgreSQL)

#### 1. 精密工具表 (`tools`)
用于记录精密资产一物一档数字主账：
```sql
CREATE TABLE tools (
    code VARCHAR(50) PRIMARY KEY,              -- 物理打标唯一识别编码
    name VARCHAR(100) NOT NULL,                -- 资产名称 (如: 电动坐封工具)
    model VARCHAR(100) NOT NULL,               -- 规格型号 (如: E-Setter 3.0)
    status VARCHAR(20) NOT NULL DEFAULT '在库', -- 在库, 离库, 报废
    use_count INT NOT NULL DEFAULT 0,          -- 累计使用次数 (寿命水位)
    lifespan_limit INT NOT NULL DEFAULT 30,    -- 核定寿命上限次数
    location VARCHAR(100) DEFAULT '基地总库',   -- 物理所在位置 / 所属井号
    operator VARCHAR(50) NOT NULL,             -- 最近一次操作的责任人
    last_update_time TIMESTAMP NOT NULL,       -- 最后更新时间戳 (状态锁)
    checkout_time TIMESTAMP DEFAULT NULL       -- 领用出库发生时间 (用于归还超期判定)
);
```

#### 2. 配件库存表 (`accessories`)
用于记录维保易损零配件库存：
```sql
CREATE TABLE accessories (
    barcode VARCHAR(50) PRIMARY KEY,           -- 配件三防标签条码
    name VARCHAR(100) NOT NULL,                -- 配件名称 (如: 氟橡胶密封圈)
    spec VARCHAR(100) NOT NULL,                -- 规格型号 (如: 120mm x 5mm)
    unit VARCHAR(10) NOT NULL DEFAULT '个',     -- 计量单位 (个, 套, 片)
    safety_stock INT NOT NULL DEFAULT 20,      -- 安全警戒水位
    current_stock INT NOT NULL DEFAULT 0       -- 全局当前在库库存量
);
```

#### 3. 工具全生命周期履历日志表 (`tool_histories`)
用于一物一码全流程追溯时间轴：
```sql
CREATE TABLE tool_histories (
    id SERIAL PRIMARY KEY,
    tool_code VARCHAR(50) NOT NULL REFERENCES tools(code) ON DELETE CASCADE,
    timestamp TIMESTAMP NOT NULL,
    type VARCHAR(50) NOT NULL,                 -- 建档入库, 领用出库, 工况变更, 归库保养
    detail TEXT NOT NULL,                      -- 详情明细 (如: 更换配件及寿命变动)
    operator VARCHAR(50) NOT NULL              -- 操作责任人
);
```

#### 4. 字典配置表 (`dictionaries`)
用于维护同步下发的井号及人员信息：
```sql
CREATE TABLE dictionaries (
    id SERIAL PRIMARY KEY,
    dict_type VARCHAR(30) NOT NULL,            -- wellbore (井号), operator (责任人), team (作业队)
    dict_value VARCHAR(100) NOT NULL,
    UNIQUE(dict_type, dict_value)
);
```

### 1.2 移动端本地数据库 (SQLite)

App 本地数据库字段与 PostgreSQL 保持一致，额外增加一张**本地离线暂存日志表**，用于在无网时缓存操作，以便联网后一键上传：

#### 离线待同步日志表 (`local_logs`)
```sql
CREATE TABLE local_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,                -- 发生时的时间戳 (毫秒)
    time_str TEXT NOT NULL,                    -- 格式化时间字符串
    type TEXT NOT NULL,                        -- CHECKOUT (出库), CHANGE_LOC (变更), MAINTAIN (维保)
    tool_code TEXT NOT NULL,                   -- 关联工具唯一编码
    operator TEXT NOT NULL,                    -- 操作人签名
    detail TEXT NOT NULL                       -- 序列化的 JSON 参数对象 (包含井号、更换配件等明细)
);
```

---

## 2. 近场同步数据契约 (API Contract)

双端近场同步通过 RESTful JSON 接口实现，涉及两个关键数据通信契约：

### 2.1 基础字典及运行配置同步 (Web ➡️ App)
手持端在握手通过后，拉取 Web 集中节点最新的字典参数更新本地 SQLite：
```json
{
  "wellbores": ["川科1井", "深地塔科1井", "威页23-4井", "大庆102井"],
  "operators": ["张建国", "李志刚", "王超", "赵强"],
  "teams": ["川庆钻探一队", "中原石油三队", "江汉作业五队"]
}
```

### 2.2 离线操作包合并对齐 (App ➡️ Web)
手持端将 `local_logs` 中的全部离线日志打包并序列化上报给 Web 服务端：
```json
{
  "terminal_uuid": "DEV-8812-XYZ",
  "logs": [
    {
      "timestamp": 1781485148000,
      "time_str": "2026-06-18 10:15:30",
      "type": "CHECKOUT",
      "tool_code": "TL-MT-056-K",
      "operator": "张建国",
      "detail": {
        "wellbore": "川科1井",
        "team": "川庆钻探一队",
        "return_days": 30
      }
    },
    {
      "timestamp": 1781485150000,
      "time_str": "2026-06-18 11:30:00",
      "type": "MAINTAIN",
      "tool_code": "TL-BG-203-A",
      "operator": "李志刚",
      "detail": {
        "level": "二级保养",
        "consumables": [
          { "barcode": "ACC-RING-001", "qty": 2 }
        ]
      }
    }
  ]
}
```

---

## 3. 系统框架脚手架搭建

我们将在工作区 `/item_intelli` 根目录下进行以下目录和框架初始化：

```
/item_intelli
  └── /proj
        ├── /server               --> 后端服务 (FastAPI)
        ├── /web                  --> Web端前端 (Vue3 + TS + Vite + Element Plus)
        └── /app                  --> 移动端 (Flutter 3.x)
```

### 3.1 后端初始化 (FastAPI)
* 架构：FastAPI + SQLAlchemy + Pydantic + Uvicorn。
* 命令：`pip install fastapi uvicorn sqlalchemy psycopg2-binary pydantic`。
* 骨架文件：`main.py` (路由网关)、`database.py` (ORM连接连接池)、`models.py` (PostgreSQL实体定义)、`schemas.py` (Pydantic结构验证)、`sync.py` (冲突解析合并算法核心)。

### 3.2 Web前端初始化 (Vue3)
* 架构：Vue 3 + TypeScript + Vite + Element Plus + Pinia + Vue Router + ECharts。
* 命令：`npx -y create-vite-app@latest web --template vue-ts`，并引入相关前端依赖。
* 骨架结构：
  - `/src/views/Dashboard.vue` (仪表盘大盘组件)
  - `/src/views/Lifecycle.vue` (生命履历表格及抽屉时间轴)
  - `/src/components/ExcelExport.vue` (通用报表模拟与数据导出插件)

### 3.3 移动端 App 初始化 (Flutter)
* 架构：Flutter 3.x (Material 3 UI 规范) + `sqflite` (本地库)。
* 命令：`flutter create --org com.item_intelli app`。
* 引入依赖：`sqflite`, `path_provider`, `mobile_scanner`, `fl_chart`, `http`。
* 骨架结构：
  - `/lib/main.dart` (App 入口与 MD3 主题配置)
  - `/lib/db/local_db.dart` (SQLite 数据库初始化与 local_logs 表操作封装)
  - `/lib/screens/home_screen.dart` (扫描与同步大卡片首页)
  - `/lib/screens/detail_screen.dart` (工具出库与拦截状态页)
  - `/lib/screens/maintenance_screen.dart` (保养级别与配件核销表单页)
  - `/lib/screens/sync_screen.dart` (数据同步网关控制台)

---

## 4. 验证计划

### 自动验证
* **数据库脚本验证**：使用本地 Docker 镜像运行 PostgreSQL 实例，测试 SQL 脚本在空库上的建表过程及外键约束。
* **FastAPI 接口单元测试**：使用 `pytest` 编写 API 测试，测试并发冲突时同步接口的返回值是否符合丢弃/报错机制。

### 手动验证
* 启动后端 API 后，使用 Postman 或 FastAPI 的 Swagger 交互页面（`/docs`），手动推送一份包含冲突时间戳的 logs JSON 包，验证数据库中的 `use_count` 和 `status` 是否按时间戳优先级合并。
