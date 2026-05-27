import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Currency, CurrencyCreate, CurrencyUpdate } from '../models/Currency';
import { CurrencyService } from '../services/CurrencyService';
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../components/CommonComponents';
import { formatAmount } from '../utils/CommonUtils';

@Entry
@Component
struct CurrencyPage {
  @State currencies: Currency[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showAddDialog: boolean = false;
  @State showEditDialog: boolean = false;
  @State selectedCurrency: Currency | null = null;
  
  // 新币种表单
  @State newCode: string = '';
  @State newName: string = '';
  @State newPrecision: number = 8;
  @State newWithdrawalFee: string = '0';
  @State newMinWithdrawal: string = '0';
  @State newIsActive: number = 1;
  
  private currencyService: CurrencyService = CurrencyService.getInstance();
  
  aboutToAppear() {
    this.loadCurrencies();
  }
  
  async loadCurrencies() {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      this.currencies = await this.currencyService.getCurrencies();
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  async createCurrency() {
    if (!this.newCode || !this.newName) {
      promptAction.showToast({ message: '请填写币种代码和名称' });
      return;
    }
    
    try {
      await this.currencyService.createCurrency({
        code: this.newCode.toUpperCase(),
        name: this.newName,
        precision: this.newPrecision,
        withdrawal_fee: this.newWithdrawalFee,
        min_withdrawal: this.newMinWithdrawal,
        is_active: this.newIsActive
      });
      
      promptAction.showToast({ message: '创建成功' });
      this.showAddDialog = false;
      this.resetForm();
      await this.loadCurrencies();
    } catch (error) {
      promptAction.showToast({ message: `创建失败: ${error}` });
    }
  }
  
  async updateCurrency() {
    if (!this.selectedCurrency) return;
    
    try {
      await this.currencyService.updateCurrency(this.selectedCurrency.code, {
        name: this.newName,
        precision: this.newPrecision,
        withdrawal_fee: this.newWithdrawalFee,
        min_withdrawal: this.newMinWithdrawal,
        is_active: this.newIsActive
      });
      
      promptAction.showToast({ message: '更新成功' });
      this.showEditDialog = false;
      this.resetForm();
      await this.loadCurrencies();
    } catch (error) {
      promptAction.showToast({ message: `更新失败: ${error}` });
    }
  }
  
  async deleteCurrency(code: string) {
    try {
      await this.currencyService.deleteCurrency(code);
      promptAction.showToast({ message: '删除成功' });
      await this.loadCurrencies();
    } catch (error) {
      promptAction.showToast({ message: `删除失败: ${error}` });
    }
  }
  
  resetForm() {
    this.newCode = '';
    this.newName = '';
    this.newPrecision = 8;
    this.newWithdrawalFee = '0';
    this.newMinWithdrawal = '0';
    this.newIsActive = 1;
    this.selectedCurrency = null;
  }
  
  editCurrency(currency: Currency) {
    this.selectedCurrency = currency;
    this.newName = currency.name;
    this.newPrecision = currency.precision;
    this.newWithdrawalFee = currency.withdrawal_fee;
    this.newMinWithdrawal = currency.min_withdrawal;
    this.newIsActive = currency.is_active;
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
        
        Text('币种管理')
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
            this.loadCurrencies();
          }
        });
      } else if (this.currencies.length === 0) {
        EmptyComponent({ message: '暂无币种数据' });
      } else {
        List() {
          ForEach(this.currencies, (currency: Currency) => {
            ListItem() {
              Column() {
                Row() {
                  Text(currency.code)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                  
                  Text(currency.name)
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ left: 8 })
                  
                  Blank()
                  
                  Text(currency.is_active === 1 ? '启用' : '禁用')
                    .fontSize(12)
                    .fontColor(currency.is_active === 1 ? '#00FF00' : '#FF0000')
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')
                .margin({ bottom: 8 })
                
                Row() {
                  Text(`精度: ${currency.precision}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`提现费: ${formatAmount(currency.withdrawal_fee, currency.precision)}`)
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#999999')
                  
                  Text(`最小提现: ${formatAmount(currency.min_withdrawal, currency.precision)}`)
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
                      this.editCurrency(currency);
                    })
                  
                  Button('删除')
                    .fontSize(12)
                    .height(28)
                    .backgroundColor('#FF0000')
                    .onClick(() => {
                      promptAction.showDialog({
                        title: '确认删除',
                        message: `确定要删除币种 ${currency.code} 吗？`,
                        buttons: [
                          { text: '取消', color: '#999999' },
                          { text: '删除', color: '#FF0000' }
                        ]
                      }).then((result) => {
                        if (result.index === 1) {
                          this.deleteCurrency(currency.code);
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
      
      // 添加币种对话框
      if (this.showAddDialog) {
        this.buildAddDialog();
      }
      
      // 编辑币种对话框
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
        Text('添加币种')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        TextInput({ placeholder: '币种代码 (如: BTC)' })
          .width('100%')
          .height(40)
          .margin({ bottom: 12 })
          .onChange((value) => {
            this.newCode = value.toUpperCase();
          })
        
        TextInput({ placeholder: '币种名称 (如: Bitcoin)' })
          .width('100%')
          .height(40)
          .margin({ bottom: 12 })
          .onChange((value) => {
            this.newName = value;
          })
        
        Row() {
          Text('精度:')
            .fontSize(14)
          
          TextInput({ text: this.newPrecision.toString() })
            .type(InputType.Number)
            .width(80)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newPrecision = parseInt(value) || 8;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('提现费:')
            .fontSize(14)
          
          TextInput({ text: this.newWithdrawalFee })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newWithdrawalFee = value;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('最小提现:')
            .fontSize(14)
          
          TextInput({ text: this.newMinWithdrawal })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newMinWithdrawal = value;
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
              this.showAddDialog = false;
              this.resetForm();
            })
          
          Button('确定')
            .width('45%')
            .onClick(() => {
              this.createCurrency();
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
        Text('编辑币种')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        if (this.selectedCurrency) {
          Text(`币种代码: ${this.selectedCurrency.code}`)
            .fontSize(14)
            .width('100%')
            .margin({ bottom: 12 })
        }
        
        TextInput({ placeholder: '币种名称', text: this.newName })
          .width('100%')
          .height(40)
          .margin({ bottom: 12 })
          .onChange((value) => {
            this.newName = value;
          })
        
        Row() {
          Text('精度:')
            .fontSize(14)
          
          TextInput({ text: this.newPrecision.toString() })
            .type(InputType.Number)
            .width(80)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newPrecision = parseInt(value) || 8;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('提现费:')
            .fontSize(14)
          
          TextInput({ text: this.newWithdrawalFee })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newWithdrawalFee = value;
            })
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        Row() {
          Text('最小提现:')
            .fontSize(14)
          
          TextInput({ text: this.newMinWithdrawal })
            .width(100)
            .height(40)
            .margin({ left: 8 })
            .onChange((value) => {
              this.newMinWithdrawal = value;
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
              this.updateCurrency();
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
