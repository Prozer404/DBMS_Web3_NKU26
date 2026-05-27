// 币种数据模型
export interface Currency {
  code: string;
  name: string;
  precision: number;
  withdrawal_fee: string;
  min_withdrawal: string;
  is_active: number; // 0-禁用, 1-启用
}

export interface CurrencyCreate {
  code: string;
  name: string;
  precision?: number;
  withdrawal_fee?: string;
  min_withdrawal?: string;
  is_active?: number;
}

export interface CurrencyUpdate {
  name?: string;
  precision?: number;
  withdrawal_fee?: string;
  min_withdrawal?: string;
  is_active?: number;
}
