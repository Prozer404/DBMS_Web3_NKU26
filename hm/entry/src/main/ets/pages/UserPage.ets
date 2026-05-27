import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { User, UserCreate, UserUpdate } from '../models/User';
import { UserService } from '../services/UserService';
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../components/CommonComponents';
import { formatDateTime, getKycStatusText, getKycStatusColor, validateEmail } from '../utils/CommonUtils';

@Entry
@Component
struct UserPage {
  @State users: User[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State showAddDialog: boolean = false;
  @State showEditDialog: boolean = false;
  @State selectedUser: User | null = null;
  
  // 新用户表单
  @State newEmail: string = '';
  @State newPassword: string = '';
  @State newKycStatus: number = 0;
  
  private userService: UserService = UserService.getInstance();
  
  aboutToAppear() {
    this.loadUsers();
  }
  
  async loadUsers() {
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      this.users = await this.userService.getUsers();
    } catch (error) {
      this.errorMessage = `加载失败: ${error}`;
    } finally {
      this.isLoading = false;
    }
  }
  
  async createUser() {
    if (!validateEmail(this.newEmail)) {
      promptAction.showToast({ message: '请输入有效的邮箱地址' });
      return;
    }
    
    if (this.newPassword.length < 6) {
      promptAction.showToast({ message: '密码至少6位' });
      return;
    }
    
    try {
      await this.userService.createUser({
        email: this.newEmail,
        password_hash: this.newPassword, // 实际应用中应该加密
        kyc_status: this.newKycStatus
      });
      
      promptAction.showToast({ message: '创建成功' });
      this.showAddDialog = false;
      this.resetForm();
      await this.loadUsers();
    } catch (error) {
      promptAction.showToast({ message: `创建失败: ${error}` });
    }
  }
  
  async updateUser() {
    if (!this.selectedUser || !this.selectedUser.id) return;
    
    try {
      await this.userService.updateUser(this.selectedUser.id, {
        kyc_status: this.newKycStatus
      });
      
      promptAction.showToast({ message: '更新成功' });
      this.showEditDialog = false;
      this.resetForm();
      await this.loadUsers();
    } catch (error) {
      promptAction.showToast({ message: `更新失败: ${error}` });
    }
  }
  
  async deleteUser(userId: number) {
    try {
      await this.userService.deleteUser(userId);
      promptAction.showToast({ message: '删除成功' });
      await this.loadUsers();
    } catch (error) {
      promptAction.showToast({ message: `删除失败: ${error}` });
    }
  }
  
  resetForm() {
    this.newEmail = '';
    this.newPassword = '';
    this.newKycStatus = 0;
    this.selectedUser = null;
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
        
        Text('用户管理')
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
            this.loadUsers();
          }
        });
      } else if (this.users.length === 0) {
        EmptyComponent({ message: '暂无用户数据' });
      } else {
        List() {
          ForEach(this.users, (user: User) => {
            ListItem() {
              Row() {
                Column() {
                  Text(user.email)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                  
                  Row() {
                    Text(`ID: ${user.id}`)
                      .fontSize(12)
                      .fontColor('#999999')
                    
                    Text(' | ')
                      .fontSize(12)
                      .fontColor('#999999')
                    
                    Text(formatDateTime(user.created_at))
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                  .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                
                Column() {
                  Text(getKycStatusText(user.kyc_status))
                    .fontSize(14)
                    .fontColor(getKycStatusColor(user.kyc_status))
                    .fontWeight(FontWeight.Bold)
                  
                  Row() {
                    Button('编辑')
                      .fontSize(12)
                      .height(28)
                      .margin({ right: 8 })
                      .onClick(() => {
                        this.selectedUser = user;
                        this.newKycStatus = user.kyc_status;
                        this.showEditDialog = true;
                      })
                    
                    Button('删除')
                      .fontSize(12)
                      .height(28)
                      .backgroundColor('#FF0000')
                      .onClick(() => {
                        promptAction.showDialog({
                          title: '确认删除',
                          message: `确定要删除用户 ${user.email} 吗？`,
                          buttons: [
                            { text: '取消', color: '#999999' },
                            { text: '删除', color: '#FF0000' }
                          ]
                        }).then((result) => {
                          if (result.index === 1 && user.id) {
                            this.deleteUser(user.id);
                          }
                        });
                      })
                  }
                  .margin({ top: 8 })
                }
                .alignItems(HorizontalAlign.End)
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
      
      // 添加用户对话框
      if (this.showAddDialog) {
        this.buildAddDialog();
      }
      
      // 编辑用户对话框
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
        Text('添加用户')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        TextInput({ placeholder: '邮箱' })
          .width('100%')
          .height(40)
          .margin({ bottom: 12 })
          .onChange((value) => {
            this.newEmail = value;
          })
        
        TextInput({ placeholder: '密码' })
          .width('100%')
          .height(40)
          .type(InputType.Password)
          .margin({ bottom: 12 })
          .onChange((value) => {
            this.newPassword = value;
          })
        
        Row() {
          Text('KYC状态:')
            .fontSize(14)
          
          ForEach([0, 1, 2, 3], (status: number) => {
            Button(getKycStatusText(status))
              .fontSize(12)
              .height(32)
              .backgroundColor(this.newKycStatus === status ? '#007DFF' : '#CCCCCC')
              .margin({ left: 8 })
              .onClick(() => {
                this.newKycStatus = status;
              })
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
              this.createUser();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('80%')
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
        Text('编辑用户')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 20 })
        
        if (this.selectedUser) {
          Text(`邮箱: ${this.selectedUser.email}`)
            .fontSize(14)
            .width('100%')
            .margin({ bottom: 12 })
        }
        
        Row() {
          Text('KYC状态:')
            .fontSize(14)
          
          ForEach([0, 1, 2, 3], (status: number) => {
            Button(getKycStatusText(status))
              .fontSize(12)
              .height(32)
              .backgroundColor(this.newKycStatus === status ? '#007DFF' : '#CCCCCC')
              .margin({ left: 8 })
              .onClick(() => {
                this.newKycStatus = status;
              })
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
              this.updateUser();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('80%')
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
