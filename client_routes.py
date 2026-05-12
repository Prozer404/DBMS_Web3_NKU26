# -*- coding: utf-8 -*-
"""
用户端 API：注册/登录(JWT)、资产、流水、订单、充提、KYC、公开行情。
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any, Optional

import bcrypt
import jwt
import pymysql
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field

from database import get_db, serialize_row

router = APIRouter(prefix="/api", tags=["client"])

JWT_SECRET = os.environ.get("JWT_SECRET", "dev-jwt-secret-change-in-production")
JWT_ALG = "HS256"
JWT_EXPIRE_HOURS = int(os.environ.get("JWT_EXPIRE_HOURS", "72"))

security = HTTPBearer(auto_error=False)


def _hash_password(plain: str) -> str:
    """使用 bcrypt 4.x 兼容方式，避免 passlib 与新版 bcrypt 不兼容。"""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("ascii")


def _verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("ascii"))
    except Exception:
        return False


def _token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=JWT_EXPIRE_HOURS)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def get_user_id(
    cred: Annotated[Optional[HTTPAuthorizationCredentials], Depends(security)],
) -> int:
    if not cred or not cred.credentials:
        raise HTTPException(status_code=401, detail="未登录或缺少 Bearer Token")
    try:
        payload = jwt.decode(cred.credentials, JWT_SECRET, algorithms=[JWT_ALG])
        return int(payload["sub"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录") from None
    except Exception as e:
        raise HTTPException(status_code=401, detail="无效令牌") from e


# ----- public -----
@router.get("/public/pairs")
def public_pairs() -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, base_currency, quote_currency, min_order_amount, price_precision, amount_precision "
                "FROM trading_pairs ORDER BY id"
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


@router.get("/public/currencies")
def public_currencies() -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT code, name, `precision`, withdrawal_fee, min_withdrawal, is_active "
                "FROM currencies WHERE is_active = 1 ORDER BY code"
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


# ----- auth -----
class RegisterBody(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=128)


@router.post("/auth/register")
def auth_register(body: RegisterBody) -> dict[str, Any]:
    email = body.email.strip().lower()
    ph = _hash_password(body.password)
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    "INSERT INTO users (email, password_hash, kyc_status) VALUES (%s, %s, 0)",
                    (email, ph),
                )
                uid = cur.lastrowid
            except pymysql.err.IntegrityError:
                raise HTTPException(409, "该邮箱已注册") from None
    token = _token(uid)
    return {"access_token": token, "token_type": "bearer", "user": {"id": uid, "email": email}}


class LoginBody(BaseModel):
    email: EmailStr
    password: str


@router.post("/auth/login")
def auth_login(body: LoginBody) -> dict[str, Any]:
    email = body.email.strip().lower()
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, password_hash, kyc_status FROM users WHERE email = %s",
                (email,),
            )
            row = cur.fetchone()
    if not row or not _verify_password(body.password, row["password_hash"]):
        raise HTTPException(401, "邮箱或密码错误")
    token = _token(int(row["id"]))
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": row["id"],
            "email": row["email"],
            "kyc_status": row["kyc_status"],
        },
    }


# ----- me -----
@router.get("/me")
def me(uid: int = Depends(get_user_id)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, kyc_status, created_at, updated_at FROM users WHERE id = %s",
                (uid,),
            )
            row = cur.fetchone()
    if not row:
        raise HTTPException(404, "用户不存在")
    return serialize_row(row)


@router.get("/me/assets")
def me_assets(uid: int = Depends(get_user_id)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, currency, balance, frozen_balance FROM assets WHERE user_id = %s ORDER BY currency",
                (uid,),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


@router.get("/me/ledger")
def me_ledger(
    uid: int = Depends(get_user_id),
    limit: int = Query(100, ge=1, le=500),
) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, currency, amount, balance_after, frozen_balance_after, ref_type, ref_id, `type`, created_at "
                "FROM ledger_entries WHERE user_id = %s ORDER BY id DESC LIMIT %s",
                (uid, limit),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


@router.get("/me/orders")
def me_orders(uid: int = Depends(get_user_id), limit: int = Query(50, ge=1, le=200)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, pair_id, side, `type`, price, total_amount, filled_amount, status, created_at, updated_at "
                "FROM `orders` WHERE user_id = %s ORDER BY id DESC LIMIT %s",
                (uid, limit),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


class OrderCreate(BaseModel):
    pair_id: int = Field(..., ge=1)
    side: int = Field(..., ge=1, le=2)
    order_type: int = Field(..., ge=1, le=2, description="1限价 2市价")
    price: str = "0"
    total_amount: str


@router.post("/me/orders")
def me_order_create(body: OrderCreate, uid: int = Depends(get_user_id)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM trading_pairs WHERE id = %s", (body.pair_id,))
            if not cur.fetchone():
                raise HTTPException(404, "交易对不存在")
            cur.execute(
                "INSERT INTO `orders` (user_id, pair_id, side, `type`, price, total_amount, filled_amount, status) "
                "VALUES (%s,%s,%s,%s,%s,%s,0,0)",
                (uid, body.pair_id, body.side, body.order_type, body.price, body.total_amount),
            )
            oid = cur.lastrowid
    return {"ok": True, "id": oid}


@router.post("/me/orders/{order_id}/cancel")
def me_order_cancel(order_id: int, uid: int = Depends(get_user_id)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE `orders` SET status = 3 WHERE id = %s AND user_id = %s AND status IN (0, 1)",
                (order_id, uid),
            )
            if cur.rowcount == 0:
                raise HTTPException(400, "无法撤单（不存在、非本人或已终态）")
    return {"ok": True, "id": order_id}


@router.get("/me/trades")
def me_trades(uid: int = Depends(get_user_id), limit: int = Query(50, ge=1, le=200)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT DISTINCT t.id, t.pair_id, t.maker_order_id, t.taker_order_id, t.price, t.amount,
                          t.fee_amount, t.fee_currency, t.created_at
                   FROM trades t
                   WHERE EXISTS (
                     SELECT 1 FROM `orders` o
                     WHERE o.user_id = %s AND (o.id = t.maker_order_id OR o.id = t.taker_order_id)
                   )
                   ORDER BY t.id DESC LIMIT %s""",
                (uid, limit),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


@router.get("/me/deposits")
def me_deposits(uid: int = Depends(get_user_id), limit: int = Query(50, ge=1, le=200)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, currency, amount, tx_hash, status, created_at, updated_at FROM deposits "
                "WHERE user_id = %s ORDER BY id DESC LIMIT %s",
                (uid, limit),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


class DepositCreate(BaseModel):
    currency: str = Field(..., max_length=10)
    amount: str
    tx_hash: Optional[str] = None


@router.post("/me/deposits")
def me_deposit_create(body: DepositCreate, uid: int = Depends(get_user_id)) -> dict[str, Any]:
    ccy = body.currency.strip().upper()
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT code FROM currencies WHERE code = %s", (ccy,))
            if not cur.fetchone():
                raise HTTPException(400, "未知币种")
            cur.execute(
                "INSERT INTO deposits (user_id, currency, amount, tx_hash, status) VALUES (%s,%s,%s,%s,0)",
                (uid, ccy, body.amount, body.tx_hash),
            )
            did = cur.lastrowid
    return {"ok": True, "id": did}


@router.get("/me/withdrawals")
def me_withdrawals(uid: int = Depends(get_user_id), limit: int = Query(50, ge=1, le=200)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, user_id, currency, address, amount, fee, status, tx_hash,
                          reviewer_id, reject_reason, created_at, updated_at
                   FROM withdrawals WHERE user_id = %s ORDER BY id DESC LIMIT %s""",
                (uid, limit),
            )
            rows = cur.fetchall()
    return [serialize_row(r) for r in rows]


class WithdrawalCreate(BaseModel):
    currency: str = Field(..., max_length=10)
    address: str = Field(..., min_length=8, max_length=512)
    amount: str


@router.post("/me/withdrawals")
def me_withdrawal_create(body: WithdrawalCreate, uid: int = Depends(get_user_id)) -> dict[str, Any]:
    ccy = body.currency.strip().upper()
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT withdrawal_fee FROM currencies WHERE code = %s AND is_active = 1",
                (ccy,),
            )
            crow = cur.fetchone()
            if not crow:
                raise HTTPException(400, "币种不可用")
            fee = str(crow["withdrawal_fee"])
            cur.execute(
                "INSERT INTO withdrawals (user_id, currency, address, amount, fee, status) VALUES (%s,%s,%s,%s,%s,0)",
                (uid, ccy, body.address.strip(), body.amount, fee),
            )
            wid = cur.lastrowid
    return {"ok": True, "id": wid}


class KycSubmitBody(BaseModel):
    real_name: str = Field(..., max_length=100)
    id_card_number: str = Field(..., max_length=50)
    document_url: Optional[str] = Field(None, max_length=255)


@router.post("/me/kyc")
def me_kyc_submit(body: KycSubmitBody, uid: int = Depends(get_user_id)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO kyc_applications (user_id, real_name, id_card_number, document_url, status) "
                "VALUES (%s,%s,%s,%s,0)",
                (uid, body.real_name.strip(), body.id_card_number.strip(), body.document_url),
            )
            kid = cur.lastrowid
            cur.execute("UPDATE users SET kyc_status = 1 WHERE id = %s", (uid,))
    return {"ok": True, "id": kid}
