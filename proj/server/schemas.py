from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

# ─────────────────────────────────────────────────────────────
# 字典参数相关 Schema
# ─────────────────────────────────────────────────────────────
class DictionaryBase(BaseModel):
    dict_type: str
    dict_value: str

    class Config:
        from_attributes = True

class DictionaryUpdate(BaseModel):
    dict_value: str

class DictionaryItemResponse(DictionaryBase):
    id: int

    class Config:
        from_attributes = True

class DictionaryResponse(BaseModel):
    wellbores: List[str]
    operators: List[str]
    teams: List[str]

# ─────────────────────────────────────────────────────────────
# 配件库存相关 Schema
# ─────────────────────────────────────────────────────────────
class AccessoryBase(BaseModel):
    barcode: str
    name: str
    spec: str
    unit: str = "个"
    safety_stock: int = 20
    current_stock: int = 0

class AccessoryCreate(AccessoryBase):
    pass

class AccessoryResponse(AccessoryBase):
    class Config:
        from_attributes = True

class AccessoryAdjustment(BaseModel):
    barcode: str
    qty: int = Field(..., gt=0, description="入库追加数量，必须大于0")

# ─────────────────────────────────────────────────────────────
# 履历日志相关 Schema
# ─────────────────────────────────────────────────────────────
class HistoryBase(BaseModel):
    timestamp: datetime
    type: str
    detail: str
    operator: str

class HistoryResponse(HistoryBase):
    id: int
    tool_code: str

    class Config:
        from_attributes = True

# ─────────────────────────────────────────────────────────────
# 精密工具相关 Schema
# ─────────────────────────────────────────────────────────────
class ToolBase(BaseModel):
    code: str
    name: str
    model: str
    lifespan_limit: int = 30
    location: str = "基地总库"

class ToolCreate(ToolBase):
    pass

class ToolResponse(ToolBase):
    status: str
    use_count: int
    operator: str
    last_update_time: datetime
    checkout_time: Optional[datetime] = None
    histories: List[HistoryResponse] = Field(default_factory=list)

    class Config:
        from_attributes = True

class SyncLogResponse(BaseModel):
    id: int
    terminal_uuid: str
    timestamp: datetime
    type: str
    text: str
    source_time: Optional[str] = None

    class Config:
        from_attributes = True

# ─────────────────────────────────────────────────────────────
# 近场数据同步协议 Schema (API 契约)
# ─────────────────────────────────────────────────────────────

class ConsumableEntry(BaseModel):
    barcode: str
    name: str
    qty: int

class SyncLogDetail(BaseModel):
    wellbore: Optional[str] = None
    team: Optional[str] = None
    return_days: Optional[int] = None
    level: Optional[str] = None
    consumables: Optional[List[ConsumableEntry]] = None

class SyncLogEntry(BaseModel):
    timestamp: int                                    # 离线操作发生时的时间戳 (毫秒)
    time_str: str                                     # 格式化日期字符串
    type: str                                         # CHECKOUT, CHANGE_LOC, MAINTAIN
    tool_code: str
    operator: str
    detail: SyncLogDetail

class SyncRequest(BaseModel):
    terminal_uuid: str
    logs: List[SyncLogEntry]

class SyncLogResult(BaseModel):
    type: str                                         # success, conflict, error
    text: str
    time: str

class SyncResponse(BaseModel):
    status: str                                       # success, partial_success, error
    report: List[SyncLogResult]
    updated_tools: List[ToolResponse]
    updated_accessories: List[AccessoryResponse]
    updated_dicts: DictionaryResponse
