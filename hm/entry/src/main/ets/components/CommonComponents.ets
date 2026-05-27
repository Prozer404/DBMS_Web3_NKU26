// 通用UI组件

// 加载状态组件
@Component
export struct LoadingComponent {
  build() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color('#007DFF')
      Text('加载中...')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 空状态组件
@Component
export struct EmptyComponent {
  @Prop message: string = '暂无数据';
  
  build() {
    Column() {
      Text('📭')
        .fontSize(48)
      Text(this.message)
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 错误状态组件
@Component
export struct ErrorComponent {
  @Prop message: string = '加载失败';
  onRetry?: () => void;
  
  build() {
    Column() {
      Text('❌')
        .fontSize(48)
      Text(this.message)
        .fontSize(14)
        .fontColor('#FF0000')
        .margin({ top: 10 })
      if (this.onRetry) {
        Button('重试')
          .fontSize(14)
          .margin({ top: 10 })
          .onClick(() => {
            if (this.onRetry) {
              this.onRetry();
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 列表项组件
@Component
export struct ListItemComponent {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop value: string = '';
  onItemClick?: () => void;
  
  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Text(this.subtitle)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      
      Text(this.value)
        .fontSize(14)
        .fontColor('#007DFF')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}
