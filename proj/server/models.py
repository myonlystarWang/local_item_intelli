from datetime import datetime
from sqlalchemy import Boolean, Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from database import Base

class AdminUser(Base):
    __tablename__ = "admin_users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), nullable=False, unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(30), nullable=False, default="admin")
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

class AuthorizedDevice(Base):
    __tablename__ = "authorized_devices"

    uuid = Column(String(100), primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    registered_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    last_sync_at = Column(DateTime, nullable=True)
    remark = Column(Text, nullable=True)

class Tool(Base):
    __tablename__ = "tools"
    
    code = Column(String(50), primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    model = Column(String(100), nullable=False)
    status = Column(String(20), nullable=False, default="在库") # 在库, 离库, 报废
    use_count = Column(Integer, nullable=False, default=0)
    lifespan_limit = Column(Integer, nullable=False, default=30)
    location = Column(String(100), default="基地总库")
    operator = Column(String(50), nullable=False)
    last_update_time = Column(DateTime, nullable=False)
    checkout_time = Column(DateTime, nullable=True)
    
    histories = relationship(
        "ToolHistory",
        back_populates="tool",
        cascade="all, delete-orphan",
        order_by="ToolHistory.timestamp.desc()",
    )

class Accessory(Base):
    __tablename__ = "accessories"
    
    barcode = Column(String(50), primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    spec = Column(String(100), nullable=False)
    unit = Column(String(10), nullable=False, default="个")
    safety_stock = Column(Integer, nullable=False, default=20)
    current_stock = Column(Integer, nullable=False, default=0)

class ToolHistory(Base):
    __tablename__ = "tool_histories"
    
    id = Column(Integer, primary_key=True, index=True)
    tool_code = Column(String(50), ForeignKey("tools.code", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime, nullable=False)
    type = Column(String(50), nullable=False) # 建档入库, 领用出库, 工况变更, 归库保养
    detail = Column(Text, nullable=False)
    operator = Column(String(50), nullable=False)
    
    tool = relationship("Tool", back_populates="histories")

class Dictionary(Base):
    __tablename__ = "dictionaries"
    
    id = Column(Integer, primary_key=True, index=True)
    dict_type = Column(String(30), nullable=False)  # wellbore, operator, team
    dict_value = Column(String(100), nullable=False)

class SyncLog(Base):
    __tablename__ = "sync_logs"

    id = Column(Integer, primary_key=True, index=True)
    terminal_uuid = Column(String(100), nullable=False, index=True)
    timestamp = Column(DateTime, nullable=False, default=datetime.utcnow)
    type = Column(String(20), nullable=False)  # success, conflict, error
    text = Column(Text, nullable=False)
    source_time = Column(String(50), nullable=True)
