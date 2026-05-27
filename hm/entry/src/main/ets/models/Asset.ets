// 资产数据模型
export interface Asset {
  id?: number;
  user_id: number;
  currency: string;
  balance: string;
  frozen_balance: string;
}

// 流水记录数据模型
export interface LedgerEntry {
  id?: number;
  user_id: number;
  currency: string;
  amount: string;
  balance_after: string;
  frozen_balance_after: string;
  ref_type: string;
  ref_id: number;
  type: string;
  created_at?: string;
}
