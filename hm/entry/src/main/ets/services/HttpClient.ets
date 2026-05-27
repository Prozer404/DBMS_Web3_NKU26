import http from '@ohos.net.http';
import { ApiConfig } from './ApiConfig';

// HTTP响应接口
export interface HttpResponse<T> {
  data: T;
  statusCode: number;
  headers: Map<string, string>;
}

// API错误类
export class ApiError extends Error {
  statusCode: number;
  
  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

// HTTP客户端封装
export class HttpClient {
  private static instance: HttpClient;
  
  private constructor() {}
  
  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }
  
  // 创建HTTP请求
  private createRequest(): http.HttpRequest {
    return http.createHttp();
  }
  
  // 获取通用请求头
  private getHeaders(isAdmin: boolean = false): Map<string, string> {
    const headers = new Map<string, string>();
    headers.set('Content-Type', 'application/json');
    
    if (ApiConfig.token) {
      headers.set('Authorization', `Bearer ${ApiConfig.token}`);
    }
    
    if (isAdmin && ApiConfig.ADMIN_KEY) {
      headers.set('X-Admin-Key', ApiConfig.ADMIN_KEY);
    }
    
    return headers;
  }
  
  // GET请求
  async get<T>(url: string, isAdmin: boolean = false): Promise<HttpResponse<T>> {
    const httpRequest = this.createRequest();
    const fullUrl = `${ApiConfig.BASE_URL}${url}`;
    
    try {
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(isAdmin),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });
      
      const data = this.parseResponse<T>(response);
      return {
        data,
        statusCode: response.responseCode,
        headers: response.header as Map<string, string>
      };
    } catch (error) {
      throw new ApiError(`GET请求失败: ${error}`, 500);
    } finally {
      httpRequest.destroy();
    }
  }
  
  // POST请求
  async post<T>(url: string, body: object, isAdmin: boolean = false): Promise<HttpResponse<T>> {
    const httpRequest = this.createRequest();
    const fullUrl = `${ApiConfig.BASE_URL}${url}`;
    
    try {
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(isAdmin),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });
      
      const data = this.parseResponse<T>(response);
      return {
        data,
        statusCode: response.responseCode,
        headers: response.header as Map<string, string>
      };
    } catch (error) {
      throw new ApiError(`POST请求失败: ${error}`, 500);
    } finally {
      httpRequest.destroy();
    }
  }
  
  // PUT请求（用于更新操作）
  async put<T>(url: string, body: object, isAdmin: boolean = false): Promise<HttpResponse<T>> {
    const httpRequest = this.createRequest();
    const fullUrl = `${ApiConfig.BASE_URL}${url}`;
    
    try {
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.PUT,
        header: this.getHeaders(isAdmin),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });
      
      const data = this.parseResponse<T>(response);
      return {
        data,
        statusCode: response.responseCode,
        headers: response.header as Map<string, string>
      };
    } catch (error) {
      throw new ApiError(`PUT请求失败: ${error}`, 500);
    } finally {
      httpRequest.destroy();
    }
  }
  
  // DELETE请求
  async delete<T>(url: string, isAdmin: boolean = false): Promise<HttpResponse<T>> {
    const httpRequest = this.createRequest();
    const fullUrl = `${ApiConfig.BASE_URL}${url}`;
    
    try {
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.DELETE,
        header: this.getHeaders(isAdmin),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });
      
      const data = this.parseResponse<T>(response);
      return {
        data,
        statusCode: response.responseCode,
        headers: response.header as Map<string, string>
      };
    } catch (error) {
      throw new ApiError(`DELETE请求失败: ${error}`, 500);
    } finally {
      httpRequest.destroy();
    }
  }
  
  // 解析响应
  private parseResponse<T>(response: http.HttpResponse): T {
    if (response.responseCode >= 400) {
      throw new ApiError(`HTTP错误: ${response.responseCode}`, response.responseCode);
    }
    
    const result = response.result as string;
    return JSON.parse(result) as T;
  }
}
