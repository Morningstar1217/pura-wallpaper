import { validWallhavenUsername } from '../core/Wallpaper';
import { GallerySource, gallerySourceLabel } from '../core/GallerySource';
import { TokenStore, WallhavenCredentials } from '../services/TokenStore';
import { WallhavenService } from '../services/WallhavenService';

@Component
export struct SettingsView {
  @Require @Prop @Watch('onSourceChanged') source: GallerySource;
  onBack: () => void = () => {};
  onBusy: (busy: boolean) => void = () => {};
  onSaved: (account: WallhavenCredentials) => void = () => {};
  onSource: (source: GallerySource) => Promise<void> = async () => {};
  @State private apiKey: string = '';
  @State private username: string = '';
  @State private loading: boolean = true;
  @State private saving: boolean = false;
  @State private switching: boolean = false;
  @State private sourceError: string = '';
  @State private saved: boolean = false;
  @State private dailyExpanded: boolean = false;
  @State private errorText: string = '';
  private store: TokenStore = new TokenStore();
  private verification: WallhavenService = new WallhavenService();
  private active: boolean = false;
  private loadRevision: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.onSourceChanged();
  }

  private onSourceChanged(): void {
    if (!this.active) return;
    if (this.source === GallerySource.Wallhaven) {
      this.loadToken();
    } else {
      this.loadRevision++;
      this.apiKey = '';
      this.username = '';
      this.errorText = '';
      this.saved = false;
    }
  }

  private async selectSource(source: GallerySource): Promise<void> {
    if (source === this.source || this.switching || this.saving) return;
    this.switching = true;
    this.sourceError = '';
    this.onBusy(true);
    try {
      await this.onSource(source);
    } catch {
      this.sourceError = '无法保存图库来源，请重试';
    } finally {
      this.switching = false;
      this.onBusy(false);
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.verification.cancel();
    this.apiKey = '';
    this.username = '';
  }

  private async loadToken(): Promise<void> {
    const revision = ++this.loadRevision;
    this.loading = true;
    this.errorText = '';
    try {
      const value = await this.store.read();
      if (this.active && revision === this.loadRevision) {
        this.apiKey = value.token;
        this.username = value.username;
      }
    } catch (error) {
      if (this.active && revision === this.loadRevision) this.errorText = (error as Error).message;
    } finally {
      if (this.active && revision === this.loadRevision) this.loading = false;
    }
  }

  private async save(): Promise<void> {
    if (this.source !== GallerySource.Wallhaven || this.saving || this.loading || this.switching) return;
    this.saved = false;
    const token = this.apiKey.trim();
    const username = token.length === 0 ? '' : this.username.trim();
    if (token.length > 0 && !/^[a-zA-Z0-9]{32}$/.test(token)) {
      this.errorText = '请输入 32 位 Wallhaven API Key';
      return;
    }
    if (username.length > 0 && !validWallhavenUsername(username)) {
      this.errorText = '请输入自己的 Wallhaven 用户名（字母、数字、下划线或连字符）';
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
      const account: WallhavenCredentials = { token: token, username: username };
      await this.store.save(account);
      if (this.active) {
        this.username = username;
        this.apiKey = token;
        this.saved = true;
        this.onSaved(account);
      }
    } catch (error) {
      if (this.active) this.errorText = (error as Error).message || '保存失败，请检查网络后重试';
    } finally {
      this.verification.setToken('');
      if (this.active) this.saving = false;
      this.onBusy(false);
    }
  }

  @Builder
  private sourceRow(source: GallerySource, subtitle: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(gallerySourceLabel(source)).fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text(subtitle).fontSize(13).fontColor($r('app.color.muted'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        SymbolGlyph(this.source === source ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(24).fontColor([this.source === source ? $r('app.color.accent') : $r('app.color.muted')])
          .accessibilityLevel('no')
      }.width('100%')
    }.width('100%').constraintSize({ minHeight: 66 }).padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(Color.Transparent).enabled(!this.switching && !this.saving)
      .accessibilitySelected(this.source === source).onClick(() => this.selectSource(source))
  }

  @Builder
  private accountCard() {
    Column({ space: 9 }) {
      Text('Wallhaven 账户').fontSize(19).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
      if (this.loading) {
        LoadingProgress().width(28).height(28).color($r('app.color.accent'))
      } else {
        Text('API Key（选填）').fontSize(14).fontColor($r('app.color.text'))
        TextInput({ text: this.apiKey, placeholder: '输入 API Key' }).type(InputType.Password).maxLength(32)
          .height(44).borderRadius(12).backgroundColor($r('app.color.surface')).fontColor($r('app.color.text'))
          .accessibilityText('API Key，选填').enabled(!this.saving && !this.switching)
          .onChange((value: string) => { this.apiKey = value; this.saved = false; })
        Text('用户名（查看收藏时填写）').fontSize(14).fontColor($r('app.color.text'))
        TextInput({ text: this.username, placeholder: '自己的 Wallhaven 用户名' }).maxLength(32)
          .height(44).borderRadius(12).backgroundColor($r('app.color.surface')).fontColor($r('app.color.text'))
          .accessibilityText('Wallhaven 用户名').enabled(!this.saving && !this.switching)
          .onChange((value: string) => { this.username = value; this.saved = false; })
        Text('普通浏览无需 Key。查看收藏时，两项须属于同一账户；清空 Key 后保存可删除账户配置。')
          .fontSize(12).fontColor($r('app.color.muted')).lineHeight(18)
        if (this.errorText.length > 0) {
          Text(this.errorText).fontSize(13).fontColor($r('app.color.error')).lineHeight(20)
        }
        Row() {
          if (this.saved) {
            Text('已保存到本机').fontSize(13).fontColor($r('app.color.accent'))
          }
          Blank()
          Button(this.saving ? '验证中…' : '保存').height(44).constraintSize({ minWidth: 84 }).fontSize(15)
            .borderRadius(14).backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
            .enabled(!this.saving && !this.switching).onClick(() => this.save())
        }.width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).borderRadius(18)
      .backgroundColor($r('app.color.accent_panel'))
  }

  @Builder
  private dailySettings() {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text('每日推荐').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
            Text('仅用于每日推荐').fontSize(13).fontColor($r('app.color.muted'))
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('必应').fontSize(14).fontColor($r('app.color.muted'))
          SymbolGlyph(this.dailyExpanded ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_forward'))
            .fontSize(15).fontColor([$r('app.color.muted')]).accessibilityLevel('no')
        }.width('100%')
      }.width('100%').constraintSize({ minHeight: 66 }).padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(Color.Transparent).onClick(() => this.dailyExpanded = !this.dailyExpanded)
      if (this.dailyExpanded) {
        Divider().color($r('app.color.line')).margin({ left: 16, right: 16 })
        Text('每日推荐固定使用必应中国的每日壁纸，不参与图库搜索或分类。')
          .width('100%').padding(16).fontSize(14).fontColor($r('app.color.muted')).lineHeight(21)
      }
    }.width('100%').borderRadius(18).border({ width: 1, color: $r('app.color.line') })
      .backgroundColor($r('app.color.surface')).clip(true)
  }

  build() {
    Column({ space: 16 }) {
      Stack({ alignContent: Alignment.Start }) {
        Text('设置').width('100%').textAlign(TextAlign.Center).fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text'))
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_backward')).fontSize(22).fontColor([$r('app.color.text')])
            .accessibilityLevel('no')
        }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('返回').enabled(!this.saving && !this.switching).onClick(() => this.onBack())
      }.width('100%').height(56)
      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 12 }) {
            Text('图库来源').fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
            Column() {
              this.sourceRow(GallerySource.Gallery360, '默认 · 无需登录')
              Divider().color($r('app.color.line')).margin({ left: 16, right: 16 })
              this.sourceRow(GallerySource.Wallhaven, 'wallhaven.cc · 普通浏览无需登录')
            }.width('100%').borderRadius(18).border({ width: 1, color: $r('app.color.line') })
              .backgroundColor($r('app.color.surface')).clip(true)
            if (this.sourceError.length > 0) {
              Text(this.sourceError).fontSize(13).fontColor($r('app.color.error'))
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
          if (this.source === GallerySource.Wallhaven) {
            this.accountCard()
          }
          this.dailySettings()
        }.width('100%').constraintSize({ maxWidth: 600 }).padding({ bottom: 24 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.padding({ left: 16, right: 16, top: 4 }).width('100%').height('100%')
      .backgroundColor($r('app.color.background'))
  }
}

