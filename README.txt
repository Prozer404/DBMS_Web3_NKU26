```markdown
# README

## 使用方法

### 1. 启动 MySQL
先确认本机MySQL已经启动，并且能用账号密码连接。

**默认项目配置：**
-   数据库地址：127.0.0.1
-   端口：3306
-   数据库名：Web3
-   用户名：root
-   密码：从 .env或环境变量读取

### 2. 准备数据库
执行以下 SQL 文件：

```bash
./schema_tables.sql
```

然后执行：

```bash
./seed_web3.sql
```

### 3. 安装 Python 依赖
在项目根目录打开PowerShell，建议先创建虚拟环境：

```bash
python -m venv .venv
```

激活虚拟环境：

```bash
.\.venv\Scripts\Activate.ps1
```

> **注意**：如果 PowerShell 不允许执行脚本，可以先执行以下命令，然后再激活：
>
> ```bash
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

安装依赖：

```bash
pip install -r requirements.txt
```

### 4. 配置数据库连接
本项目已经配置好，无需更改配置。

### 5. 启动后端服务
在项目根目录执行：

```bash
uvicorn admin_server:app --reload --host 127.0.0.1 --port 8080
```

启动成功后，终端里应该能看到：

```text
Uvicorn running on http://127.0.0.1:8080
```

### 6. 打开演示页面
浏览器打开以下地址：

-   **用户页面：** [http://127.0.0.1:8080/user/](http://127.0.0.1:8080/user/)
-   **管理页面：** [http://127.0.0.1:8080/admin/](http://127.0.0.1:8080/admin/)
```
