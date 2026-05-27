import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { TradingPair, TradingPairCreate, TradingPairUpdate } from '../models/TradingPair';
import { TradingPairService } from '../services/TradingPairService';
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../components/CommonComponents';
import { formatAmount } from '../utils/CommonUtils';

@Entry
@Component
struct TradingPairPage {
  @State pairs: TradingPair[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showAddDialog: boolean = false;
  @State showEditDialog: boolean = false;
  @State selectedPair: TradingPair | null = null;
  
  // 新交易对表单
  @State newBaseCurrency: string = '';
  @State newQuoteCurrency: string = '';
  @State newMinOrderAmount: string = '0';
  @State newPricePrecision: number = 8;
  @State newAmountPrecision: number = 8;
  @State newIsActive: number = 1;
  
  private pairService: TradingPairService = TradingPairService.getInstance();
  
  aboutToAppear() {
    this.loadPairs();
  }
  
  async loadPairs() {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      this.pairs = await this.pairService.getTradingPairs();
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  async createPair() {
    if (!this.newBaseCurrency || !this.newQuoteCurrency) {
      promptAction.showToast({ message: '请填写基础币种和报价币种' });
      return;
    }
    
    try {
      await this.pairService.createTradingPair({
        base_currency: this.newBaseCurrency.toUpperCase(),
        quote_currency: this.newQuoteCurrency.toUpperCase(),
        min_order_amount: this.newMinOrderAmount,
        price_precision: this.newPricePrecision,
        amount_precision: this.newAmountPrecision
      });
      
      promptAction.showToast({ message: '创建成功' });
      this.showAddDialog = false;
      this.resetForm();
      await this.loadPairs();
    } catch (error) {
      promptAction.showToast({ message: `创建失败: ${error}` });
    }
  }
  
  async updatePair() {
    if (!this.selectedPair || !this.selectedPair.id) return;
    
    try {
      await this.pairService.updateTradingPair(this.selectedPair.id, {
        min_order_amount: this.newMinOrderAmount,
        price_precision: this.newPricePrecision,
        amount_precision: this.newAmountPrecision,
        is_active: this.newIsActive
      });
      
      promptAction.showToast({ message: '更新成功' });
      this.showEditDialog = false;
      this.resetForm();
      await this.loadPairs();
    } catch (error) {
      promptAction.showToast({ message: `更新失败: ${error}` });
    }
  }
  
  async deletePair(pairId: number) {
    try {
      await this.pairService.deleteTradingPair(pairId);
      promptAction.showToast({ message: '删除成功' });
      await this.loadPairs();
    } catch (error) {
      promptAction.showToast({ message: `删除失败: ${error}` });
    }
  }
  
  resetForm() {
    this.newBaseCurrency = '';
    this.newQuoteCurrency = '';
    this.newMinOrderAmount = '0';
    this.newPricePrecision = 8;
    this.newAmountPrecision = 8;
    this.newIsActive = 1;
    this.selectedPair = null;
  }
  
  editPair(pair: TradingPair) {
    this.selectedPair = pair;
    this.newMinOrderAmount = pair.min_order_amount;
    this.newPricePrecision = pair.price_precision;
    this.newAmountPrecision = pair.amount_precision;
    this.newIsActive = pair.is_active || 1;
    this.showEditDialog = true;
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
        
        Text('交易对管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Button('添加')
          .fontSize(14)
          .onClick(() => {
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#007DFF')
      .justifyContent(FlexAlign.SpaceBetween)
      
      // 内容区域
      if (this.isLoading) {
        LoadingComponent();
      } else if (this.errorMessage) {
        ErrorComponent({ 
          message: this.errorMessage,
          onRetry: () => {
            this.loadPairs();
          }
        });
      } else if (this.pairs.length === 0) {
        EmptyComponent({ message: '暂无交易对数据' });
      } else {
        List() {
          ForEach(this.pairs, (pair: TradingPair) => {
            ListItem() {
              Column() {
                Row() {
                  Text(`${pair.base_currency}/${pair.quote_currency}`)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                  
                  Blank()
                  
                  Text(pair.is_active === 1 ? '启用' : '禁用')
                    .fontSize(12)
                    .fontColor(pair.is_active === 1 ? '#00FF00' : '#FF0000')
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')
                .margin({ bottom: 8 })
                
                Row() {
                  Text(`ID: ${pair.id}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`最小金额: ${formatAmount(pair.min_order_amount)}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`价格精度: ${pair.price_precision}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`数量精度: ${pair.amount_precision}`)
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .width('100%')
                .margin({ bottom: 12 })
                
                Row() {
                  Button('编辑')
                    .fontSize(12)
                    .height(28)
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.editPair(pair);
                    })
                  
                  Button('删除')
                    .fontSize(12)
                    .height(28)
                    .backgroundColor('#FF0000')
                    .onClick(() => {
                      promptAction.showDialog({
                        title: '确认删除',
                        message: `确定要删除交易对 ${pair.base_currency}/${pair.quote_currency} 吗？`,
                        buttons: [
                          { text: '取消', color: '#999999' },
                          { text: '删除', color: '#FF0000' }
                        ]
                      }).then((result) => {
                        if (result.index === 1 && pair.id) {
                          this.deletePair(pair.id);
                        }
                      });
                    })
                }
                .width('100%')
                .justifyContent(FlexAlign.End)
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
      
      // 添加交易对对话框
      if (this.showAddDialog) {
        this.buildAddDialog();
      }
      
      // 编辑交易对对话框
      if (this.showEditDialog) {
        this.buildEditDialog();
      }
    }
    .width('100%')
    .height('100%')
  }
  
  @Builder
  buildAddDialog() {
    Column() {
      Column() {
        Text('添加交易对')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        Row() {
          TextInput({ placeholder: '基础币种 (如: BTC)' })
            .layoutWeight(1)
            .height(40)
            .onChange((value) => {
              this.newBaseCurrency = value.toUpperCase();
            })
          
          Text('/')
            .fontSize(20)
            .margin({ left: 8, right: 8 })
          
          TextInput({ placeholder: '报价币种 (如: USDT)' })
            .layoutWeight(1)
            .height(40)
            .onChange((value) => {
              this.newQuoteCurrency = value.toUpperCase();
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('最小订单金额:')
            .fontSize(14)
          
          TextInput({ text: this.newMinOrderAmount })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newMinOrderAmount = value;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('价格精度:')
            .fontSize(14)
          
          TextInput({ text: this.newPricePrecision.toString() })
            .type(InputType.Number)
            .width(60)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newPricePrecision = parseInt(value) || 8;
            })
          
          Text('数量精度:')
            .fontSize(14)
            .margin({ left: 16 })
          
          TextInput({ text: this.newAmountPrecision.toString() })
            .type(InputType.Number)
            .width(60)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newAmountPrecision = parseInt(value) || 8;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })
        
        Row() {
          Button('取消')
            .width('45%')
            .backgroundColor('#CCCCCC')
            .onClick(() => {
              this.showAddDialog = false;
              this.resetForm();
            })
          
          Button('确定')
            .width('45%')
            .onClick(() => {
              this.createPair();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('85%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showAddDialog = false;
      this.resetForm();
    })
  }
  
  @Builder
  buildEditDialog() {
    Column() {
      Column() {
        Text('编辑交易对')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        if (this.selectedPair) {
          Text(`交易对: ${this.selectedPair.base_currency}/${this.selectedPair.quote_currency}`)
            .fontSize(16)
            .fontColor('#007DFF')
            .width('100%')
            .margin({ bottom: 12 })
        }
        
        Row() {
          Text('最小订单金额:')
            .fontSize(14)
          
          TextInput({ text: this.newMinOrderAmount })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newMinOrderAmount = value;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('价格精度:')
            .fontSize(14)
          
          TextInput({ text: this.newPricePrecision.toString() })
            .type(InputType.Number)
            .width(60)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newPricePrecision = parseInt(value) || 8;
            })
          
          Text('数量精度:')
            .fontSize(14)
            .margin({ left: 16 })
          
          TextInput({ text: this.newAmountPrecision.toString() })
            .type(InputType.Number)
            .width(60)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newAmountPrecision = parseInt(value) || 8;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('状态:')
            .fontSize(14)
          
          Button('启用')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.newIsActive === 1 ? '#007DFF' : '#CCCCCC')
            .margin({ left: 8 })
            .onClick(() => {
              this.newIsActive = 1;
            })
          
          Button('禁用')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.newIsActive === 0 ? '#007DFF' : '#CCCCCC')
            .margin({ left: 8 })
            .onClick(() => {
              this.newIsActive = 0;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })
        
        Row() {
          Button('取消')
            .width('45%')
            .backgroundColor('#CCCCCC')
            .onClick(() => {
              this.showEditDialog = false;
              this.resetForm();
            })
          
          Button('确定')
            .width('45%')
            .onClick(() => {
              this.updatePair();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('85%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showEditDialog = false;
      this.resetForm();
    })
  }
}
