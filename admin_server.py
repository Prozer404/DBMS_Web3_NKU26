#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Web3 交易所：FastAPI 统一服务用户端与管理端静态页，经 pymysql 访问 MySQL。
启动: uvicorn admin_server:app --reload --host 127.0.0.1 --port 8080
用户端: http://127.0.0.1:8080/user/   管理端: http://127.0.0.1:8080/admin/
"""

from __future__ import annotations

import os
import warnings
from typing import Any, Optional

import pymysql
from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from database import get_db, serialize_row as _serialize_row

_STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "admin")
_STATIC_USER_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "user")


def verify_admin(x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key")) -> None:
    expected = (os.environ.get("ADMIN_API_KEY") or "").strip()
    if not expected:
        return
    if (x_admin_key or "").strip() != expected:
        raise HTTPException(status_code=401, detail="无效或未提供 X-Admin-Key")


app = FastAPI(title="Web3 Exchange", version="0.1")

from client_routes import router as client_router  # noqa: E402

app.include_router(client_router)


@app.on_event("startup")
def _startup() -> None:
    if not (os.environ.get("ADMIN_API_KEY") or "").strip():
        warnings.warn(
            "未设置 ADMIN_API_KEY：管理 API 对任何人开放，仅用于本机演示。请在 .env 中设置。",
            stacklevel=1,
        )


@app.get("/api/health")
def health() -> dict[str, Any]:
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 AS ok")
                cur.fetchone()
        return {"ok": True, "database": "connected"}
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={"ok": False, "error": str(e)},
        )


@app.get("/api/admin/meta")
def admin_meta(_: None = Depends(verify_admin)) -> dict[str, Any]:
    return {
        "auth_required": bool((os.environ.get("ADMIN_API_KEY") or "").strip()),
        "tables": [
            "users",
            "currencies",
            "trading_pairs",
            "kyc_applications",
            "deposits",
            "withdrawals",
        ],
    }


# ----- users -----
@app.get("/api/admin/users")
def list_users(
    _: None = Depends(verify_admin),
    limit: int = Query(200, ge=1, le=500),
) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, email, kyc_status, created_at, updated_at FROM users ORDER BY id DESC LIMIT %s",
                (limit,),
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class UserKycPatch(BaseModel):
    kyc_status: int = Field(..., ge=0, le=3)


@app.patch("/api/admin/users/{user_id}")
def patch_user_kyc(
    user_id: int,
    body: UserKycPatch,
    _: None = Depends(verify_admin),
) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE users SET kyc_status = %s WHERE id = %s",
                (body.kyc_status, user_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(404, "用户不存在")
    return {"ok": True, "id": user_id, "kyc_status": body.kyc_status}


class UserCreate(BaseModel):
    email: str = Field(..., max_length=100)
    password_hash: str = Field(..., max_length=255)
    kyc_status: int = Field(0, ge=0, le=3)


@app.post("/api/admin/users")
def create_user(body: UserCreate, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    "INSERT INTO users (email, password_hash, kyc_status) VALUES (%s, %s, %s)",
                    (body.email.strip(), body.password_hash, body.kyc_status),
                )
                uid = cur.lastrowid
            except pymysql.err.IntegrityError as e:
                raise HTTPException(409, f"违反约束: {e}") from e
    return {"ok": True, "id": uid}


@app.delete("/api/admin/users/{user_id}")
def delete_user(user_id: int, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
                if cur.rowcount == 0:
                    raise HTTPException(404, "用户不存在")
            except pymysql.err.IntegrityError as e:
                raise HTTPException(409, f"存在外键引用，无法删除: {e}") from e
    return {"ok": True, "deleted": user_id}


# ----- currencies -----
@app.get("/api/admin/currencies")
def list_currencies(_: None = Depends(verify_admin)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT code, name, `precision`, withdrawal_fee, min_withdrawal, is_active FROM currencies ORDER BY code"
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class CurrencyCreate(BaseModel):
    code: str = Field(..., max_length=10)
    name: str = Field(..., max_length=50)
    precision: int = Field(8, ge=0, le=18)
    withdrawal_fee: str = "0"
    min_withdrawal: str = "0"
    is_active: int = Field(1, ge=0, le=1)


@app.post("/api/admin/currencies")
def create_currency(body: CurrencyCreate, _: None = Depends(verify_admin)) -> dict[str, Any]:
    code = body.code.strip().upper()
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO currencies (code, name, `precision`, withdrawal_fee, min_withdrawal, is_active) VALUES (%s,%s,%s,%s,%s,%s)",
                (
                    code,
                    body.name,
                    body.precision,
                    body.withdrawal_fee,
                    body.min_withdrawal,
                    body.is_active,
                ),
            )
    return {"ok": True, "code": code}


class CurrencyPatch(BaseModel):
    name: Optional[str] = None
    precision: Optional[int] = Field(None, ge=0, le=18)
    withdrawal_fee: Optional[str] = None
    min_withdrawal: Optional[str] = None
    is_active: Optional[int] = Field(None, ge=0, le=1)


@app.patch("/api/admin/currencies/{code}")
def patch_currency(
    code: str,
    body: CurrencyPatch,
    _: None = Depends(verify_admin),
) -> dict[str, Any]:
    fields: list[str] = []
    vals: list[Any] = []
    if body.name is not None:
        fields.append("name = %s")
        vals.append(body.name)
    if body.precision is not None:
        fields.append("`precision` = %s")
        vals.append(body.precision)
    if body.withdrawal_fee is not None:
        fields.append("withdrawal_fee = %s")
        vals.append(body.withdrawal_fee)
    if body.min_withdrawal is not None:
        fields.append("min_withdrawal = %s")
        vals.append(body.min_withdrawal)
    if body.is_active is not None:
        fields.append("is_active = %s")
        vals.append(body.is_active)
    if not fields:
        raise HTTPException(400, "无更新字段")
    vals.append(code)
    sql = f"UPDATE currencies SET {', '.join(fields)} WHERE code = %s"
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, vals)
            if cur.rowcount == 0:
                raise HTTPException(404, "币种不存在")
    return {"ok": True, "code": code}


@app.delete("/api/admin/currencies/{code}")
def delete_currency(code: str, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("DELETE FROM currencies WHERE code = %s", (code,))
                if cur.rowcount == 0:
                    raise HTTPException(404, "币种不存在")
            except pymysql.err.IntegrityError as e:
                raise HTTPException(409, f"仍被引用，无法删除: {e}") from e
    return {"ok": True, "deleted": code}


# ----- trading_pairs -----
@app.get("/api/admin/trading-pairs")
def list_pairs(_: None = Depends(verify_admin)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, base_currency, quote_currency, min_order_amount, price_precision, amount_precision FROM trading_pairs ORDER BY id"
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class PairCreate(BaseModel):
    base_currency: str = Field(..., max_length=10)
    quote_currency: str = Field(..., max_length=10)
    min_order_amount: str
    price_precision: int = Field(2, ge=0)
    amount_precision: int = Field(8, ge=0)


@app.post("/api/admin/trading-pairs")
def create_pair(body: PairCreate, _: None = Depends(verify_admin)) -> dict[str, Any]:
    b, q = body.base_currency.strip().upper(), body.quote_currency.strip().upper()
    if b == q:
        raise HTTPException(400, "基础币与计价币不能相同")
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute(
                    "INSERT INTO trading_pairs (base_currency, quote_currency, min_order_amount, price_precision, amount_precision) VALUES (%s,%s,%s,%s,%s)",
                    (b, q, body.min_order_amount, body.price_precision, body.amount_precision),
                )
                pid = cur.lastrowid
            except pymysql.err.IntegrityError as e:
                raise HTTPException(409, str(e)) from e
    return {"ok": True, "id": pid}


class PairPatch(BaseModel):
    min_order_amount: Optional[str] = None
    price_precision: Optional[int] = Field(None, ge=0)
    amount_precision: Optional[int] = Field(None, ge=0)


@app.patch("/api/admin/trading-pairs/{pair_id}")
def patch_pair(
    pair_id: int,
    body: PairPatch,
    _: None = Depends(verify_admin),
) -> dict[str, Any]:
    fields: list[str] = []
    vals: list[Any] = []
    if body.min_order_amount is not None:
        fields.append("min_order_amount = %s")
        vals.append(body.min_order_amount)
    if body.price_precision is not None:
        fields.append("price_precision = %s")
        vals.append(body.price_precision)
    if body.amount_precision is not None:
        fields.append("amount_precision = %s")
        vals.append(body.amount_precision)
    if not fields:
        raise HTTPException(400, "无更新字段")
    vals.append(pair_id)
    sql = f"UPDATE trading_pairs SET {', '.join(fields)} WHERE id = %s"
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, vals)
            if cur.rowcount == 0:
                raise HTTPException(404, "交易对不存在")
    return {"ok": True, "id": pair_id}


@app.delete("/api/admin/trading-pairs/{pair_id}")
def delete_pair(pair_id: int, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("DELETE FROM trading_pairs WHERE id = %s", (pair_id,))
                if cur.rowcount == 0:
                    raise HTTPException(404, "交易对不存在")
            except pymysql.err.IntegrityError as e:
                raise HTTPException(409, f"存在订单/成交引用: {e}") from e
    return {"ok": True, "deleted": pair_id}


# ----- kyc -----
@app.get("/api/admin/kyc-applications")
def list_kyc(_: None = Depends(verify_admin), limit: int = Query(200, ge=1, le=500)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, user_id, real_name, id_card_number, document_url, status,
                          reject_reason, reviewer_id, created_at, updated_at
                   FROM kyc_applications ORDER BY id DESC LIMIT %s""",
                (limit,),
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class KycPatch(BaseModel):
    status: int = Field(..., ge=0, le=2)
    reject_reason: Optional[str] = None
    reviewer_id: Optional[int] = None


@app.patch("/api/admin/kyc-applications/{kyc_id}")
def patch_kyc(kyc_id: int, body: KycPatch, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE kyc_applications SET status = %s, reject_reason = %s, reviewer_id = %s WHERE id = %s",
                (body.status, body.reject_reason, body.reviewer_id, kyc_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(404, "记录不存在")
            cur.execute("SELECT user_id FROM kyc_applications WHERE id = %s", (kyc_id,))
            row = cur.fetchone()
            uid = row["user_id"] if row else None
            if uid is not None:
                user_kyc = {0: 1, 1: 2, 2: 3}.get(body.status, 1)
                cur.execute("UPDATE users SET kyc_status = %s WHERE id = %s", (user_kyc, uid))
    return {"ok": True, "id": kyc_id}


# ----- deposits -----
@app.get("/api/admin/deposits")
def list_deposits(_: None = Depends(verify_admin), limit: int = Query(200, ge=1, le=500)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, currency, amount, tx_hash, status, created_at, updated_at FROM deposits ORDER BY id DESC LIMIT %s",
                (limit,),
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class DepositPatch(BaseModel):
    status: int = Field(..., ge=0, le=2)
    tx_hash: Optional[str] = None


@app.patch("/api/admin/deposits/{dep_id}")
def patch_deposit(dep_id: int, body: DepositPatch, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, user_id, currency, amount, status FROM deposits WHERE id = %s FOR UPDATE",
                (dep_id,),
            )
            dep = cur.fetchone()
            if not dep:
                raise HTTPException(404, "记录不存在")

            old_status = int(dep["status"])
            new_status = int(body.status)

            # 首次置为「成功」时入账：更新/插入 assets + 写 ledger（避免重复入账）
            if new_status == 1 and old_status != 1:
                uid = int(dep["user_id"])
                currency = str(dep["currency"])
                amt = dep["amount"]

                cur.execute(
                    "SELECT id, balance, frozen_balance FROM assets WHERE user_id = %s AND currency = %s FOR UPDATE",
                    (uid, currency),
                )
                asset = cur.fetchone()
                if asset:
                    cur.execute(
                        "UPDATE assets SET balance = balance + %s WHERE id = %s",
                        (amt, asset["id"]),
                    )
                else:
                    cur.execute(
                        "INSERT INTO assets (user_id, currency, balance, frozen_balance) VALUES (%s, %s, %s, 0)",
                        (uid, currency, amt),
                    )

                cur.execute(
                    "SELECT balance, frozen_balance FROM assets WHERE user_id = %s AND currency = %s",
                    (uid, currency),
                )
                snap = cur.fetchone()
                if not snap:
                    raise HTTPException(500, "入账后未读到资产行")

                cur.execute(
                    "INSERT INTO ledger_entries (user_id, currency, amount, balance_after, frozen_balance_after, "
                    "ref_type, ref_id, `type`) VALUES (%s, %s, %s, %s, %s, 'DEPOSIT', %s, 'RECHARGE')",
                    (uid, currency, amt, snap["balance"], snap["frozen_balance"], dep_id),
                )

            if body.tx_hash is not None:
                cur.execute(
                    "UPDATE deposits SET status = %s, tx_hash = %s WHERE id = %s",
                    (new_status, body.tx_hash, dep_id),
                )
            else:
                cur.execute("UPDATE deposits SET status = %s WHERE id = %s", (new_status, dep_id))
    return {"ok": True, "id": dep_id}


# ----- withdrawals -----
@app.get("/api/admin/withdrawals")
def list_withdrawals(_: None = Depends(verify_admin), limit: int = Query(200, ge=1, le=500)) -> list[dict[str, Any]]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, user_id, currency, address, amount, fee, status, tx_hash,
                          reviewer_id, reject_reason, created_at, updated_at
                   FROM withdrawals ORDER BY id DESC LIMIT %s""",
                (limit,),
            )
            rows = cur.fetchall()
    return [_serialize_row(r) for r in rows]


class WithdrawalPatch(BaseModel):
    status: int = Field(..., ge=0, le=3)
    tx_hash: Optional[str] = None
    reject_reason: Optional[str] = None
    reviewer_id: Optional[int] = None


@app.patch("/api/admin/withdrawals/{wd_id}")
def patch_withdrawal(wd_id: int, body: WithdrawalPatch, _: None = Depends(verify_admin)) -> dict[str, Any]:
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """UPDATE withdrawals SET status = %s, tx_hash = COALESCE(%s, tx_hash),
                   reject_reason = COALESCE(%s, reject_reason), reviewer_id = COALESCE(%s, reviewer_id)
                   WHERE id = %s""",
                (body.status, body.tx_hash, body.reject_reason, body.reviewer_id, wd_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(404, "记录不存在")
    return {"ok": True, "id": wd_id}


# ----- static -----
if os.path.isdir(_STATIC_USER_DIR):
    app.mount("/user", StaticFiles(directory=_STATIC_USER_DIR, html=True), name="user")
if os.path.isdir(_STATIC_DIR):
    app.mount("/admin", StaticFiles(directory=_STATIC_DIR, html=True), name="admin")


@app.get("/")
def root() -> RedirectResponse:
    return RedirectResponse(url="/user/")
