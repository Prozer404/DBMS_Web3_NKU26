# -*- coding: utf-8 -*-
"""共享：MySQL 连接与行序列化（admin_server / client_routes 共用）"""

from __future__ import annotations

from contextlib import contextmanager
from decimal import Decimal
from typing import Any, Generator

import pymysql
from pymysql.cursors import DictCursor

import config

config.load_dotenv_if_present()


def serialize_row(row: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for k, v in row.items():
        if isinstance(v, Decimal):
            out[k] = str(v)
        elif hasattr(v, "isoformat"):
            out[k] = v.isoformat(sep=" ", timespec="seconds")
        else:
            out[k] = v
    return out


@contextmanager
def get_db() -> Generator[pymysql.connections.Connection, None, None]:
    p = config.get_mysql_params()
    conn = pymysql.connect(
        host=p["host"],
        port=int(p["port"]),
        user=p["user"],
        password=p["password"],
        database=p["database"],
        charset="utf8mb4",
        cursorclass=DictCursor,
        autocommit=False,
    )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
