import { PreviewView } from '../components/PreviewView';
import { HomeView } from '../components/HomeView';
import { SettingsView } from '../components/SettingsView';
import { DailyView } from '../components/DailyView';
import { common } from '@kit.AbilityKit';
import { Wallpaper, DeviceProfile } from '../core/Wallpaper';
import { GallerySource } from '../core/GallerySource';
import { GallerySourceStore } from '../services/GallerySourceStore';
import { WallhavenService } from '../services/WallhavenService';
import { TokenStore, WallhavenCredentials } from '../services/TokenStore';
import { getDeviceProfile } from '../services/DeviceProfile';

@Entry
@Component
struct Index {
  @StorageLink('deviceProfile') private deviceProfile: DeviceProfile = { name: '', width: 0, height: 0 };
  @State private ready: boolean = false;
  @State private errorText: string = '';
  @State private page: string = 'home';
  @State private cropFullscreen: boolean = false;
  @State private accountRevision: number = 0;
  @State private selected: Wallpaper | undefined = undefined;
  @State private source: GallerySource = GallerySource.Gallery360;
  @State private tab: number = 0;
  private busy: boolean = false;
  private service: WallhavenService = new WallhavenService();
  private collectionService: WallhavenService = new WallhavenService();
  private tabs: TabsController = new TabsController();
  private sourceStore: GallerySourceStore = new GallerySourceStore();
  private sourceRevision: number = 0;
  private username: string = '';

  aboutToAppear(): void { this.initialize(); }

  aboutToDisappear(): void {
    this.service.cancel();
    this.collectionService.cancel();
  }

  onBackPress(): boolean {
    if (this.busy) return true;
    if (this.cropFullscreen) {
      this.cropFullscreen = false;
      return true;
    }
    if (this.page !== 'home') {
      this.page = 'home';
      this.selected = undefined;
      return true;
    }
    if (this.tab !== 0) {
      this.tabs.changeIndex(0);
      return true;
    }
    return false;
  }

  private async initialize(): Promise<void> {
    this.errorText = '';
    try {
      AppStorage.setOrCreate('deviceProfile', getDeviceProfile());
      this.ready = true;
    } catch (error) {
      this.errorText = (error as Error).message;
      return;
    }
    this.restoreSource();
    const revision = this.accountRevision;
    try {
      const account = await new TokenStore().read();
      if (revision === this.accountRevision) this.setAccount(account);
    } catch {
      // An optional Wallhaven account must not prevent browsing 360 wallpapers.
    }
  }

  private setAccount(account: WallhavenCredentials): void {
    this.service.setToken(account.token);
    this.collectionService.setToken(account.token);
    this.username = account.username;
    this.accountRevision++;
  }

  private async restoreSource(): Promise<void> {
    const revision = this.sourceRevision;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const source = await this.sourceStore.read(context);
      if (this.sourceRevision === revision) this.source = source;
    } catch {
      // Fall back to the default gallery without blocking the daily screen.
    }
  }

  private async changeSource(source: GallerySource): Promise<void> {
    this.sourceRevision++;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await this.sourceStore.save(context, source);
    this.source = source;
  }

  private openWallpaper(item: Wallpaper): void {
    this.selected = item;
    this.page = 'preview';
  }

  @Builder
  private tabItem(title: string, index: number, icon: Resource, selectedIcon: Resource) {
    Column({ space: 4 }) {
      SymbolGlyph(this.tab === index ? selectedIcon : icon).fontSize(24)
        .fontColor([this.tab === index ? $r('app.color.accent') : $r('app.color.muted')]).accessibilityLevel('no')
      Text(title).fontSize(12).maxLines(1)
        .fontColor(this.tab === index ? $r('app.color.accent') : $r('app.color.muted'))
        .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Regular)
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      .accessibilityGroup(true).accessibilityText(title).accessibilitySelected(this.tab === index)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor($r('app.color.background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .hitTestBehavior(HitTestMode.None)
      if (this.ready) {
        Tabs({ barPosition: BarPosition.End, controller: this.tabs }) {
          TabContent() {
            DailyView({ active: this.tab === 0 && this.page === 'home',
              onSettings: () => this.page = 'settings', onGallery: () => this.tabs.changeIndex(1),
              onOpen: (item: Wallpaper) => this.openWallpaper(item) })
          }.tabBar(this.tabItem('发现', 0, $r('sys.symbol.compass'), $r('sys.symbol.compass')))
          TabContent() {
            HomeView({ active: this.tab === 1 && this.page === 'home', source: this.source,
              service: this.service, accountRevision: this.accountRevision, getUsername: () => this.username,
              onSettings: () => this.page = 'settings', onOpen: (item: Wallpaper) => this.openWallpaper(item) })
          }.tabBar(this.tabItem('图库', 1, $r('sys.symbol.picture'), $r('sys.symbol.picture_fill')))
          TabContent() {
            HomeView({ active: this.tab === 2 && this.page === 'home', source: this.source, collectionsMode: true,
              service: this.collectionService, accountRevision: this.accountRevision, getUsername: () => this.username,
              onSettings: () => this.page = 'settings', onOpen: (item: Wallpaper) => this.openWallpaper(item) })
          }.tabBar(this.tabItem('我的收藏', 2, $r('sys.symbol.heart'), $r('sys.symbol.heart_fill')))
        }.width('100%').height('100%').barMode(BarMode.Fixed).barHeight(62).barOverlap(false)
          .barBackgroundColor($r('app.color.background')).divider({ strokeWidth: 0.5, color: $r('app.color.line') })
          .scrollable(false).onChange((index: number) => this.tab = index)
          .visibility(this.page === 'home' ? Visibility.Visible : Visibility.Hidden)
        if (this.page === 'settings') {
          SettingsView({
            source: this.source,
            onSource: (source: GallerySource) => this.changeSource(source),
            onBusy: (busy: boolean) => this.busy = busy,
            onBack: () => this.page = 'home',
            onSaved: (account: WallhavenCredentials) => {
              this.setAccount(account);
            }
          })
        } else if (this.page === 'preview' && this.selected) {
          PreviewView({ cropFullscreen: this.$cropFullscreen, deviceProfile: this.deviceProfile, onBusy: (busy: boolean) => this.busy = busy, wallpaper: this.selected, onBack: () => {
            this.page = 'home';
            this.selected = undefined;
          } })
        }
      } else {
        Column({ space: 16 }) {
          if (this.errorText.length > 0) {
            Text(this.errorText).fontColor($r('app.color.error'))
            Button('重试').onClick(() => this.initialize())
          } else {
            LoadingProgress().width(36).height(36)
          }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(24)
      }
    }.width('100%').height('100%')
      .backgroundColor($r('app.color.background'))
  }
}
