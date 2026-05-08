-- 虚拟货币交易平台 — 核心表结构（MySQL 8+，InnoDB）
-- 在已创建库 Web3 下执行；若库名不同，请修改下一行
USE Web3;

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 1. 用户与权限 (User & Auth)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id BIGINT NOT NULL AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  kyc_status TINYINT NOT NULL DEFAULT 0 COMMENT '0未认证 1审核中 2已通过',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='用户表（含KYC）';

-- ---------------------------------------------------------------------------
-- 2. 市场配置（先于订单，被 orders / trades 引用）
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trading_pairs (
  id BIGINT NOT NULL AUTO_INCREMENT,
  base_currency VARCHAR(32) NOT NULL,
  quote_currency VARCHAR(32) NOT NULL,
  min_order_amount DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000,
  price_precision INT NOT NULL DEFAULT 8,
  amount_precision INT NOT NULL DEFAULT 8,
  PRIMARY KEY (id),
  UNIQUE KEY uk_trading_pairs_base_quote (base_currency, quote_currency)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='交易对配置';

-- ---------------------------------------------------------------------------
-- 3. 资产与钱包
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assets (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  currency VARCHAR(32) NOT NULL,
  balance DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '可用余额',
  frozen_balance DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '冻结余额',
  PRIMARY KEY (id),
  UNIQUE KEY uk_assets_user_currency (user_id, currency),
  CONSTRAINT fk_assets_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='用户资产（可用/冻结分离）';

CREATE TABLE IF NOT EXISTS ledger_entries (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  currency VARCHAR(32) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL COMMENT '正入账负出账',
  balance_after DECIMAL(20, 8) NOT NULL COMMENT '变动后可用余额快照',
  `type` VARCHAR(32) NOT NULL COMMENT 'RECHARGE/WITHDRAW/ORDER_FREEZE/ORDER_UNFREEZE/TRADE_BUY/TRADE_SELL/FEE',
  ref_id VARCHAR(64) NULL COMMENT '订单号、提现单号等业务关联',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ledger_user_time (user_id, created_at),
  KEY idx_ledger_currency_time (currency, created_at),
  KEY idx_ledger_ref (ref_id),
  CONSTRAINT fk_ledger_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='资金流水与审计';

-- ---------------------------------------------------------------------------
-- 4. 订单与成交
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `orders` (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  pair_id BIGINT NOT NULL,
  side TINYINT NOT NULL COMMENT '1买入 2卖出',
  `type` TINYINT NOT NULL COMMENT '1限价 2市价',
  price DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000,
  total_amount DECIMAL(20, 8) NOT NULL,
  filled_amount DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待成交 1部分成交 2完全成交 3已撤销',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_orders_user (user_id),
  KEY idx_orders_pair (pair_id),
  KEY idx_orders_status (status),
  KEY idx_orders_created (created_at),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_orders_pair FOREIGN KEY (pair_id) REFERENCES trading_pairs (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='订单';

CREATE TABLE IF NOT EXISTS trades (
  id BIGINT NOT NULL AUTO_INCREMENT,
  buy_order_id BIGINT NOT NULL,
  sell_order_id BIGINT NOT NULL,
  pair_id BIGINT NOT NULL,
  price DECIMAL(20, 8) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL,
  fee DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_trades_pair_time (pair_id, created_at),
  KEY idx_trades_buy (buy_order_id),
  KEY idx_trades_sell (sell_order_id),
  CONSTRAINT fk_trades_buy_order FOREIGN KEY (buy_order_id) REFERENCES `orders` (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_trades_sell_order FOREIGN KEY (sell_order_id) REFERENCES `orders` (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_trades_pair FOREIGN KEY (pair_id) REFERENCES trading_pairs (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='成交记录（清算依据）';

-- ---------------------------------------------------------------------------
-- 5. 充值与提现
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS deposits (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  currency VARCHAR(32) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待确认 1成功 2失败',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_deposits_user (user_id),
  KEY idx_deposits_status (status),
  CONSTRAINT fk_deposits_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='充值记录';

CREATE TABLE IF NOT EXISTS withdrawals (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  currency VARCHAR(32) NOT NULL,
  address VARCHAR(512) NOT NULL,
  amount DECIMAL(20, 8) NOT NULL,
  fee DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000,
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0审核中 1处理中 2成功 3驳回',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_withdrawals_user (user_id),
  KEY idx_withdrawals_status (status),
  CONSTRAINT fk_withdrawals_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='提现记录';
