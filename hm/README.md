# Web3 数据库管理移动应用

一个基于 HarmonyOS 的数据库管理移动应用，用于管理 Web3 交易平台的数据库。

## 功能特性

### 1. 用户管理
- 查看用户列表
- 添加新用户
- 编辑用户KYC状态
- 删除用户

### 2. 币种管理
- 查看币种列表
- 添加新币种
- 编辑币种信息（精度、提现费、最小提现等）
- 删除币种

### 3. 交易对管理
- 查看交易对列表
- 添加新交易对
- 编辑交易对参数
- 删除交易对

### 4. 资产查看
- 根据用户ID查询资产
- 查看可用余额和冻结余额
- 查看流水记录

### 5. 订单管理
- 根据用户ID查询订单
- 查看订单详情
- 取消未完成订单

## 项目结构

```
entry/src/main/ets/
├── models/              # 数据模型
│   ├── User.ets        # 用户模型
│   ├── Currency.ets    # 币种模型
│   ├── TradingPair.ets # 交易对模型
│   ├── Asset.ets       # 资产模型
│   └── Order.ets       # 订单模型
├── services/           # API服务
│   ├── ApiConfig.ets   # API配置
│   ├── HttpClient.ets  # HTTP客户端封装
│   ├── UserService.ets # 用户服务
│   ├── CurrencyService.ets # 币种服务
│   ├── TradingPairService.ets # 交易对服务
│   └── AssetOrderService.ets # 资产和订单服务
├── components/         # 通用组件
│   └── CommonComponents.ets
├── utils/              # 工具函数
│   └── CommonUtils.ets
└── pages/              # 页面
    ├── Index.ets       # 主页面
    ├── UserPage.ets    # 用户管理页面
    ├── CurrencyPage.ets # 币种管理页面
    ├── TradingPairPage.ets # 交易对管理页面
    ├── AssetPage.ets   # 资产查看页面
    └── OrderPage.ets   # 订单管理页面
```

## 配置说明

### 1. API配置
在 `services/ApiConfig.ets` 中配置后端API地址：

```typescript
export class ApiConfig {
  static readonly BASE_URL: string = 'http://127.0.0.1:8080'; // 修改为实际服务器地址
  static readonly ADMIN_KEY: string = ''; // 管理员API密钥
  static token: string = ''; // JWT Token
}
```

### 2. 网络权限
已在 `module.json5` 中配置网络权限：

```json
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET",
    "reason": "需要网络权限以访问后端API"
  }
]
```

## 使用说明

### 1. 启动后端服务
确保 Python 后端服务正在运行：
```bash
cd C:\Users\24957\Desktop\Database_work
uvicorn admin_server:app --reload --host 127.0.0.1 --port 8080
```

### 2. 运行应用
在 DevEco Studio 中运行 HarmonyOS 应用。

### 3. 使用功能
- 主页面显示5个功能模块的图标
- 点击图标进入对应的管理页面
- 在管理页面中进行增删改查操作

## 技术栈

- **前端框架**: HarmonyOS ArkUI
- **开发语言**: ArkTS (TypeScript扩展)
- **网络请求**: @ohos.net.http
- **路由导航**: @ohos.router
- **UI交互**: @ohos.promptAction

## 注意事项

1. **网络配置**: 确保设备可以访问后端API地址
2. **认证**: 部分API需要管理员密钥或JWT Token
3. **数据验证**: 应用已包含基本的数据验证
4. **错误处理**: 所有API调用都有错误处理机制

## 后端API对应

应用使用的后端API端点：

- 用户管理: `/api/admin/users`
- 币种管理: `/api/admin/currencies`
- 交易对管理: `/api/admin/pairs`
- 资产查看: `/api/admin/assets/{userId}`
- 订单管理: `/api/admin/orders/{userId}`

## 开发建议

1. 根据实际需求调整API端点
2. 添加更多数据验证和错误处理
3. 实现本地数据缓存
4. 添加用户登录功能
5. 优化UI交互体验
