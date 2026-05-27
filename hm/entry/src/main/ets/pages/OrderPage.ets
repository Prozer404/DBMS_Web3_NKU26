import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Order, OrderCreate } from '../models/Order';
import { AssetOrderService } from '../services/AssetOrderService';
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../components/CommonComponents';
import { formatDateTime, formatAmount, getOrderStatusText, getOrderSideText } from '../utils/CommonUtils';

@Entry
@Component
struct OrderPage {
  @State orders: Order[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State userIdInput: string = '';
  @State currentUserId: number = 0;
  
  private orderService: AssetOrderService = AssetOrderService.getInstance();
  
  async loadOrders() {
    if (!this.userIdInput) {
      promptAction.showToast({ message: '请输入用户ID' });
      return;
    }
    
    const userId = parseInt(this.userIdInput);
    if (isNaN(userId)) {
      promptAction.showToast({ message: '用户ID必须是数字' });
      return;
    }
    
    this.currentUserId = userId;
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      this.orders = await this.orderService.getUserOrders(userId);
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  async cancelOrder(orderId: number) {
    try {
      await this.orderService.cancelOrder(orderId);
      promptAction.showToast({ message: '取消成功' });
      await this.loadOrders();
    } catch (error) {
      promptAction.showToast({ message: `取消失败: ${error}` });
    }
  }
  
  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .fontSize(14)
          .backgroundColor('#CCCCCC')
          .onClick(() => {
            router.back();
          })
        
        Text('订单管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Button('刷新')
          .fontSize(14)
          .onClick(() => {
            this.loadOrders();
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#007DFF')
      .justifyContent(FlexAlign.SpaceBetween)
      
      // 搜索栏
      Row() {
        TextInput({ placeholder: '输入用户ID', text: this.userIdInput })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(40)
          .onChange((value) => {
            this.userIdInput = value;
          })
        
        Button('查询')
          .height(40)
          .margin({ left: 12 })
          .onClick(() => {
            this.loadOrders();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      
      // 内容区域
      if (this.isLoading) {
        LoadingComponent();
      } else if (this.errorMessage) {
        ErrorComponent({ 
          message: this.errorMessage,
          onRetry: () => {
            this.loadOrders();
          }
        });
      } else if (this.orders.length === 0) {
        EmptyComponent({ message: '请输入用户ID查询订单' });
      } else {
        List() {
          ForEach(this.orders, (order: Order) => {
            ListItem() {
              Column() {
                Row() {
                  Text(`订单 #${order.id}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                  
                  Text(getOrderSideText(order.side))
                    .fontSize(12)
                    .fontColor(order.side === 'buy' ? '#00FF00' : '#FF0000')
                    .fontWeight(FontWeight.Bold)
                    .margin({ left: 8 })
                  
                  Blank()
                  
                  Text(getOrderStatusText(order.status))
                    .fontSize(12)
                    .fontColor(this.getStatusColor(order.status))
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')
                .margin({ bottom: 8 })
                
                Row() {
                  Text(`交易对ID: ${order.pair_id}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`类型: ${order.type}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(formatDateTime(order.created_at))
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .width('100%')
                .margin({ bottom: 12 })
                
                Row() {
                  Column() {
                    Text('价格')
                      .fontSize(12)
                      .fontColor('#999999')
                    Text(formatAmount(order.price))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  
                  Column() {
                    Text('总量')
                      .fontSize(12)
                      .fontColor('#999999')
                    Text(formatAmount(order.total_amount))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  
                  Column() {
                    Text('已成交')
                      .fontSize(12)
                      .fontColor('#999999')
                    Text(formatAmount(order.filled_amount))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#00FF00')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 12 })
                
                if (order.status === 'pending' || order.status === 'partial') {
                  Row() {
                    Button('取消订单')
                      .fontSize(12)
                      .height(32)
                      .backgroundColor('#FF0000')
                      .onClick(() => {
                        promptAction.showDialog({
                          title: '确认取消',
                          message: `确定要取消订单 #${order.id} 吗？`,
                          buttons: [
                            { text: '取消', color: '#999999' },
                            { text: '确定', color: '#FF0000' }
                          ]
                        }).then((result) => {
                          if (result.index === 1 && order.id) {
                            this.cancelOrder(order.id);
                          }
                        });
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .margin({ bottom: 8 })
            }
            .padding({ left: 16, right: 16 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F0F0F0')
      }
    }
    .width('100%')
    .height('100%')
  }
  
  private getStatusColor(status: string): string {
    const colorMap: Map<string, string> = new Map([
      ['pending', '#FFA500'],
      ['partial', '#007DFF'],
      ['filled', '#00FF00'],
      ['cancelled', '#999999']
    ]);
    
    return colorMap.get(status) || '#999999';
  }
}
