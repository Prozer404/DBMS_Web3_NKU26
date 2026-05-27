// API配置
export class ApiConfig {
  // 后端API基础URL，需要根据实际服务器地址修改
  static readonly BASE_URL: string = 'http://127.0.0.1:8080';
  
  // 管理员API密钥（如果需要）
  static readonly ADMIN_KEY: string = '';
  
  // JWT Token（用户登录后设置）
  static token: string = '';
  
  // 请求超时时间（毫秒）
  static readonly TIMEOUT: number = 30000;
}
