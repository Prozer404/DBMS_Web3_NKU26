-- =============================================================================
-- 虚拟货币交易所 — 修订版全量建表脚本（MySQL 8.0.16+，InnoDB）
-- 说明：含 currencies 规范化、KYC 子表、流水双快照、成交 Maker/Taker、
--       充提链上哈希与审计时间、部分 CHECK 约束。
-- 执行前请使用空库或先 DROP 旧表（注意外键顺序）。
-- 一键删库重建：先执行 rebuild_web3_full.sql，再执行 seed_web3.sql。
-- =============================================================================

SET NAMES utf8mb4;
-- 请在客户端选中库 Web3，或在本文件开头自行添加 USE Web3;

-- -----------------------------------------------------------------------------
-- 1. 基础配置：币种与交易对
-- -----------------------------------------------------------------------------

-- 币种主数据：全库资产/手续费/交易对侧统一引用 code，避免硬编码与拼写漂移
CREATE TABLE IF NOT EXISTS currencies (
  code VARCHAR(10) NOT NULL COMMENT '币种代码，如 BTC、USDT、ETH，全库唯一',
  name VARCHAR(50) NOT NULL COMMENT '展示名称，如 比特币、泰达币',
  `precision` INT NOT NULL DEFAULT 8 COMMENT '链上/账内统一小数位数（展示与校验用）；列名保留 precision 时需反引号',
  withdrawal_fee DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '默认提币手续费（可按币种覆盖策略）',
  min_withdrawal DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '最小提币额',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1启用 0停用，停用后禁止新开仓与充值路由',
  PRIMARY KEY (code),
  CONSTRAINT chk_currencies_precision CHECK (`precision` >= 0 AND `precision` <= 18),
  CONSTRAINT chk_currencies_withdrawal_fee CHECK (withdrawal_fee >= 0),
  CONSTRAINT chk_currencies_min_withdrawal CHECK (min_withdrawal >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='币种配置主表';

-- 交易对：base/quote 必须已存在于 currencies，保证可交易标的合法
CREATE TABLE IF NOT EXISTS trading_pairs (
  id INT NOT NULL AUTO_INCREMENT COMMENT '交易对主键',
  base_currency VARCHAR(10) NOT NULL COMMENT '基础资产代码，对应 currencies.code',
  quote_currency VARCHAR(10) NOT NULL COMMENT '计价资产代码，对应 currencies.code',
  min_order_amount DECIMAL(20, 8) NOT NULL COMMENT '单笔最小委托数量（基础资产计量）',
  price_precision INT NOT NULL DEFAULT 2 COMMENT '委托价小数位',
  amount_precision INT NOT NULL DEFAULT 8 COMMENT '委托量小数位',
  PRIMARY KEY (id),
  UNIQUE KEY uk_trading_pairs_base_quote (base_currency, quote_currency),
  CONSTRAINT fk_tp_base_currency FOREIGN KEY (base_currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_tp_quote_currency FOREIGN KEY (quote_currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_tp_distinct_ccy CHECK (base_currency <> quote_currency),
  CONSTRAINT chk_tp_min_order CHECK (min_order_amount > 0),
  CONSTRAINT chk_tp_precisions CHECK (price_precision >= 0 AND amount_precision >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='交易对配置';

-- -----------------------------------------------------------------------------
-- 2. 用户与合规
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '用户主键',
  email VARCHAR(100) NOT NULL COMMENT '登录邮箱，全库唯一',
  password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希（bcrypt/argon2 等），禁止明文',
  kyc_status TINYINT NOT NULL DEFAULT 0 COMMENT '0未认证 1审核中 2已通过 3已拒绝',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '资料最后更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email),
  CONSTRAINT chk_users_kyc CHECK (kyc_status IN (0, 1, 2, 3))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='用户主表';

-- KYC 申请流水：与 users.kyc_status 配合，体现审核轨迹与拒绝原因（生产环境证件号需脱敏/加密存储）
CREATE TABLE IF NOT EXISTS kyc_applications (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT 'KYC 申请单主键',
  user_id BIGINT NOT NULL COMMENT '申请人',
  real_name VARCHAR(100) NOT NULL COMMENT '真实姓名',
  id_card_number VARCHAR(50) NOT NULL COMMENT '证件号（演示库明文；生产应加密或令牌化）',
  document_url VARCHAR(255) NULL COMMENT '证件影像存储路径或对象存储 URL',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待审核 1通过 2拒绝',
  reject_reason VARCHAR(255) NULL COMMENT '拒绝原因，status=2 时建议必填',
  reviewer_id BIGINT NULL COMMENT '审核人，可为运营子账号，对应 users.id',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '提交时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '审核状态最后更新时间',
  PRIMARY KEY (id),
  KEY idx_kyc_user (user_id),
  KEY idx_kyc_status (status),
  CONSTRAINT fk_kyc_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_kyc_reviewer FOREIGN KEY (reviewer_id) REFERENCES users (id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT chk_kyc_app_status CHECK (status IN (0, 1, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='KYC 申请与审核记录';

-- -----------------------------------------------------------------------------
-- 3. 资产与钱包
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS assets (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '资产行主键',
  user_id BIGINT NOT NULL COMMENT '所属用户',
  currency VARCHAR(10) NOT NULL COMMENT '币种代码，引用 currencies.code',
  balance DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '可用余额',
  frozen_balance DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '冻结余额（挂单、提现审核中等）',
  PRIMARY KEY (id),
  UNIQUE KEY uk_assets_user_currency (user_id, currency),
  CONSTRAINT fk_assets_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_assets_currency FOREIGN KEY (currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_assets_balance_nonneg CHECK (balance >= 0 AND frozen_balance >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='用户资产（可用/冻结分桶）';

-- 资金流水：追加式记账。ref_type + ref_id 为多态弱关联（MySQL 无法单字段同时 FK 多表，由应用层保证一致性）
CREATE TABLE IF NOT EXISTS ledger_entries (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '流水主键',
  user_id BIGINT NOT NULL COMMENT '账务归属用户',
  currency VARCHAR(10) NOT NULL COMMENT '记账币种，引用 currencies.code',
  amount DECIMAL(20, 8) NOT NULL COMMENT '变动量：正为入账，负为出账',
  balance_after DECIMAL(20, 8) NOT NULL COMMENT '本笔完成后可用余额快照',
  frozen_balance_after DECIMAL(20, 8) NOT NULL COMMENT '本笔完成后冻结余额快照',
  ref_type VARCHAR(20) NOT NULL COMMENT '业务大类：ORDER, TRADE, DEPOSIT, WITHDRAWAL, KYC, ADJUST 等',
  ref_id BIGINT NOT NULL COMMENT '对应业务表主键 ID，与 ref_type 联合解析',
  `type` VARCHAR(30) NOT NULL COMMENT '动作细类：ORDER_FREEZE, TRADE_BUY, FEE, RECHARGE 等',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记账时间',
  PRIMARY KEY (id),
  KEY idx_ledger_user_time (user_id, created_at),
  KEY idx_ledger_user_ref (user_id, ref_type, ref_id),
  KEY idx_ledger_currency_time (currency, created_at),
  CONSTRAINT fk_ledger_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ledger_currency FOREIGN KEY (currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='资金流水与审计（双快照）';

-- -----------------------------------------------------------------------------
-- 4. 交易与撮合（表名 orders 为 SQL 保留冲突风险，使用反引号）
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `orders` (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '订单主键',
  user_id BIGINT NOT NULL COMMENT '下单用户',
  pair_id INT NOT NULL COMMENT '交易对 ID，引用 trading_pairs.id',
  side TINYINT NOT NULL COMMENT '1买入 2卖出',
  `type` TINYINT NOT NULL COMMENT '1限价 2市价',
  price DECIMAL(20, 8) NOT NULL COMMENT '委托价；市价单可为 0',
  total_amount DECIMAL(20, 8) NOT NULL COMMENT '委托总数量（基础资产）',
  filled_amount DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '已成交数量',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待成交 1部分成交 2完全成交 3已撤销（与 filled_amount 配合使用）',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '下单时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '订单最后变更时间',
  PRIMARY KEY (id),
  KEY idx_orders_user (user_id),
  KEY idx_orders_pair (pair_id),
  KEY idx_orders_status (status),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_orders_pair FOREIGN KEY (pair_id) REFERENCES trading_pairs (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_orders_side CHECK (side IN (1, 2)),
  CONSTRAINT chk_orders_type CHECK (`type` IN (1, 2)),
  CONSTRAINT chk_orders_status CHECK (status IN (0, 1, 2, 3)),
  CONSTRAINT chk_orders_filled CHECK (filled_amount <= total_amount),
  CONSTRAINT chk_orders_price CHECK (price >= 0),
  CONSTRAINT chk_orders_amounts_pos CHECK (total_amount > 0 AND filled_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='订单';

-- 成交：maker 为挂单方、taker 为吃单方；手续费币种独立，便于混合计费
CREATE TABLE IF NOT EXISTS trades (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '成交主键',
  pair_id INT NOT NULL COMMENT '交易对，冗余加速查询，须与双方订单 pair_id 一致（由应用保证）',
  maker_order_id BIGINT NOT NULL COMMENT 'Maker 订单，引用 orders.id',
  taker_order_id BIGINT NOT NULL COMMENT 'Taker 订单，引用 orders.id',
  price DECIMAL(20, 8) NOT NULL COMMENT '成交价格（计价货币）',
  amount DECIMAL(20, 8) NOT NULL COMMENT '成交数量（基础货币）',
  fee_amount DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '手续费数量',
  fee_currency VARCHAR(10) NOT NULL COMMENT '手续费币种，引用 currencies.code',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '成交时间',
  PRIMARY KEY (id),
  KEY idx_trades_pair_time (pair_id, created_at),
  KEY idx_trades_maker (maker_order_id),
  KEY idx_trades_taker (taker_order_id),
  CONSTRAINT fk_trades_pair FOREIGN KEY (pair_id) REFERENCES trading_pairs (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_trades_maker_order FOREIGN KEY (maker_order_id) REFERENCES `orders` (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_trades_taker_order FOREIGN KEY (taker_order_id) REFERENCES `orders` (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_trades_fee_currency FOREIGN KEY (fee_currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_trades_distinct_orders CHECK (maker_order_id <> taker_order_id),
  CONSTRAINT chk_trades_price_amount CHECK (price > 0 AND amount > 0),
  CONSTRAINT chk_trades_fee_nonneg CHECK (fee_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='成交记录（含 Maker/Taker 与手续费币种）';

-- -----------------------------------------------------------------------------
-- 5. 充值与提现
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS deposits (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '充值单主键',
  user_id BIGINT NOT NULL COMMENT '用户',
  currency VARCHAR(10) NOT NULL COMMENT '充值币种',
  amount DECIMAL(20, 8) NOT NULL COMMENT '到账数量',
  tx_hash VARCHAR(128) NULL COMMENT '链上交易哈希，待确认时可为空',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0待确认 1成功 2失败',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '状态最后更新时间',
  PRIMARY KEY (id),
  KEY idx_deposits_user (user_id),
  KEY idx_deposits_status (status),
  CONSTRAINT fk_deposits_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_deposits_currency FOREIGN KEY (currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT chk_deposits_status CHECK (status IN (0, 1, 2)),
  CONSTRAINT chk_deposits_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='充值记录';

CREATE TABLE IF NOT EXISTS withdrawals (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '提现单主键',
  user_id BIGINT NOT NULL COMMENT '用户',
  currency VARCHAR(10) NOT NULL COMMENT '提现币种',
  address VARCHAR(512) NOT NULL COMMENT '提币目标地址（链上地址可能较长，512 更稳妥）',
  amount DECIMAL(20, 8) NOT NULL COMMENT '用户申请到账数量（或净额，由业务定义并在文档说明）',
  fee DECIMAL(20, 8) NOT NULL DEFAULT 0.00000000 COMMENT '平台收取的提现手续费',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '0审核中 1处理中 2成功 3驳回',
  tx_hash VARCHAR(128) NULL COMMENT '链上打币哈希，成功后可填',
  reviewer_id BIGINT NULL COMMENT '审核人 users.id',
  reject_reason VARCHAR(255) NULL COMMENT '驳回原因',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '状态最后更新时间',
  PRIMARY KEY (id),
  KEY idx_withdrawals_user (user_id),
  KEY idx_withdrawals_status (status),
  CONSTRAINT fk_withdrawals_user FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_withdrawals_currency FOREIGN KEY (currency) REFERENCES currencies (code)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_withdrawals_reviewer FOREIGN KEY (reviewer_id) REFERENCES users (id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT chk_withdrawals_status CHECK (status IN (0, 1, 2, 3)),
  CONSTRAINT chk_withdrawals_amount_fee CHECK (amount > 0 AND fee >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='提现记录';

-- =============================================================================
-- 设计说明（可节选写入大作业）
-- -----------------------------------------------------------------------------
-- 1) currencies 为唯一合法币种来源；assets / ledger / deposits / withdrawals /
--    trading_pairs / trades.fee_currency 均外键引用，避免游离代码。
-- 2) ledger_entries 的 ref_type+ref_id 为多态关联：无法在单列上声明多表 FK，
--    需在应用层或触发器保证 ref_id 与 ref_type 指向真实存在的业务行。
-- 3) orders.status 已恢复「部分成交」语义（0~3），与您初版撮合模型一致；
--    若坚持三态，可改为 CHECK 仅允许 0,1,2 并仅用 filled_amount 表示部分成交。
-- 4) deposits.status 增加 2失败，便于链上失败/风控拒绝与流水冲正对应。
-- =============================================================================
