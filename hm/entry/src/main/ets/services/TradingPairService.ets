import { HttpClient, HttpResponse } from './HttpClient';
import { TradingPair, TradingPairCreate, TradingPairUpdate } from '../models/TradingPair';
import { CreateTradingPairResponse, DeleteTradingPairResponse } from '../models/ApiResponse';

// 交易对API服务
export class TradingPairService {
  private static instance: TradingPairService;
  private httpClient: HttpClient = HttpClient.getInstance();
  
  private constructor() {}
  
  static getInstance(): TradingPairService {
    if (!TradingPairService.instance) {
      TradingPairService.instance = new TradingPairService();
    }
    return TradingPairService.instance;
  }
  
  // 获取交易对列表
  async getTradingPairs(): Promise<TradingPair[]> {
    const response: HttpResponse<TradingPair[]> = await this.httpClient.get<TradingPair[]>(
      '/api/admin/pairs',
      true
    );
    return response.data;
  }
  
  // 获取公开交易对列表
  async getPublicPairs(): Promise<TradingPair[]> {
    const response: HttpResponse<TradingPair[]> = await this.httpClient.get<TradingPair[]>(
      '/api/public/pairs'
    );
    return response.data;
  }
  
  // 创建交易对
  async createTradingPair(pair: TradingPairCreate): Promise<CreateTradingPairResponse> {
    const response: HttpResponse<CreateTradingPairResponse> = 
      await this.httpClient.post<CreateTradingPairResponse>(
        '/api/admin/pairs',
        pair,
        true
      );
    return response.data;
  }
  
  // 更新交易对
  async updateTradingPair(pairId: number, update: TradingPairUpdate): Promise<CreateTradingPairResponse> {
    const response: HttpResponse<CreateTradingPairResponse> = 
      await this.httpClient.put<CreateTradingPairResponse>(
        `/api/admin/pairs/${pairId}`,
        update,
        true
      );
    return response.data;
  }
  
  // 删除交易对
  async deleteTradingPair(pairId: number): Promise<DeleteTradingPairResponse> {
    const response: HttpResponse<DeleteTradingPairResponse> = 
      await this.httpClient.delete<DeleteTradingPairResponse>(
        `/api/admin/pairs/${pairId}`,
        true
      );
    return response.data;
  }
}
