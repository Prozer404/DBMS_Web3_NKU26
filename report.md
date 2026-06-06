# 数据库工程作业报告

**项目名称：Web3 虚拟货币交易所数据库信息管理系统**

**项目依据文件：**`admin_server.py`、`client_routes.py`、`config.py`、`database.py`、`db_manager.py`、`requirements.txt`、`schema_tables.sql`、`seed_web3.sql`。

**实际实现说明：**本报告优先依据工程中已经实现的数据库脚本、FastAPI 接口和命令行数据库管理工具填写。报告中涉及“截图”的位置，需要运行项目后自行粘贴页面或接口演示截图。

---

## 1. 项目信息（10 分）

| 学号 |  | 姓名 |  | 专业 |  |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **项目名称** | Web3 虚拟货币交易所数据库信息管理系统 |  |  |  |  |
| **必备环境** | Python 3.x、MySQL 8.0、FastAPI、Uvicorn、PyMySQL、浏览器、MySQL Workbench / Navicat / DataGrip |  |  |  |  |
| **系统主要功能简介（4 分）** | 本系统采用 B/S 架构，后端使用 Python FastAPI，数据库使用 MySQL。系统包含用户注册登录、JWT 身份认证、币种管理、交易对管理、KYC 申请与审核、用户资产查询、资金流水查询、订单创建与撤销、成交记录查询、充值申请、充值审核入账、提现申请与审核、管理端增删改查和数据库命令行管理等功能。数据库通过主键、唯一约束、外键约束、检查约束和事务提交/回滚保证数据一致性。 |  |  |  |  |
| **系统主要页面截图（6 分）** | 需要运行 `uvicorn admin_server:app --reload --host 127.0.0.1 --port 8080` 后截图：<br>1. 用户端首页或登录注册页面：`http://127.0.0.1:8080/user/`<br>2. 用户资产/流水/订单页面截图<br>3. 用户充值、提现或 KYC 页面截图<br>4. 管理端页面：`http://127.0.0.1:8080/admin/` |  |  |  |  |

---

## 2. 系统配置（10 分）

| 说明 | （2 分）说明系统配置情况；（8 分）说明高级语言连接数据库的连接串及各部分含义。 |
| :--- | :--- |
| **配置步骤（2 分）** | 1. 安装 MySQL 8.0，创建并使用 `Web3` 数据库。<br>2. 执行数据库建表脚本 `schema_tables.sql`，创建用户、交易对、资产、订单、成交、充值、提现等核心表。<br>3. 执行 `seed_web3.sql` 灌入演示数据。<br>4. 安装 Python 依赖：`pip install -r requirements.txt`。<br>5. 启动服务：`uvicorn admin_server:app --reload --host 127.0.0.1 --port 8080`。 |
| **后台数据库** | MySQL 8.0，字符集使用 `utf8mb4`，主要存储引擎使用 InnoDB。 |
| **高级语言与框架** | Python；Web 框架为 FastAPI；数据库访问库为 PyMySQL；密码加密使用 bcrypt；登录认证使用 JWT。 |
| **连接配置来源** | `config.py` 从项目根目录 `.env` 或环境变量读取数据库配置。优先支持 `MYSQL_HOST`、`MYSQL_PORT`、`MYSQL_USER`、`MYSQL_PASSWORD`、`MYSQL_DATABASE`，也支持 `DATABASE_URL`。 |
| **连接参数示例** | `MYSQL_HOST=127.0.0.1`<br>`MYSQL_PORT=3306`<br>`MYSQL_USER=root`<br>`MYSQL_PASSWORD=你的密码`<br>`MYSQL_DATABASE=Web3` |
| **连接串示例** | `mysql+pymysql://root:你的密码@127.0.0.1:3306/Web3?charset=utf8mb4` |
| **连接串分析（6 分）** | 1. `mysql+pymysql`：表示使用 MySQL 数据库和 PyMySQL 驱动。<br>2. `root`：数据库用户名。<br>3. `你的密码`：数据库用户密码。<br>4. `127.0.0.1`：数据库服务器地址。<br>5. `3306`：MySQL 默认端口。<br>6. `Web3`：连接的业务数据库名称。<br>7. `charset=utf8mb4`：指定字符集，保证中文、符号和多语言数据正常保存。 |
| **实际连接代码（2 分）** | 工程实际连接在 `database.py` 中实现。`get_db()` 调用 `config.get_mysql_params()` 获取配置，然后使用 `pymysql.connect(...)` 连接 MySQL，并设置 `charset='utf8mb4'`、`cursorclass=DictCursor`、`autocommit=False`。该上下文管理器在正常执行后 `commit()`，异常时 `rollback()`。请在此处粘贴 `database.py` 中连接代码截图。 |

---

## 3. 数据库设计（14 分）

| 说明 | 按照数据表创建顺序给出表信息；关系图需要使用数据库工具生成后截图。 |
| :--- | :--- |
| **数据表（10 分）** | 创建顺序 | 数据表名称 | 主键 | 参照属性 | 被参照表及属性 |
|  | 1 | `users` | `id` | 无 | 无 |
|  | 2 | `trading_pairs` | `id` | 无 | 无 |
|  | 3 | `assets` | `id` | `user_id` | `users(id)` |
|  | 4 | `ledger_entries` | `id` | `user_id` | `users(id)` |
|  | 5 | `orders` | `id` | `user_id`、`pair_id` | `users(id)`、`trading_pairs(id)` |
|  | 6 | `trades` | `id` | `buy_order_id`、`sell_order_id`、`pair_id` | `orders(id)`、`orders(id)`、`trading_pairs(id)` |
|  | 7 | `deposits` | `id` | `user_id` | `users(id)` |
|  | 8 | `withdrawals` | `id` | `user_id` | `users(id)` |
| **关系图（4 分）** | 请在 MySQL Workbench / Navicat / DataGrip 中对 `Web3` 数据库执行反向工程，生成 ER 图并粘贴截图。 |
| **补充说明** | `seed_web3.sql` 中包含更完整的演示数据，含 `currencies`、`kyc_applications` 等数据插入语句；如果实际执行的建表脚本为修订版，则数据库会比 `schema_tables.sql` 更完整。当前用户指定的 `schema_tables.sql` 核心表结构为上述 8 张表。 |

---

## 4. 含有事务应用的删除操作（13 分）

| 说明 | 本部分依据工程中真实存在的删除接口和数据库连接事务机制填写。 |
| :--- | :--- |
| **功能描述（1 分）** | 管理端删除交易对。若该交易对已经被订单或成交引用，系统不允许删除，并返回错误提示，避免破坏历史交易数据。 |
| **涉及的表（2 分）** | `trading_pairs`、`orders`、`trades` |
| **表连接涉及字段（1 分）** | `trading_pairs.id = orders.pair_id`；`trading_pairs.id = trades.pair_id` |
| **删除条件字段描述（1 分）** | `trading_pairs.id = ?`，其中 `?` 为管理端选择的交易对 ID。 |
| **关键代码（4 分）** | 删除接口位于 `admin_server.py` 的 `delete_pair(pair_id)`。核心 SQL 为：`DELETE FROM trading_pairs WHERE id = %s`。如果存在订单或成交引用，MySQL 外键约束会触发 `pymysql.err.IntegrityError`，接口返回 409 错误。事务由 `database.py` 的 `get_db()` 统一管理：正常执行后 `conn.commit()`，出现异常时 `conn.rollback()`。请在此处粘贴 `admin_server.py` 删除交易对代码和 `database.py` 事务上下文代码截图。 |
| **程序演示（4 分）** | 1. 启动服务并进入管理端。<br>2. 选择一个没有被订单引用的交易对，执行删除，系统返回成功。<br>3. 选择一个已被订单或成交引用的交易对，执行删除。<br>4. 系统返回“存在订单/成交引用”之类的错误，数据库回滚，不会删除该交易对。 |
| **实际实现评价** | 工程中有删除接口，也有 `commit/rollback` 事务封装；但删除语句本身没有显式写 `START TRANSACTION`，而是依赖 PyMySQL 连接的 `autocommit=False` 和上下文管理器完成事务。 |

---

## 5. 触发器控制下的添加操作（20 分）

| 说明 | 报告要求“触发器控制下的添加操作”。工程中实现了充值添加和审核入账流程，但没有发现数据库触发器。 |
| :--- | :--- |
| **功能描述（1 分）** | 用户提交充值申请，系统向 `deposits` 表添加一条待确认充值记录；管理员审核充值为成功后，系统更新或创建用户资产，并写入资金流水。 |
| **触发器描述（2 分）** | 当前工程没有实现 MySQL `CREATE TRIGGER` 触发器。等价业务逻辑在应用层 `admin_server.py` 的 `patch_deposit(dep_id)` 中完成：当充值状态首次变为成功时，锁定充值单和资产行，更新 `assets.balance`，并插入 `ledger_entries`。 |
| **涉及的表（1 分）** | `deposits`、`assets`、`ledger_entries`、`users`。若使用修订版数据库，还涉及 `currencies`。 |
| **输入数据（2 分）** | 充值申请接口输入：`currency`、`amount`、`tx_hash`。<br>1. `currency`：币种代码，用户端会检查该币种是否存在。<br>2. `amount`：充值金额，应大于 0；数据库修订版中有 `CHECK(amount > 0)`。<br>3. `tx_hash`：链上交易哈希，可为空。<br>4. `user_id`：来自 JWT 登录用户，不由前端直接传入。 |
| **插入操作源码（3 分）** | 用户端新增充值位于 `client_routes.py` 的 `me_deposit_create()`。核心 SQL 为：`INSERT INTO deposits (user_id, currency, amount, tx_hash, status) VALUES (%s,%s,%s,%s,0)`。请粘贴该方法截图。 |
| **触发器源码（3 分）** | 工程中未发现 `CREATE TRIGGER` 语句，因此没有可截图的触发器源码。若必须满足该评分项，需要补充数据库触发器，例如 `AFTER UPDATE ON deposits` 或 `AFTER INSERT ON deposits`，在充值成功时自动更新 `assets` 并插入 `ledger_entries`。 |
| **程序演示：符合规则（4 分）** | 1. 用户登录后提交合法币种和金额的充值申请。<br>2. 管理员在管理端将充值状态改为成功。<br>3. 系统执行 `SELECT ... FOR UPDATE` 锁定充值单和资产行。<br>4. 用户资产余额增加，并新增一条 `ledger_entries` 流水。 |
| **程序演示：违反规则（4 分）** | 1. 输入未知币种提交充值，用户端接口会返回“未知币种”。<br>2. 管理员重复将同一充值单设为成功，代码通过 `old_status != 1` 避免重复入账。<br>3. 如果数据库约束不满足，例如用户不存在或币种不存在，插入会失败并回滚。 |
| **实际实现评价** | 添加充值记录和审核入账逻辑已经实现，但严格来说不属于“数据库触发器控制”，而是“应用层事务控制”。这是与报告要求不完全一致的地方。 |

---

## 6. 存储过程控制下的更新操作（18 分）

| 说明 | 报告要求“存储过程控制下的更新操作”。工程中实现了多个更新接口，但没有发现 MySQL 存储过程。 |
| :--- | :--- |
| **功能描述（1 分）** | 管理员审核 KYC 申请，更新 `kyc_applications.status`，并同步更新用户表 `users.kyc_status`。 |
| **存储过程功能描述（1 分）** | 当前工程没有实现 `CREATE PROCEDURE` 存储过程。等价业务逻辑由 `admin_server.py` 中的 `patch_kyc(kyc_id)` 完成：先更新 KYC 申请记录，再根据申请状态把用户 KYC 状态同步为审核中、已通过或已拒绝。 |
| **涉及的关系表（2 分）** | `kyc_applications`、`users` |
| **表连接涉及字段（1 分）** | `kyc_applications.user_id = users.id`；`kyc_applications.reviewer_id = users.id` |
| **更改字段（2 分）** | 1. `kyc_applications.status`：管理员设置为待审核、通过或拒绝。<br>2. `kyc_applications.reject_reason`：拒绝时填写拒绝原因。<br>3. `kyc_applications.reviewer_id`：记录审核人。<br>4. `users.kyc_status`：根据 KYC 申请状态同步更新，待审核映射为 1，通过映射为 2，拒绝映射为 3。 |
| **更新代码（3 分）** | 工程实际更新接口为 `PATCH /api/admin/kyc-applications/{kyc_id}`，位于 `admin_server.py`。核心 SQL 包括：`UPDATE kyc_applications SET status = %s, reject_reason = %s, reviewer_id = %s WHERE id = %s`，随后查询 `user_id` 并执行 `UPDATE users SET kyc_status = %s WHERE id = %s`。请粘贴该方法截图。 |
| **创建存储过程源码（3 分）** | 工程中未发现 `CREATE PROCEDURE` 语句，因此没有可截图的存储过程源码。若必须满足该评分项，需要补充如 `sp_review_kyc` 或 `sp_apply_trade` 的存储过程，将上述两次更新封装到数据库端。 |
| **存储过程执行源码（1 分）** | 工程中没有 `CALL 存储过程名(...)` 的代码。若补充存储过程，可使用类似 `CALL sp_review_kyc(?, ?, ?, ?);` 的方式执行。 |
| **程序演示：符合规则（2 分）** | 管理端选择一条 KYC 申请，设置为通过或拒绝并提交。系统更新 KYC 申请记录，同时用户表中的 `kyc_status` 发生对应变化。 |
| **程序演示：违反规则（2 分）** | 如果 KYC 记录不存在，接口返回 404“记录不存在”；如果 reviewer_id 不存在，数据库外键会拒绝更新并回滚。 |
| **实际实现评价** | 更新操作已经实现，并且由 `database.py` 提供事务提交/回滚；但严格来说不是“存储过程控制”，而是 FastAPI 应用层控制。 |

---

## 7. 含有视图的查询操作（15 分）

| 说明 | 报告要求“含有视图的查询操作”。工程中有复杂联表查询，但没有发现 MySQL 视图。 |
| :--- | :--- |
| **操作功能描述（1 分）** | 查询当前用户相关成交记录，展示成交 ID、交易对、Maker 订单、Taker 订单、成交价格、成交数量、手续费和成交时间。 |
| **视图功能描述（1 分）** | 当前工程没有创建数据库视图。等价查询由 `client_routes.py` 中的 `me_trades()` 直接使用 SQL 完成。该查询通过 `trades` 和 `orders` 的关联筛选出当前登录用户参与过的成交记录。 |
| **涉及的关系表（2 分）** | `trades`、`orders` |
| **表连接字段（1 分）** | `orders.id = trades.maker_order_id`；`orders.id = trades.taker_order_id`；`orders.user_id = 当前登录用户 ID`。如果使用旧版 `schema_tables.sql`，成交表字段为 `buy_order_id`、`sell_order_id`，需要相应调整查询。 |
| **创建视图代码（3 分）** | 工程中未发现 `CREATE VIEW` 语句，因此没有可截图的视图创建源码。若必须满足评分项，可补充视图，例如 `CREATE VIEW v_user_trades AS SELECT ... FROM trades t JOIN orders mo ... JOIN orders to ...`。 |
| **查询代码（3 分）** | 工程实际查询位于 `client_routes.py` 的 `me_trades()`。核心 SQL 使用 `SELECT DISTINCT ... FROM trades t WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = %s AND (o.id = t.maker_order_id OR o.id = t.taker_order_id)) ORDER BY t.id DESC LIMIT %s`。请粘贴该方法截图。 |
| **程序演示（4 分）** | 1. 用户登录后获取 JWT。<br>2. 调用 `GET /api/me/trades`。<br>3. 系统根据 JWT 中的用户 ID 查询该用户参与过的成交记录。<br>4. 页面或接口返回成交列表，截图保存。 |
| **实际实现评价** | 联表查询功能已经实现，但数据库视图没有实现。若教师严格要求“必须含有视图”，需要新增 `CREATE VIEW` 脚本，并把查询改为查询视图。 |

---

## 8. 工程中已实现但报告模板未单独要求的功能

1. **用户注册登录**：`client_routes.py` 实现邮箱注册、bcrypt 密码哈希、JWT 登录令牌。
2. **JWT 权限控制**：用户端接口通过 `HTTPBearer` 和 `get_user_id()` 获取当前用户。
3. **管理端密钥保护**：`admin_server.py` 支持通过 `ADMIN_API_KEY` 和 `X-Admin-Key` 保护管理端 API。
4. **数据库健康检查**：`GET /api/health` 通过 `SELECT 1 AS ok` 检查数据库连接。
5. **命令行数据库管理器**：`db_manager.py` 支持连接数据库、只读查询、执行 SQL、查看表和字段结构。
6. **高危 SQL 风险扫描**：`db_manager.py` 对删除用户、修改资产余额、删除流水、删除成交等高危 SQL 进行提示，并要求输入大写 `YES` 才执行。
7. **统一事务管理**：`database.py` 的 `get_db()` 在所有接口中统一处理提交和回滚。

---

## 9. 仍然缺失或与报告要求不完全一致的内容

根据当前指定文件检查，以下内容仍然缺失或需要补充：

1. **数据库触发器缺失**
   - 没有发现 `CREATE TRIGGER`。
   - 报告第 5 部分要求“触发器控制下的添加操作”，目前由应用层代码 `patch_deposit()` 实现充值入账，不是数据库触发器。

2. **数据库存储过程缺失**
   - 没有发现 `CREATE PROCEDURE`。
   - 报告第 6 部分要求“存储过程控制下的更新操作”，目前由 FastAPI 接口直接执行 SQL。

3. **数据库视图缺失**
   - 没有发现 `CREATE VIEW`。
   - 报告第 7 部分要求“含有视图的查询操作”，目前由接口中的联表查询直接实现。

4. **显式事务 SQL 缺失**
   - 工程有事务机制：`autocommit=False`、正常 `commit()`、异常 `rollback()`。
   - 但 SQL 文件或接口代码中没有显式 `START TRANSACTION` / `COMMIT` / `ROLLBACK` 语句。

5. **`schema_tables.sql` 与部分 Python 代码字段不完全一致**
   - `client_routes.py` 和 `admin_server.py` 使用了 `currencies`、`kyc_applications`、`trades.maker_order_id`、`trades.taker_order_id`、`fee_amount`、`fee_currency`、`deposits.tx_hash`、`withdrawals.reviewer_id` 等字段。
   - 如果只执行当前 `schema_tables.sql`，这些表或字段可能不存在，程序会报错。
   - `seed_web3.sql` 也使用了修订版字段结构。建议使用完整修订版建表脚本，或者把 `schema_tables.sql` 更新为与 Python 代码一致。

6. **页面截图需要人工补充**
   - 报告中的页面截图、连接代码截图、接口演示截图需要运行系统后粘贴。

7. **订单撮合/成交生成逻辑不完整**
   - 工程可以创建订单、撤销订单、查询成交，但没有发现自动撮合或创建成交的接口。
   - 演示成交数据主要来自 `seed_web3.sql`。

---

## 10. 建议补充内容

如果要让报告完全符合评分项，建议补充以下 SQL 或代码：

1. 新增触发器：充值单成功时自动更新 `assets` 并插入 `ledger_entries`。
2. 新增存储过程：例如 `sp_review_kyc` 或 `sp_apply_trade`，用于封装 KYC 审核或成交后订单状态更新。
3. 新增视图：例如 `v_user_trade_overview` 或 `v_user_trades`，封装用户订单与成交查询。
4. 统一数据库脚本：让 `schema_tables.sql` 与 Python 代码、`seed_web3.sql` 的表结构保持一致。
5. 运行项目并补充截图：用户端、管理端、数据库 ER 图、代码截图和接口执行结果截图。
