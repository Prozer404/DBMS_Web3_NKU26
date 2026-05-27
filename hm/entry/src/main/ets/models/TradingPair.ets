// 交易对数据模型
export interface TradingPair {
  id?: number;
  base_currency: string;
  quote_currency: string;
  min_order_amount: string;
  price_precision: number;
  amount_precision: number;
  is_active?: number;
}

export interface TradingPairCreate {
  base_currency: string;
  quote_currency: string;
  min_order_amount?: string;
  price_precision?: number;
  amount_precision?: number;
}

export interface TradingPairUpdate {
  min_order_amount?: string;
  price_precision?: number;
  amount_precision?: number;
  is_active?: number;
}
