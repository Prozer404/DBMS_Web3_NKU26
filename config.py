# -*- coding: utf-8 -*-
"""
数据库连接配置：从环境变量或项目根目录 .env 读取。
优先级：分项 MYSQL_* ；若未设置库名且存在 DATABASE_URL，则解析 URL。

供后续 FastAPI/Flask 与 db_manager 共用（db_manager 会自行 load_dotenv，此处也可显式调用 load_dotenv_if_present）。
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

_ENV_FILE = Path(__file__).resolve().parent / ".env"


def load_dotenv_if_present() -> None:
    """加载项目根目录 .env（不覆盖已在环境中设置的变量）。"""
    if not _ENV_FILE.is_file():
        return
    try:
        from dotenv import load_dotenv

        load_dotenv(_ENV_FILE, override=False)
    except ImportError:
        pass


def _parse_database_url(url: str) -> dict[str, Any]:
    """
    解析 DATABASE_URL，例如：
    mysql+pymysql://user:pass@127.0.0.1:3306/Web3?charset=utf8mb4
    mysql://user:pass@host:3306/dbname
    密码中含特殊字符时请做 URL 编码（如 @ -> %40）。
    """
    u = urlparse(url)
    if not u.hostname:
        raise ValueError("DATABASE_URL 中缺少主机名")
    database = (u.path or "").lstrip("/").split("?")[0]
    if not database:
        raise ValueError("DATABASE_URL 中缺少库名（路径部分）")
    return {
        "host": u.hostname,
        "port": u.port or 3306,
        "user": unquote(u.username or ""),
        "password": unquote(u.password or ""),
        "database": database,
    }


def get_mysql_params() -> dict[str, Any]:
    """
    返回 pymysql.connect 可用关键字：host, port, user, password, database
    """
    load_dotenv_if_present()

    url = (os.environ.get("DATABASE_URL") or "").strip()
    has_piecewise = bool(os.environ.get("MYSQL_DATABASE") or os.environ.get("MYSQL_USER"))

    if url and not has_piecewise:
        return _parse_database_url(url)

    return {
        "host": os.environ.get("MYSQL_HOST", "127.0.0.1"),
        "port": int(os.environ.get("MYSQL_PORT", "3306")),
        "user": os.environ.get("MYSQL_USER", "root"),
        "password": os.environ.get("MYSQL_PASSWORD", ""),
        "database": os.environ.get("MYSQL_DATABASE", "Web3"),
    }


def get_sqlalchemy_database_url() -> str:
    """
    SQLAlchemy 2 常用：create_engine(get_sqlalchemy_database_url())
    若设置了 DATABASE_URL 且为 mysql+pymysql 开头则直接返回；
    否则由分项拼出。
    """
    load_dotenv_if_present()
    raw = (os.environ.get("DATABASE_URL") or "").strip()
    if raw.startswith("mysql+pymysql://") or raw.startswith("mysql://"):
        if raw.startswith("mysql://"):
            return raw.replace("mysql://", "mysql+pymysql://", 1)
        return raw
    p = get_mysql_params()
    from urllib.parse import quote_plus

    user = quote_plus(p["user"])
    pwd = quote_plus(p["password"])
    host = p["host"]
    port = p["port"]
    db = quote_plus(p["database"])
    return f"mysql+pymysql://{user}:{pwd}@{host}:{port}/{db}?charset=utf8mb4"
