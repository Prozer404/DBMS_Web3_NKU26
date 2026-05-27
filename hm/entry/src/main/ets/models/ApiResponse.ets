// API响应类型定义

// 通用响应
export interface ApiResponse {
  ok: boolean;
}

// 创建用户响应
export interface CreateUserResponse {
  ok: boolean;
  id: number;
}

// 更新用户响应
export interface UpdateUserResponse {
  ok: boolean;
  id: number;
  kyc_status: number;
}

// 删除用户响应
export interface DeleteUserResponse {
  ok: boolean;
  deleted: number;
}

// 创建币种响应
export interface CreateCurrencyResponse {
  ok: boolean;
  code: string;
}

// 删除币种响应
export interface DeleteCurrencyResponse {
  ok: boolean;
  deleted: string;
}

// 创建交易对响应
export interface CreateTradingPairResponse {
  ok: boolean;
  id: number;
}

// 删除交易对响应
export interface DeleteTradingPairResponse {
  ok: boolean;
  deleted: number;
}

// 创建订单响应
export interface CreateOrderResponse {
  ok: boolean;
  order_id: number;
}

// 取消订单响应
export interface CancelOrderResponse {
  ok: boolean;
  order_id: number;
}
