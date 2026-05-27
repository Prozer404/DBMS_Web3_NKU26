// 工具函数

// 格式化日期时间
export function formatDateTime(dateStr: string | undefined): string {
  if (!dateStr) return '-';
  
  try {
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  } catch (e) {
    return dateStr;
  }
}

// 格式化金额
export function formatAmount(amount: string | number, precision: number = 8): string {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(num)) return '0';
  
  return num.toFixed(precision);
}

// KYC状态文本
export function getKycStatusText(status: number): string {
  const statusMap: Map<number, string> = new Map([
    [0, '未验证'],
    [1, '审核中'],
    [2, '已验证'],
    [3, '已拒绝']
  ]);
  
  return statusMap.get(status) || '未知';
}

// KYC状态颜色
export function getKycStatusColor(status: number): string {
  const colorMap: Map<number, string> = new Map([
    [0, '#999999'],
    [1, '#FFA500'],
    [2, '#00FF00'],
    [3, '#FF0000']
  ]);
  
  return colorMap.get(status) || '#999999';
}

// 订单状态文本
export function getOrderStatusText(status: string): string {
  const statusMap: Map<string, string> = new Map([
    ['pending', '待处理'],
    ['partial', '部分成交'],
    ['filled', '已完成'],
    ['cancelled', '已取消']
  ]);
  
  return statusMap.get(status) || status;
}

// 订单方向文本
export function getOrderSideText(side: string): string {
  return side === 'buy' ? '买入' : '卖出';
}

// 验证邮箱格式
export function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// 显示提示消息
export function showToast(message: string): void {
  // 这里可以集成HarmonyOS的Toast API
  console.log(`Toast: ${message}`);
}
