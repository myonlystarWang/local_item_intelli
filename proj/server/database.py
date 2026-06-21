import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 优先使用环境变量中的数据库连接，默认为 PostgreSQL 局域网服务
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://postgres:postgres@localhost:5432/item_intelli"
)

# 自动检测并降级：如果 PostgreSQL 连接不可用，则切换至本地 SQLite
try:
    if not SQLALCHEMY_DATABASE_URL.startswith("postgresql"):
        raise ValueError("Not PostgreSQL")
        
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL, 
        pool_pre_ping=True, 
        pool_size=10, 
        max_overflow=20
    )
    # 测试连接是否可用
    with engine.connect() as conn:
        pass
    print(f"成功连接到 PostgreSQL 数据库: {SQLALCHEMY_DATABASE_URL}")
except Exception as e:
    print(f"PostgreSQL 数据库连接不可用 ({e})。自动降级切换至本地 SQLite 数据库...")
    SQLALCHEMY_DATABASE_URL = "sqlite:///./item_intelli.db"
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL,
        connect_args={"check_same_thread": False}  # SQLite 专有参数，允许多线程并发连接
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# 依赖注入，用于 FastAPI 路由获取数据库连接会话
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
