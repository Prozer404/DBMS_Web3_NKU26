// 订单数据模型
export interface Order {
  id?: number;
  user_id: number;
  pair_id: number;
  side: string; // 'buy' or 'sell'
  type: string; // 'limit' or 'market'
  price: string;
  total_amount: string;
  filled_amount: string;
  status: string; // 'pending', 'partial', 'filled', 'cancelled'
  created_at?: string;
  updated_at?: string;
}

export interface OrderCreate {
  pair_id: number;
  side: string;
  type: string;
  price: string;
  total_amount: string;
}

// 成交记录数据模型
export interface Trade {
  id?: number;
  pair_id: number;
  maker_order_id: number;
  taker_order_id: number;
  price: string;
  amount: string;
  created_at?: string;
}
