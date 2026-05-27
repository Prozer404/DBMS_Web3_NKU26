import { HttpClient, HttpResponse } from './HttpClient';
import { Asset, LedgerEntry } from '../models/Asset';
import { Order, OrderCreate } from '../models/Order';
import { CreateOrderResponse, CancelOrderResponse } from '../models/ApiResponse';

// 资产和订单API服务
export class AssetOrderService {
  private static instance: AssetOrderService;
  private httpClient: HttpClient = HttpClient.getInstance();
  
  private constructor() {}
  
  static getInstance(): AssetOrderService {
    if (!AssetOrderService.instance) {
      AssetOrderService.instance = new AssetOrderService();
    }
    return AssetOrderService.instance;
  }
  
  // 获取用户资产
  async getUserAssets(userId: number): Promise<Asset[]> {
    const response: HttpResponse<Asset[]> = await this.httpClient.get<Asset[]>(
      `/api/admin/assets/${userId}`,
      true
    );
    return response.data;
  }
  
  // 获取当前用户资产
  async getMyAssets(): Promise<Asset[]> {
    const response: HttpResponse<Asset[]> = await this.httpClient.get<Asset[]>(
      '/api/me/assets'
    );
    return response.data;
  }
  
  // 获取用户流水
  async getUserLedger(userId: number, limit: number = 100): Promise<LedgerEntry[]> {
    const response: HttpResponse<LedgerEntry[]> = await this.httpClient.get<LedgerEntry[]>(
      `/api/admin/ledger/${userId}?limit=${limit}`,
      true
    );
    return response.data;
  }
  
  // 获取当前用户流水
  async getMyLedger(limit: number = 100): Promise<LedgerEntry[]> {
    const response: HttpResponse<LedgerEntry[]> = await this.httpClient.get<LedgerEntry[]>(
      `/api/me/ledger?limit=${limit}`
    );
    return response.data;
  }
  
  // 获取用户订单
  async getUserOrders(userId: number, limit: number = 50): Promise<Order[]> {
    const response: HttpResponse<Order[]> = await this.httpClient.get<Order[]>(
      `/api/admin/orders/${userId}?limit=${limit}`,
      true
    );
    return response.data;
  }
  
  // 获取当前用户订单
  async getMyOrders(limit: number = 50): Promise<Order[]> {
    const response: HttpResponse<Order[]> = await this.httpClient.get<Order[]>(
      `/api/me/orders?limit=${limit}`
    );
    return response.data;
  }
  
  // 创建订单
  async createOrder(order: OrderCreate): Promise<CreateOrderResponse> {
    const response: HttpResponse<CreateOrderResponse> = 
      await this.httpClient.post<CreateOrderResponse>(
        '/api/me/orders',
        order
      );
    return response.data;
  }
  
  // 取消订单
  async cancelOrder(orderId: number): Promise<CancelOrderResponse> {
    const response: HttpResponse<CancelOrderResponse> = 
      await this.httpClient.delete<CancelOrderResponse>(
        `/api/me/orders/${orderId}`
      );
    return response.data;
  }
}
