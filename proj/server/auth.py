import base64
import hashlib
import hmac
import json
import os
import secrets
import time
from datetime import datetime
from typing import Any

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

import models
from database import get_db

PASSWORD_ITERATIONS = 210_000
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "480"))


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _jwt_secret() -> str:
    secret = os.getenv("JWT_SECRET_KEY", "").strip()
    if not secret or secret == "change-me-to-a-long-random-secret":
        raise RuntimeError("JWT_SECRET_KEY 未配置或仍为示例值，无法签发或校验 JWT。")
    return secret


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PASSWORD_ITERATIONS,
    )
    return f"pbkdf2_sha256${PASSWORD_ITERATIONS}${salt}${digest.hex()}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, salt, expected = password_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            int(iterations),
        ).hex()
        return hmac.compare_digest(digest, expected)
    except Exception:
        return False


def create_access_token(user: models.AdminUser) -> str:
    now = int(time.time())
    payload: dict[str, Any] = {
        "sub": str(user.id),
        "username": user.username,
        "role": user.role,
        "iat": now,
        "exp": now + JWT_EXPIRE_MINUTES * 60,
    }
    header = {"alg": JWT_ALGORITHM, "typ": "JWT"}
    signing_input = ".".join(
        [
            _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8")),
            _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8")),
        ]
    )
    signature = hmac.new(
        _jwt_secret().encode("utf-8"),
        signing_input.encode("ascii"),
        hashlib.sha256,
    ).digest()
    return f"{signing_input}.{_b64url_encode(signature)}"


def decode_access_token(token: str) -> dict[str, Any]:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无效或已过期的登录凭证",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        header_b64, payload_b64, signature_b64 = token.split(".", 2)
        signing_input = f"{header_b64}.{payload_b64}"
        expected_signature = hmac.new(
            _jwt_secret().encode("utf-8"),
            signing_input.encode("ascii"),
            hashlib.sha256,
        ).digest()
        actual_signature = _b64url_decode(signature_b64)
        if not hmac.compare_digest(expected_signature, actual_signature):
            raise credentials_error

        payload = json.loads(_b64url_decode(payload_b64).decode("utf-8"))
        if int(payload.get("exp", 0)) < int(time.time()):
            raise credentials_error
        return payload
    except HTTPException:
        raise
    except Exception as exc:
        raise credentials_error from exc


def authenticate_admin(db: Session, username: str, password: str) -> models.AdminUser | None:
    user = db.query(models.AdminUser).filter(models.AdminUser.username == username).first()
    if not user or not user.is_active:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


def require_admin(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> models.AdminUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="缺少管理员登录凭证",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_access_token(authorization.removeprefix("Bearer ").strip())
    try:
        user_id = int(payload.get("sub", ""))
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效或已过期的登录凭证",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    user = db.query(models.AdminUser).filter(models.AdminUser.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员账号不存在或已停用",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def ensure_initial_admin(db: Session) -> None:
    if db.query(models.AdminUser).count() > 0:
        return

    username = os.getenv("INITIAL_ADMIN_USERNAME", "").strip()
    password = os.getenv("INITIAL_ADMIN_PASSWORD", "").strip()
    if not username or not password:
        raise RuntimeError(
            "AdminUser 表为空，必须配置 INITIAL_ADMIN_USERNAME 和 INITIAL_ADMIN_PASSWORD 初始化第一个管理员。"
        )

    db.add(
        models.AdminUser(
            username=username,
            password_hash=hash_password(password),
            role="admin",
            is_active=True,
            created_at=datetime.utcnow(),
        )
    )
    db.commit()
