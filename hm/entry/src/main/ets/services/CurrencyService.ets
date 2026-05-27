import { HttpClient, HttpResponse } from './HttpClient';
import { Currency, CurrencyCreate, CurrencyUpdate } from '../models/Currency';
import { CreateCurrencyResponse, DeleteCurrencyResponse } from '../models/ApiResponse';

// 币种API服务
export class CurrencyService {
  private static instance: CurrencyService;
  private httpClient: HttpClient = HttpClient.getInstance();
  
  private constructor() {}
  
  static getInstance(): CurrencyService {
    if (!CurrencyService.instance) {
      CurrencyService.instance = new CurrencyService();
    }
    return CurrencyService.instance;
  }
  
  // 获取币种列表
  async getCurrencies(): Promise<Currency[]> {
    const response: HttpResponse<Currency[]> = await this.httpClient.get<Currency[]>(
      '/api/admin/currencies',
      true
    );
    return response.data;
  }
  
  // 获取公开币种列表
  async getPublicCurrencies(): Promise<Currency[]> {
    const response: HttpResponse<Currency[]> = await this.httpClient.get<Currency[]>(
      '/api/public/currencies'
    );
    return response.data;
  }
  
  // 创建币种
  async createCurrency(currency: CurrencyCreate): Promise<CreateCurrencyResponse> {
    const response: HttpResponse<CreateCurrencyResponse> = 
      await this.httpClient.post<CreateCurrencyResponse>(
        '/api/admin/currencies',
        currency,
        true
      );
    return response.data;
  }
  
  // 更新币种
  async updateCurrency(code: string, update: CurrencyUpdate): Promise<CreateCurrencyResponse> {
    const response: HttpResponse<CreateCurrencyResponse> = 
      await this.httpClient.put<CreateCurrencyResponse>(
        `/api/admin/currencies/${code}`,
        update,
        true
      );
    return response.data;
  }
  
  // 删除币种
  async deleteCurrency(code: string): Promise<DeleteCurrencyResponse> {
    const response: HttpResponse<DeleteCurrencyResponse> = 
      await this.httpClient.delete<DeleteCurrencyResponse>(
        `/api/admin/currencies/${code}`,
        true
      );
    return response.data;
  }
}
