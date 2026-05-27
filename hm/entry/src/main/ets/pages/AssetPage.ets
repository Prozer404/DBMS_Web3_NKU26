import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Asset, LedgerEntry } from '../models/Asset';
import { AssetOrderService } from '../services/AssetOrderService';
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../components/CommonComponents';
import { formatDateTime, formatAmount } from '../utils/CommonUtils';

@Entry
@Component
struct AssetPage {
  @State assets: Asset[] = [];
  @State ledger: LedgerEntry[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State userIdInput: string = '';
  @State currentUserId: number = 0;
  @State showLedger: boolean = false;
  
  private assetService: AssetOrderService = AssetOrderService.getInstance();
  
  async loadAssets() {
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
      this.assets = await this.assetService.getUserAssets(userId);
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  async loadLedger() {
    if (this.currentUserId === 0) {
      promptAction.showToast({ message: '请先查询用户资产' });
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      this.ledger = await this.assetService.getUserLedger(this.currentUserId);
      this.showLedger = true;
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
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
        
        Text('资产查看')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Button('流水')
          .fontSize(14)
          .onClick(() => {
            this.loadLedger();
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
            this.loadAssets();
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
            if (this.showLedger) {
              this.loadLedger();
            } else {
              this.loadAssets();
            }
          }
        });
      } else if (this.showLedger) {
        // 显示流水记录
        Column() {
          Row() {
            Text('流水记录')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
            
            Button('返回资产')
              .fontSize(12)
              .onClick(() => {
                this.showLedger = false;
              })
          }
          .width('100%')
          .padding(16)
          .justifyContent(FlexAlign.SpaceBetween)
          
          if (this.ledger.length === 0) {
            EmptyComponent({ message: '暂无流水记录' });
          } else {
            List() {
              ForEach(this.ledger, (entry: LedgerEntry) => {
                ListItem() {
                  Column() {
                    Row() {
                      Text(entry.currency)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#007DFF')
                      
                      Text(entry.type)
                        .fontSize(12)
                        .fontColor('#999999')
                        .margin({ left: 8 })
                      
                      Blank()
                      
                      Text(formatDateTime(entry.created_at))
                        .fontSize(12)
                        .fontColor('#999999')
                    }
                    .width('100%')
                    .margin({ bottom: 8 })
                    
                    Row() {
                      Column() {
                        Text('变动金额')
                          .fontSize(12)
                          .fontColor('#999999')
                        Text(formatAmount(entry.amount))
                          .fontSize(14)
                          .fontColor(parseFloat(entry.amount) >= 0 ? '#00FF00' : '#FF0000')
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      
                      Column() {
                        Text('余额')
                          .fontSize(12)
                          .fontColor('#999999')
                        Text(formatAmount(entry.balance_after))
                          .fontSize(14)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      
                      Column() {
                        Text('冻结')
                          .fontSize(12)
                          .fontColor('#999999')
                        Text(formatAmount(entry.frozen_balance_after))
                          .fontSize(14)
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                    }
                    .width('100%')
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
        .layoutWeight(1)
      } else if (this.assets.length === 0) {
        EmptyComponent({ message: '请输入用户ID查询资产' });
      } else {
        // 显示资产列表
        List() {
          ForEach(this.assets, (asset: Asset) => {
            ListItem() {
              Column() {
                Row() {
                  Text(asset.currency)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                  
                  Blank()
                  
                  Text(`ID: ${asset.id}`)
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .width('100%')
                .margin({ bottom: 12 })
                
                Row() {
                  Column() {
                    Text('可用余额')
                      .fontSize(12)
                      .fontColor('#999999')
                    Text(formatAmount(asset.balance))
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#333333')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  
                  Column() {
                    Text('冻结余额')
                      .fontSize(12)
                      .fontColor('#999999')
                    Text(formatAmount(asset.frozen_balance))
                      .fontSize(20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#FFA500')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
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
}
