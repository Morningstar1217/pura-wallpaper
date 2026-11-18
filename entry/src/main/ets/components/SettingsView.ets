import { DeviceProfile } from '../core/Wallpaper';
import { BackButton } from './BackButton';
import { TokenStore } from '../services/TokenStore';
import { WallhavenService } from '../services/WallhavenService';

@Component
export struct SettingsView {
  @Require @Prop deviceProfile: DeviceProfile;
  onBack: () => void = () => {};
  onBusy: (busy: boolean) => void = () => {};
  onSaved: (token: string) => void = () => {};
  @State private apiKey: string = '';
  @State private loading: boolean = true;
  @State private saving: boolean = false;
  @State private errorText: string = '';
  private store: TokenStore = new TokenStore();
  private verification: WallhavenService = new WallhavenService();
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.loadToken();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.verification.cancel();
    this.apiKey = '';
  }

  private async loadToken(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const value = await this.store.read();
      if (this.active) this.apiKey = value;
    } catch (error) {
      if (this.active) this.errorText = (error as Error).message;
    } finally {
      if (this.active) this.loading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.saving || this.loading) return;
    const token = this.apiKey.trim();
    if (token.length > 0 && !/^[a-zA-Z0-9]{32}$/.test(token)) {
      this.errorText = '请输入 32 位 Wallhaven API Key';
      return;
    }
    this.saving = true;
    this.onBusy(true);
    this.errorText = '';
    try {
      if (token.length > 0) {
        this.verification.setToken(token);
        await this.verification.collections();
      }
      if (!this.active) return;
      await this.store.save(token);
      if (this.active) this.onSaved(token);
    } catch (error) {
      if (this.active) this.errorText = (error as Error).message || '保存失败，请检查网络后重试';
    } finally {
      if (this.active) this.saving = false;
      this.onBusy(false);
    }
  }

  build() {
    Column({ space: 24 }) {
      Row() {
        BackButton({ isEnabled: !this.saving, onBack: () => this.onBack() })
        Blank()
        Text('设置').fontSize(18).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
        Blank()
        Text('').width(64)
      }.width('100%')
      Scroll() {
        Column({ space: 24 }) {
          Column({ space: 12 }) {
            Text('Wallhaven').fontSize(28).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            Text('pangdunqing').fontSize(15).fontColor($r('app.color.muted'))
          }.width('100%').alignItems(HorizontalAlign.Start)
          Column({ space: 14 }) {
            Text('API Key').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
            if (this.loading) {
              LoadingProgress().width(28).height(28).color($r('app.color.accent'))
            } else {
              TextInput({ text: this.apiKey, placeholder: '输入 Wallhaven API Key' })
                .type(InputType.Password).maxLength(32).height(52)
                .backgroundColor($r('app.color.background')).fontColor($r('app.color.text'))
                .onChange((value: string) => this.apiKey = value)
                .enabled(!this.saving)
            }
            Text('用于访问你的私有收藏集，保存在本机安全存储中。')
              .fontSize(14).fontColor($r('app.color.muted')).lineHeight(22)
            Text('可在 wallhaven.cc/settings/account 获取。留空保存可清除已存的 API Key。')
              .fontSize(14).fontColor($r('app.color.muted')).lineHeight(22)
            if (this.errorText.length > 0) {
              Text(this.errorText).fontSize(14).fontColor($r('app.color.error')).lineHeight(22)
            }
            Button(this.saving ? '验证并保存中…' : '保存')
              .width('100%').height(48).fontSize(16)
              .backgroundColor($r('app.color.accent')).fontColor($r('app.color.background'))
              .enabled(!this.loading && !this.saving).onClick(() => this.save())
          }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface'))
          .alignItems(HorizontalAlign.Start).width('100%')
          Column({ space: 10 }) {
            Text('设置壁纸').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
            Text('预览并裁剪后保存到图库，在系统图库中打开图片并设为桌面或锁屏壁纸。')
              .fontSize(14).fontColor($r('app.color.muted')).lineHeight(24)
            Text('裁剪尺寸 ' + this.deviceProfile.width + ' × ' + this.deviceProfile.height + '，适配 ' + this.deviceProfile.name + '。')
              .fontSize(14).fontColor($r('app.color.muted'))
          }.padding(20).borderRadius(24).backgroundColor($r('app.color.surface'))
          .alignItems(HorizontalAlign.Start).width('100%')
        }.width('100%').constraintSize({ maxWidth: 600 }).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.padding({ left: 20, right: 20, top: 12, bottom: 12 }).width('100%').height('100%')
    .backgroundColor($r('app.color.background'))
  }
}

