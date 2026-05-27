import { HttpClient, HttpResponse } from './HttpClient';
import { User, UserCreate, UserUpdate } from '../models/User';
import { CreateUserResponse, UpdateUserResponse, DeleteUserResponse } from '../models/ApiResponse';

// 用户API服务
export class UserService {
  private static instance: UserService;
  private httpClient: HttpClient = HttpClient.getInstance();
  
  private constructor() {}
  
  static getInstance(): UserService {
    if (!UserService.instance) {
      UserService.instance = new UserService();
    }
    return UserService.instance;
  }
  
  // 获取用户列表
  async getUsers(limit: number = 200): Promise<User[]> {
    const response: HttpResponse<User[]> = await this.httpClient.get<User[]>(
      `/api/admin/users?limit=${limit}`,
      true
    );
    return response.data;
  }
  
  // 创建用户
  async createUser(user: UserCreate): Promise<CreateUserResponse> {
    const response: HttpResponse<CreateUserResponse> = 
      await this.httpClient.post<CreateUserResponse>(
        '/api/admin/users',
        user,
        true
      );
    return response.data;
  }
  
  // 更新用户KYC状态
  async updateUser(userId: number, update: UserUpdate): Promise<UpdateUserResponse> {
    const response: HttpResponse<UpdateUserResponse> = 
      await this.httpClient.put<UpdateUserResponse>(
        `/api/admin/users/${userId}`,
        update,
        true
      );
    return response.data;
  }
  
  // 删除用户
  async deleteUser(userId: number): Promise<DeleteUserResponse> {
    const response: HttpResponse<DeleteUserResponse> = 
      await this.httpClient.delete<DeleteUserResponse>(
        `/api/admin/users/${userId}`,
        true
      );
    return response.data;
  }
}
