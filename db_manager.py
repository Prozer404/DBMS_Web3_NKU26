#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Web3 交易所数据库 — 命令行管理器
通过环境变量或 connect 命令连接 MySQL，支持查询/执行与高危操作警告。
"""

from __future__ import annotations

import os
import re
import shlex
import sys
from typing import Any, Callable, Optional, Tuple

try:
    import pymysql
    from pymysql.cursors import DictCursor
except ImportError:
    print("请先安装依赖: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# 高危规则：命中后需输入 YES 才执行（除 query 仅允许 SELECT）
# ---------------------------------------------------------------------------

HIGH_RISK_PATTERNS: list[Tuple[str, re.Pattern[str], str]] = [
    (
        "结构破坏",
        re.compile(r"\b(TRUNCATE|DROP\s+TABLE|DROP\s+DATABASE|ALTER\s+TABLE)\b", re.I),
        "将清空或改变表结构，可能导致数据不可恢复。",
    ),
    (
        "资金账实",
        re.compile(r"\bUPDATE\s+[`']?assets[`']?\b.*\b(balance|frozen_balance)\b", re.I | re.S),
        "直接改 assets 可用/冻结余额会破坏与 ledger_entries 流水的一致性，对账会不平。",
    ),
    (
        "流水篡改",
        re.compile(r"\b(UPDATE|DELETE)\s+[`']?ledger_entries[`']?\b", re.I),
        "流水应为追加式审计记录，修改/删除会破坏账务追溯与对账。",
    ),
    (
        "成交记录",
        re.compile(r"\b(UPDATE|DELETE)\s+[`']?trades[`']?\b", re.I),
        "成交是清算依据，事后修改/删除会导致与订单、流水不一致。",
    ),
    (
        "订单成交字段",
        re.compile(
            r"\bUPDATE\s+[`']?orders[`']?\b.*\b(filled_amount|status)\b",
            re.I | re.S,
        ),
        "改订单已成交量或状态应通过撮合/撤单业务逻辑完成，手工改易与 trades、资产冻结对不上。",
    ),
    (
        "成功充提",
        re.compile(
            r"\bDELETE\s+FROM\s+[`']?(deposits|withdrawals)[`']?\b",
            re.I,
        ),
        "删除充提记录会影响合规追溯；若需冲正请用业务单+流水，而非物理删除。",
    ),
    (
        "成功充值后改额",
        re.compile(
            r"\bUPDATE\s+[`']?deposits[`']?\b.*\b(amount|status|currency)\b",
            re.I | re.S,
        ),
        "已入账的充值单改金额/状态/币种会导致与 ledger、资产不一致。",
    ),
    (
        "成功提现后改额",
        re.compile(
            r"\bUPDATE\s+[`']?withdrawals[`']?\b.*\b(amount|status|currency|fee)\b",
            re.I | re.S,
        ),
        "已处理的提现单改关键字段会导致账务、链上记录对不上。",
    ),
    (
        "用户主键/认证",
        re.compile(r"\bDELETE\s+FROM\s+[`']?users[`']?\b", re.I),
        "删除用户可能违反外键或产生孤儿引用；通常应停用账号而非删除。",
    ),
]

MEDIUM_RISK_PATTERNS: list[Tuple[str, re.Pattern[str], str]] = [
    (
        "资产直插",
        re.compile(r"\bINSERT\s+INTO\s+[`']?assets[`']?\b", re.I),
        "资产余额应随业务与 ledger_entries 同步变更；仅 INSERT 资产行易导致与流水脱节。",
    ),
    (
        "币种主数据",
        re.compile(r"\b(UPDATE\s+[`']?currencies[`']?|DELETE\s+FROM\s+[`']?currencies[`']?)\b", re.I),
        "currencies 被多表外键引用，修改/删除可能影响交易对、资产、手续费。",
    ),
    (
        "交易对配置",
        re.compile(r"\b(UPDATE\s+[`']?trading_pairs[`']?|DELETE\s+FROM\s+[`']?trading_pairs[`']?)\b", re.I),
        "已有订单/成交引用 pair_id，随意改动可能导致历史数据语义错误。",
    ),
    (
        "KYC 审计",
        re.compile(r"\bDELETE\s+FROM\s+[`']?kyc_applications[`']?\b", re.I),
        "删除 KYC 申请记录不利于合规审计。",
    ),
]


def analyze_sql_risk(sql: str) -> Tuple[list[str], list[str]]:
    """返回 (高危说明列表, 中危说明列表)。"""
    high: list[str] = []
    medium: list[str] = []
    for name, pat, desc in HIGH_RISK_PATTERNS:
        if pat.search(sql):
            high.append(f"[高危 · {name}] {desc}")
    for name, pat, desc in MEDIUM_RISK_PATTERNS:
        if pat.search(sql):
            medium.append(f"[中危 · {name}] {desc}")
    return high, medium


def is_select_only(sql: str) -> bool:
    s = sql.strip()
    if not s:
        return False
    # 禁止多语句
    if ";" in s.rstrip(";"):
        return False
    return bool(re.match(r"^\s*SELECT\b", s, re.I))


def print_help() -> None:
    print(
        """
================================================================================
  Web3 数据库管理器 — 帮助 (/help 与 help 等价)
================================================================================

【连接】
  connect <主机> <用户> <密码> <数据库>
      例: connect 127.0.0.1 root 你的密码 Web3
  也可设置环境变量: MYSQL_HOST MYSQL_PORT MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE
      启动后若已配置则自动尝试连接。

【只读查询 — 仅允许单条 SELECT】
  query <SQL>
      例: query SELECT * FROM users LIMIT 5

【执行写操作或任意 SQL — 会扫描高危/中危并可能要求确认】
  run <SQL>
      例: run UPDATE users SET kyc_status=2 WHERE id=1
  命中高危或中危时，需输入大写 YES 才会执行。

【元数据】
  tables              列出当前库中所有表
  desc <表名>         等价于 DESCRIBE 表名（orders 为保留名请加反引号: desc `orders`）

【其它】
  help  或  /help     显示本帮助
  exit  或  quit     退出程序

【说明】
  - 本工具用于开发与课设调试，生产环境请用专门运维与审计流程。
  - 高危规则无法覆盖所有 SQL 组合；执行前请自行判断业务影响。
================================================================================
"""
    )


class Manager:
    def __init__(self) -> None:
        self.conn: Optional[Any] = None

    def connect(
        self,
        host: str,
        port: int,
        user: str,
        password: str,
        database: str,
    ) -> None:
        if self.conn:
            self.conn.close()
        self.conn = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            charset="utf8mb4",
            cursorclass=DictCursor,
            autocommit=False,
        )
        print(f"已连接: {user}@{host}:{port}/{database}")

    def ensure_conn(self) -> Any:
        if not self.conn:
            raise RuntimeError("尚未连接，请先 connect 或配置环境变量后重启。")
        return self.conn

    def cmd_tables(self, _: list[str]) -> None:
        conn = self.ensure_conn()
        with conn.cursor() as cur:
            cur.execute("SHOW TABLES")
            rows = cur.fetchall()
        # DictCursor 每行一个 dict，键名因驱动而异
        for r in rows:
            v = next(iter(r.values()))
            print(v)

    def cmd_desc(self, args: list[str]) -> None:
        if len(args) < 1:
            print("用法: desc <表名>")
            return
        table = args[0]
        conn = self.ensure_conn()
        with conn.cursor() as cur:
            cur.execute(f"DESCRIBE {table}")
            rows = cur.fetchall()
        for row in rows:
            print(row)

    def cmd_query(self, args: list[str]) -> None:
        if not args:
            print("用法: query SELECT ...")
            return
        sql = " ".join(args).strip()
        if not is_select_only(sql):
            print("错误: query 仅允许单条 SELECT 语句。")
            return
        conn = self.ensure_conn()
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
        self._print_rows(rows)

    def cmd_run(self, args: list[str]) -> None:
        if not args:
            print("用法: run <SQL>")
            return
        sql = " ".join(args).strip().rstrip(";")
        if is_select_only(sql):
            print("提示: 这是 SELECT，请用 query 命令（只读通道）。")
            return
        high, medium = analyze_sql_risk(sql)
        if high or medium:
            print("\n----- 风险扫描 -----")
            for h in high:
                print(h)
            for m in medium:
                print(m)
            print("--------------------\n")
        if high:
            confirm = input("高危操作：输入大写 YES 确认执行，其它键放弃: ").strip()
            if confirm != "YES":
                print("已取消。")
                return
        elif medium:
            confirm = input("中危操作：输入大写 YES 确认执行，其它键放弃: ").strip()
            if confirm != "YES":
                print("已取消。")
                return
        conn = self.ensure_conn()
        try:
            with conn.cursor() as cur:
                affected = cur.execute(sql)
                conn.commit()
            print(f"执行成功，受影响行数: {affected}")
        except Exception as e:
            conn.rollback()
            print(f"执行失败（已回滚）: {e}")

    @staticmethod
    def _print_rows(rows: list[Any]) -> None:
        if not rows:
            print("(无行)")
            return
        cols = list(rows[0].keys())
        print(" | ".join(cols))
        print("-" * min(120, len(" | ".join(cols)) + 20))
        for r in rows:
            print(" | ".join(str(r[c]) for c in cols))


def try_env_connect(m: Manager) -> None:
    try:
        import config as _cfg

        _cfg.load_dotenv_if_present()
        p = _cfg.get_mysql_params()
        host, port, user, password, database = (
            p["host"],
            p["port"],
            p["user"],
            p["password"],
            p["database"],
        )
    except Exception:
        host = os.environ.get("MYSQL_HOST", "127.0.0.1")
        port = int(os.environ.get("MYSQL_PORT", "3306"))
        user = os.environ.get("MYSQL_USER", "")
        password = os.environ.get("MYSQL_PASSWORD", "")
        database = os.environ.get("MYSQL_DATABASE", "")
    if user and database:
        try:
            m.connect(host, port, user, password, database)
        except Exception as e:
            print(f"环境变量自动连接失败: {e}")


def parse_line(line: str) -> Tuple[str, list[str]]:
    line = line.strip()
    if not line:
        return "", []
    # 支持 /help
    if line.startswith("/"):
        line = line[1:]
    try:
        parts = shlex.split(line, posix=False)
    except ValueError as e:
        print(f"解析错误: {e}")
        return "", []
    if not parts:
        return "", []
    cmd = parts[0].lower()
    args = parts[1:]
    return cmd, args


def repl() -> None:
    m = Manager()
    print("Web3 数据库管理器 — 输入 help 或 /help 查看命令。\n")
    try_env_connect(m)

    handlers: dict[str, Callable[[Manager, list[str]], None]] = {
        "tables": lambda mgr, a: mgr.cmd_tables(a),
        "desc": lambda mgr, a: mgr.cmd_desc(a),
        "query": lambda mgr, a: mgr.cmd_query(a),
        "run": lambda mgr, a: mgr.cmd_run(a),
    }

    while True:
        try:
            line = input("db> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见。")
            break
        cmd, args = parse_line(line)
        if not cmd:
            continue
        if cmd in ("exit", "quit", "q"):
            print("再见。")
            break
        if cmd in ("help", "?"):
            print_help()
            continue
        if cmd == "connect":
            if len(args) < 4:
                print("用法: connect <主机> <用户> <密码> <数据库>")
                continue
            host, user, password, database = args[0], args[1], args[2], args[3]
            port = int(os.environ.get("MYSQL_PORT", "3306"))
            try:
                m.connect(host, port, user, password, database)
            except Exception as e:
                print(f"连接失败: {e}")
            continue
        if cmd in handlers:
            try:
                handlers[cmd](m, args)
            except Exception as e:
                print(f"错误: {e}")
            continue
        print(f"未知命令: {cmd}，输入 help 查看帮助。")

    if m.conn:
        m.conn.close()


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1].lower() in ("-h", "--help", "help"):
        print_help()
        return
    repl()


if __name__ == "__main__":
    main()
