import os
from fastapi import APIRouter, FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List
import auth, models, schemas, database, sync
from database import get_db

app = FastAPI(title="精密工具智能化管理系统 后端同步中枢", version="1.0")
api_router = APIRouter(prefix="/api/v1")
MIN_SUPPORTED_APP_VERSION = "1.0.0"
MIN_SUPPORTED_SCHEMA_VERSION = 2

def _get_allowed_origins():
    raw_origins = os.getenv("ALLOWED_ORIGINS", "")
    origins = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]
    if not origins:
        raise RuntimeError("未设置 ALLOWED_ORIGINS；生产环境必须显式配置 Web 端允许访问的域名或 IP。")
    if "*" in origins:
        raise RuntimeError("ALLOWED_ORIGINS 禁止配置为 *；请配置明确的库房端域名或 IP。")
    return origins


# 开启跨域访问 (CORS)，允许指定 Web 端与 App 端通信
app.add_middleware(
    CORSMiddleware,
    allow_origins=_get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _parse_version(version: str) -> tuple[int, int, int]:
    parts = []
    for part in version.split(".")[:3]:
        try:
            parts.append(int(part))
        except ValueError:
            parts.append(0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def _validate_sync_client_version(sync_data: schemas.SyncRequest):
    if _parse_version(sync_data.app_version) < _parse_version(MIN_SUPPORTED_APP_VERSION):
        raise HTTPException(
            status_code=426,
            detail=f"App 版本过低，最低支持版本为 {MIN_SUPPORTED_APP_VERSION}，请升级手持端后再同步。",
        )
    if sync_data.schema_version < MIN_SUPPORTED_SCHEMA_VERSION:
        raise HTTPException(
            status_code=426,
            detail=f"本地数据库 schema_version={sync_data.schema_version} 已不兼容，最低支持版本为 {MIN_SUPPORTED_SCHEMA_VERSION}，请升级手持端后再同步。",
        )


def _require_authorized_device(db: Session, terminal_uuid: str) -> models.AuthorizedDevice:
    device = db.query(models.AuthorizedDevice).filter(models.AuthorizedDevice.uuid == terminal_uuid).first()
    if not device:
        raise HTTPException(status_code=403, detail="终端设备未授权，禁止同步。")
    if not device.is_active:
        raise HTTPException(status_code=403, detail="终端设备已禁用，禁止同步。")
    return device

# 自动填充初始演示数据 (如果库为空)
@app.on_event("startup")
def startup_populate_db():
    db = database.SessionLocal()
    try:
        auth.ensure_initial_admin(db)

        # 1. 字典参数初始化
        if db.query(models.Dictionary).count() == 0:
            for wb in ["川科1井", "深地塔科1井", "威页23-4井", "大庆102井"]:
                db.add(models.Dictionary(dict_type="wellbore", dict_value=wb))
            for op in ["张建国", "李志刚", "王超", "赵强"]:
                db.add(models.Dictionary(dict_type="operator", dict_value=op))
            for tm in ["川庆钻探一队", "中原石油三队", "江汉作业五队"]:
                db.add(models.Dictionary(dict_type="team", dict_value=tm))
            db.commit()

        # 2. 精密资产一物一档数据初始化
        if db.query(models.Tool).count() == 0:
            tools = [
                models.Tool(
                    code="TL-MT-056-K", name="电动坐封工具", model="E-Setter 3.0",
                    status="在库", use_count=12, lifespan_limit=30, location="基地总库",
                    operator="系统初始化", last_update_time=datetime.now()
                ),
                models.Tool(
                    code="TL-BG-112-B", name="阿瓦隆桥塞", model="Avalon-Bridge 10",
                    status="在库", use_count=28, lifespan_limit=30, location="基地总库",
                    operator="系统初始化", last_update_time=datetime.now()
                ),
                models.Tool(
                    code="TL-MT-099-H", name="电动坐封工具", model="E-Setter 2.0",
                    status="在库", use_count=30, lifespan_limit=30, location="基地总库",
                    operator="系统初始化", last_update_time=datetime.now()
                ),
                models.Tool(
                    code="TL-BG-203-A", name="阿瓦隆桥塞", model="Avalon-Bridge 12",
                    status="离库", use_count=15, lifespan_limit=40, location="川科1井",
                    operator="王超", last_update_time=datetime.now(), checkout_time=datetime.now()
                )
            ]
            db.add_all(tools)
            db.commit()

            # 填充初始历史履历
            for code in ["TL-MT-056-K", "TL-BG-112-B", "TL-MT-099-H", "TL-BG-203-A"]:
                db.add(models.ToolHistory(
                    tool_code=code, timestamp=datetime.now(), type="建档入库",
                    detail="系统数据库建档完成，录入初始电子档案数据。", operator="系统中枢"
                ))
            db.commit()

        # 3. 零配件安全水位数据初始化
        if db.query(models.Accessory).count() == 0:
            accs = [
                models.Accessory(barcode="ACC-RING-001", name="氟橡胶密封圈 O-Ring", spec="120mm x 5mm", unit="个", safety_stock=20, current_stock=45),
                models.Accessory(barcode="ACC-BOLT-002", name="高强防腐螺栓", spec="M16 x 80", unit="套", safety_stock=50, current_stock=15),
                models.Accessory(barcode="ACC-SEAL-003", name="井下密封金属垫", spec="DN100", unit="片", safety_stock=10, current_stock=25)
            ]
            db.add_all(accs)
            db.commit()
    finally:
        db.close()

# ─────────────────────────────────────────────────────────────
# 路由接口实现
# ─────────────────────────────────────────────────────────────

@api_router.post("/auth/login", response_model=schemas.TokenResponse)
def login_admin(credentials: schemas.AdminLoginRequest, db: Session = Depends(get_db)):
    """库管员登录，返回 Web 管理端 JWT。"""
    user = auth.authenticate_admin(db, credentials.username, credentials.password)
    if not user:
        raise HTTPException(status_code=401, detail="用户名或密码错误")
    return schemas.TokenResponse(
        access_token=auth.create_access_token(user),
        expires_in=auth.JWT_EXPIRE_MINUTES * 60,
        user=user,
    )

@api_router.get("/devices", response_model=List[schemas.AuthorizedDeviceResponse])
def read_devices(
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """获取授权手持终端列表。"""
    return (
        db.query(models.AuthorizedDevice)
        .order_by(models.AuthorizedDevice.registered_at.desc())
        .all()
    )

@api_router.post("/devices", response_model=schemas.AuthorizedDeviceResponse)
def create_device(
    device: schemas.AuthorizedDeviceCreate,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """登记一个允许同步的手持终端 UUID。"""
    uuid = device.uuid.strip()
    name = device.name.strip()
    if not uuid or not name:
        raise HTTPException(status_code=400, detail="设备 UUID 和名称不能为空")
    db_exist = db.query(models.AuthorizedDevice).filter_by(uuid=uuid).first()
    if db_exist:
        raise HTTPException(status_code=400, detail="该设备 UUID 已登记")

    created = models.AuthorizedDevice(
        uuid=uuid,
        name=name,
        is_active=True,
        registered_at=datetime.utcnow(),
        remark=device.remark,
    )
    db.add(created)
    db.commit()
    db.refresh(created)
    return created

@api_router.patch("/devices/{device_uuid}", response_model=schemas.AuthorizedDeviceResponse)
def update_device(
    device_uuid: str,
    item: schemas.AuthorizedDeviceUpdate,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """更新设备名称、启用状态或备注。"""
    db_device = db.query(models.AuthorizedDevice).filter_by(uuid=device_uuid).first()
    if not db_device:
        raise HTTPException(status_code=404, detail="未找到该设备")

    if item.name is not None:
        name = item.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="设备名称不能为空")
        db_device.name = name
    if item.is_active is not None:
        db_device.is_active = item.is_active
    if item.remark is not None:
        db_device.remark = item.remark

    db.commit()
    db.refresh(db_device)
    return db_device

@api_router.delete("/devices/{device_uuid}")
def delete_device(
    device_uuid: str,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """禁用设备。保留历史记录，不做物理删除。"""
    db_device = db.query(models.AuthorizedDevice).filter_by(uuid=device_uuid).first()
    if not db_device:
        raise HTTPException(status_code=404, detail="未找到该设备")

    db_device.is_active = False
    db.commit()
    return {"message": "设备已禁用"}

@api_router.get("/dictionaries", response_model=schemas.DictionaryResponse)
def read_dictionaries(db: Session = Depends(get_db)):
    """获取所有同步下发的基础字典参数。"""
    wellbores = [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="wellbore").all()]
    operators = [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="operator").all()]
    teams = [r.dict_value for r in db.query(models.Dictionary).filter_by(dict_type="team").all()]
    return {"wellbores": wellbores, "operators": operators, "teams": teams}

@api_router.get("/dictionaries/items", response_model=List[schemas.DictionaryItemResponse])
def read_dictionary_items(db: Session = Depends(get_db)):
    """获取基础字典台账明细，供 Web 端维护井号、人员、大队。"""
    return (
        db.query(models.Dictionary)
        .order_by(models.Dictionary.dict_type.asc(), models.Dictionary.dict_value.asc())
        .all()
    )

@api_router.post("/dictionaries/items", response_model=schemas.DictionaryItemResponse)
def create_dictionary_item(
    item: schemas.DictionaryBase,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """新增基础字典项。"""
    if item.dict_type not in {"wellbore", "operator", "team"}:
        raise HTTPException(status_code=400, detail="字典类型仅支持 wellbore/operator/team")

    db_exist = (
        db.query(models.Dictionary)
        .filter_by(dict_type=item.dict_type, dict_value=item.dict_value)
        .first()
    )
    if db_exist:
        raise HTTPException(status_code=400, detail="该字典项已存在")

    created = models.Dictionary(dict_type=item.dict_type, dict_value=item.dict_value)
    db.add(created)
    db.commit()
    db.refresh(created)
    return created

@api_router.put("/dictionaries/items/{item_id}", response_model=schemas.DictionaryItemResponse)
def update_dictionary_item(
    item_id: int,
    item: schemas.DictionaryUpdate,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """修改基础字典项名称。"""
    db_item = db.query(models.Dictionary).filter_by(id=item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="未找到该字典项")

    db_exist = (
        db.query(models.Dictionary)
        .filter(
            models.Dictionary.id != item_id,
            models.Dictionary.dict_type == db_item.dict_type,
            models.Dictionary.dict_value == item.dict_value,
        )
        .first()
    )
    if db_exist:
        raise HTTPException(status_code=400, detail="同类型字典中已存在该值")

    db_item.dict_value = item.dict_value
    db.commit()
    db.refresh(db_item)
    return db_item

@api_router.delete("/dictionaries/items/{item_id}")
def delete_dictionary_item(
    item_id: int,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """删除基础字典项。"""
    db_item = db.query(models.Dictionary).filter_by(id=item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="未找到该字典项")

    db.delete(db_item)
    db.commit()
    return {"message": "字典项已删除"}

@api_router.post("/dictionaries/wellbores")
def add_wellbore_dictionary(
    item: schemas.DictionaryBase,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """库管员在管理端新增目标作业井号字典。"""
    db_exist = db.query(models.Dictionary).filter_by(dict_type="wellbore", dict_value=item.dict_value).first()
    if db_exist:
        raise HTTPException(status_code=400, detail="该井号参数在字典中已存在")
    new_wb = models.Dictionary(dict_type="wellbore", dict_value=item.dict_value)
    db.add(new_wb)
    db.commit()
    return {"message": f"成功录入目标井号: {item.dict_value}"}

@api_router.get("/tools", response_model=List[schemas.ToolResponse])
def get_tools(db: Session = Depends(get_db)):
    """获取全局精密资产列表主账本。"""
    return db.query(models.Tool).all()

@api_router.post("/tools", response_model=schemas.ToolResponse)
def create_tool(
    tool: schemas.ToolCreate,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """库管员在管理端进行单一精密工具新购入库手动建档。"""
    db_exist = db.query(models.Tool).filter_by(code=tool.code).first()
    if db_exist:
        raise HTTPException(status_code=400, detail="该工具资产唯一打标识别码在数据库中已存在")
    
    timestamp = datetime.now()
    created = models.Tool(
        code=tool.code, name=tool.name, model=tool.model,
        lifespan_limit=tool.lifespan_limit, location=tool.location,
        status="在库", use_count=0, operator="库管员",
        last_update_time=timestamp
    )
    db.add(created)
    db.commit()
    db.refresh(created)
    
    # 记入履历
    history = models.ToolHistory(
        tool_code=tool.code, timestamp=timestamp, type="建档入库",
        detail=f"精密工具手动新购建档，设定初始核定寿命水位上限为 {tool.lifespan_limit} 次。", operator="库管员"
    )
    db.add(history)
    db.commit()
    db.refresh(created)
    return created

@api_router.get("/accessories", response_model=List[schemas.AccessoryResponse])
def get_accessories(db: Session = Depends(get_db)):
    """获取所有零配件库管库存水位量。"""
    return db.query(models.Accessory).all()

@api_router.post("/accessories", response_model=schemas.AccessoryResponse)
def create_accessory(
    acc: schemas.AccessoryCreate,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """库管员在管理端进行单一零配件新购入库手动建档。"""
    db_exist = db.query(models.Accessory).filter_by(barcode=acc.barcode).first()
    if db_exist:
        raise HTTPException(status_code=400, detail="该配件唯一条码在数据库中已存在")
    
    created = models.Accessory(
        barcode=acc.barcode,
        name=acc.name,
        spec=acc.spec,
        unit=acc.unit,
        safety_stock=acc.safety_stock,
        current_stock=acc.current_stock
    )
    db.add(created)
    db.commit()
    db.refresh(created)
    return created

@api_router.post("/accessories/adjust")
def adjust_accessory_stock(
    item: schemas.AccessoryAdjustment,
    db: Session = Depends(get_db),
    _admin: models.AdminUser = Depends(auth.require_admin),
):
    """零配件调库补货，追加当前在库库存量。"""
    db_acc = db.query(models.Accessory).filter_by(barcode=item.barcode).first()
    if not db_acc:
        raise HTTPException(status_code=404, detail="未找到该配件条码的记录")
    db_acc.current_stock += item.qty
    db.commit()
    return {"message": f"配件 [{db_acc.name}] 成功补货入库 {item.qty} {db_acc.unit}。"}

@api_router.post("/sync", response_model=schemas.SyncResponse)
def sync_offline_data(sync_data: schemas.SyncRequest, db: Session = Depends(get_db)):
    """近场握手数据同步接口：接收终端打包离线日志，进行时间戳及状态锁对齐合并，并反馈最新总账字典数据。"""
    _validate_sync_client_version(sync_data)
    device = _require_authorized_device(db, sync_data.terminal_uuid)
    response = sync.process_offline_sync(db, sync_data)
    device.last_sync_at = datetime.utcnow()
    db.commit()
    return response

@api_router.get("/sync-logs", response_model=List[schemas.SyncLogResponse])
def read_sync_logs(limit: int = Query(20, ge=1, le=200), db: Session = Depends(get_db)):
    """获取真实局域网同步校验日志，供 Web 端 Dashboard 展示。"""
    return (
        db.query(models.SyncLog)
        .order_by(models.SyncLog.timestamp.desc(), models.SyncLog.id.desc())
        .limit(limit)
        .all()
    )


app.include_router(api_router)
