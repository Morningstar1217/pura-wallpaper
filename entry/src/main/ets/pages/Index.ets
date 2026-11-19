import { PreviewView } from '../components/PreviewView';
import { HomeView } from '../components/HomeView';
import { SettingsView } from '../components/SettingsView';
import { DailyView } from '../components/DailyView';
import { FloatingNav } from '../components/FloatingNav';
import { FavoritesView } from '../components/FavoritesView';
import { FavoritesStore } from '../services/FavoritesStore';
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { Wallpaper, DeviceProfile } from '../core/Wallpaper';
import { GallerySource } from '../core/GallerySource';
import { GallerySourceStore } from '../services/GallerySourceStore';
import { WallhavenService } from '../services/WallhavenService';
import { TokenStore, WallhavenCredentials } from '../services/TokenStore';
import { getDeviceProfile } from '../services/DeviceProfile';
import { FLOATING_NAV_BOTTOM_GAP } from '../core/FloatingNavigation';

@Entry
@Component
struct Index {
  @StorageLink('deviceProfile') private deviceProfile: DeviceProfile = { name: '', width: 0, height: 0 };
  @StorageLink('keyboardVisible') @Watch('onKeyboardChanged') private keyboardVisible: boolean = false;
  @State private ready: boolean = false;
  @State private errorText: string = '';
  @State private page: string = 'home';
  private returnPage: string = 'home';
  @State private cropFullscreen: boolean = false;
  @State private accountRevision: number = 0;
  @State private selected: Wallpaper | undefined = undefined;
  @State private source: GallerySource = GallerySource.Gallery360;
  @State private tab: number = 0;
  @State private navHidden: boolean = false;
  @State private favorites: Wallpaper[] = [];
  @State private favoritesAvailable: boolean = false;
  @State private favoriteSaving: boolean = false;
  @State private favoritesError: string = '';
  private busy: boolean = false;
  private service: WallhavenService = new WallhavenService();
  private collectionService: WallhavenService = new WallhavenService();
  private favoritesStore: FavoritesStore = new FavoritesStore();
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
    if (this.keyboardVisible) return false;
    if (this.cropFullscreen) {
      this.cropFullscreen = false;
      return true;
    }
    if (this.page !== 'home') {
      this.page = this.page === 'preview' ? this.returnPage : 'home';
      this.selected = undefined;
      return true;
    }
    if (this.tab !== 0) {
      this.changeTab(0);
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
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.restoreFavorites(context.filesDir);
    } catch {
      this.favoritesError = '无法读取本机收藏';
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

  private async restoreFavorites(filesDir: string): Promise<void> {
    try {
      this.favorites = await this.favoritesStore.open(filesDir);
      this.favoritesAvailable = true;
    } catch {
      this.favoritesError = '无法读取本机收藏';
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
    this.navHidden = false;
    this.returnPage = this.page;
    this.selected = item;
    this.page = 'preview';
  }

  private changeTab(index: number): void {
    if (this.tab === index || index < 0 || index > 2) return;
    this.navHidden = false;
    this.tab = index;
  }

  private onKeyboardChanged(): void {
    this.navHidden = false;
  }

  private setNavHidden(index: number, hidden: boolean): void {
    if (this.page === 'home' && this.tab === index && !this.keyboardVisible) this.navHidden = hidden;
  }

  private openSettings(): void {
    this.navHidden = false;
    this.page = 'settings';
  }

  private isFavorite(item: Wallpaper): boolean {
    return this.favorites.some((entry: Wallpaper) => entry.id === item.id);
  }

  private async toggleFavorite(item: Wallpaper, data?: ArrayBuffer): Promise<void> {
    if (this.favoriteSaving) return;
    this.favoriteSaving = true;
    try {
      if (this.isFavorite(item)) this.favorites = await this.favoritesStore.remove(item.id);
      else if (data) this.favorites = await this.favoritesStore.add(item, data);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: (error as Error).message || '无法保存本机收藏' });
    } finally {
      this.favoriteSaving = false;
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor($r('app.color.background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .hitTestBehavior(HitTestMode.None)
      if (this.ready) {
        Stack({ alignContent: Alignment.Bottom }) {
          DailyView({ active: this.tab === 0 && this.page === 'home',
            onSettings: () => this.openSettings(), onGallery: () => this.changeTab(1),
            onOpen: (item: Wallpaper) => this.openWallpaper(item) })
            .align(Alignment.Top).visibility(this.tab === 0 ? Visibility.Visible : Visibility.Hidden)
          HomeView({ active: this.tab === 1 && this.page === 'home', source: this.source,
            navHidden: this.navHidden, keyboardVisible: this.keyboardVisible,
            onNavHidden: (hidden: boolean) => this.setNavHidden(1, hidden),
            service: this.service, accountRevision: this.accountRevision, getUsername: () => this.username,
            onSettings: () => this.openSettings(), onOpen: (item: Wallpaper) => this.openWallpaper(item) })
            .visibility(this.tab === 1 ? Visibility.Visible : Visibility.Hidden)
          FavoritesView({ items: this.favorites, storageError: this.favoritesError,
            active: this.tab === 2 && this.page === 'home', navHidden: this.navHidden,
            keyboardVisible: this.keyboardVisible, onNavHidden: (hidden: boolean) => this.setNavHidden(2, hidden),
            canViewRemote: this.accountRevision > 0 && this.source === GallerySource.Wallhaven &&
              this.collectionService.hasToken() && this.username.length > 0,
            onSettings: () => this.openSettings(), onGallery: () => this.changeTab(1),
            onRemote: () => { this.navHidden = false; this.page = 'remote'; },
            onOpen: (item: Wallpaper) => this.openWallpaper(item),
            localUri: (id: string) => fileUri.getUriFromPath(this.favoritesStore.imagePath(id)) })
            .visibility(this.tab === 2 ? Visibility.Visible : Visibility.Hidden)
          FloatingNav({ selected: this.tab, hidden: this.navHidden, keyboardVisible: this.keyboardVisible,
            onSelect: (index: number) => this.changeTab(index) }).margin({ bottom: FLOATING_NAV_BOTTOM_GAP })
        }.width('100%').height('100%').visibility(this.page === 'home' ? Visibility.Visible : Visibility.Hidden)
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
        } else if (this.page === 'remote' || (this.page === 'preview' && this.returnPage === 'remote')) {
          HomeView({ active: this.page === 'remote', source: this.source, collectionsMode: true,
            service: this.collectionService, accountRevision: this.accountRevision, getUsername: () => this.username,
            onBack: () => this.page = 'home', onSettings: () => this.page = 'settings',
            onOpen: (item: Wallpaper) => this.openWallpaper(item) })
            .visibility(this.page === 'remote' ? Visibility.Visible : Visibility.Hidden)
        }
        if (this.page === 'preview' && this.selected) {
          PreviewView({ cropFullscreen: this.$cropFullscreen, deviceProfile: this.deviceProfile,
            onBusy: (busy: boolean) => this.busy = busy, wallpaper: this.selected,
            favorite: this.isFavorite(this.selected), favoritesAvailable: this.favoritesAvailable && !this.favoriteSaving,
            readLocal: (id: string) => this.favoritesStore.readImage(id),
            onFavorite: (item: Wallpaper, data?: ArrayBuffer) => { this.toggleFavorite(item, data); }, onBack: () => {
            this.page = this.returnPage;
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
