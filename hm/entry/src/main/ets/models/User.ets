// 用户数据模型
export interface User {
  id?: number;
  email: string;
  password_hash?: string;
  kyc_status: number; // 0-未验证, 1-审核中, 2-已验证, 3-拒绝
  created_at?: string;
  updated_at?: string;
}

export interface UserCreate {
  email: string;
  password_hash: string;
  kyc_status?: number;
}

export interface UserUpdate {
  kyc_status?: number;
}
