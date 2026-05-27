import router from '@ohos.router';

// 菜单项接口
interface MenuItem {
  icon: string;
  title: string;
  route: string;
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  
  // 菜单项
  private menuItems: MenuItem[] = [
    { icon: '👥', title: '用户管理', route: 'pages/UserPage' },
    { icon: '💰', title: '币种管理', route: 'pages/CurrencyPage' },
    { icon: '📊', title: '交易对管理', route: 'pages/TradingPairPage' },
    { icon: '💎', title: '资产查看', route: 'pages/AssetPage' },
    { icon: '📝', title: '订单管理', route: 'pages/OrderPage' }
  ];
  
  build() {
    Column() {
      // 标题栏
      Row() {
        Text('Web3 数据库管理')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(60)
      .backgroundColor('#007DFF')
      .justifyContent(FlexAlign.Center)
      
      // 菜单网格
      Grid() {
        ForEach(this.menuItems, (item: MenuItem, index: number) => {
          GridItem() {
            Column() {
              Text(item.icon)
                .fontSize(48)
                .margin({ bottom: 12 })
              
              Text(item.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: '#1F000000',
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              router.pushUrl({
                url: item.route
              });
            })
          }
          .padding(8)
        })
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .columnsGap(16)
      .rowsGap(16)
      .width('100%')
      .layoutWeight(1)
      .padding(16)
      
      // 底部信息
      Row() {
        Text('数据库管理系统 v1.0')
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
  }
}
