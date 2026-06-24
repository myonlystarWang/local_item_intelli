import os
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker


def _load_dotenv():
    """Load proj/server/.env without overriding process environment variables."""
    env_path = Path(__file__).with_name(".env")
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "y", "on"}


def _create_sqlite_engine(database_url: str):
    return create_engine(
        database_url,
        connect_args={"check_same_thread": False},
    )


def _create_postgresql_engine(database_url: str):
    engine = create_engine(
        database_url,
        pool_pre_ping=True,
        pool_size=10,
        max_overflow=20,
    )
    with engine.connect():
        pass
    return engine


_load_dotenv()

ALLOW_SQLITE_FALLBACK = _env_bool("ALLOW_SQLITE_FALLBACK", False)
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

if not SQLALCHEMY_DATABASE_URL:
    if not ALLOW_SQLITE_FALLBACK:
        raise RuntimeError(
            "未设置 DATABASE_URL，且 ALLOW_SQLITE_FALLBACK 未启用；"
            "生产环境必须显式配置 PostgreSQL 数据库连接。"
        )
    SQLALCHEMY_DATABASE_URL = "sqlite:///./item_intelli.db"
    print("未设置 DATABASE_URL，已按 ALLOW_SQLITE_FALLBACK=true 使用本地 SQLite。")
    engine = _create_sqlite_engine(SQLALCHEMY_DATABASE_URL)
else:
    normalized_database_url = SQLALCHEMY_DATABASE_URL.lower()
    is_postgresql = normalized_database_url.startswith("postgresql")
    is_sqlite = normalized_database_url.startswith("sqlite")

    if is_sqlite:
        if not ALLOW_SQLITE_FALLBACK:
            raise RuntimeError(
                "检测到 SQLite DATABASE_URL，但 ALLOW_SQLITE_FALLBACK 未启用；"
                "生产环境禁止使用 SQLite。"
            )
        print("已按 ALLOW_SQLITE_FALLBACK=true 使用显式配置的 SQLite 数据库。")
        engine = _create_sqlite_engine(SQLALCHEMY_DATABASE_URL)
    elif is_postgresql:
        try:
            engine = _create_postgresql_engine(SQLALCHEMY_DATABASE_URL)
            print("成功连接到 PostgreSQL 数据库。")
        except Exception as exc:
            if not ALLOW_SQLITE_FALLBACK:
                raise RuntimeError(
                    "PostgreSQL 数据库连接不可用，生产环境禁止自动降级 SQLite。"
                ) from exc

            print(f"PostgreSQL 数据库连接不可用 ({exc})，已按 ALLOW_SQLITE_FALLBACK=true 降级到本地 SQLite。")
            SQLALCHEMY_DATABASE_URL = "sqlite:///./item_intelli.db"
            engine = _create_sqlite_engine(SQLALCHEMY_DATABASE_URL)
    else:
        raise RuntimeError("DATABASE_URL 仅支持 postgresql 或显式启用 fallback 后的 sqlite。")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# 依赖注入，用于 FastAPI 路由获取数据库连接会话
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
