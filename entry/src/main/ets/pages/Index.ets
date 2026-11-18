import { PreviewView } from '../components/PreviewView';
import { HomeView } from '../components/HomeView';
import { SettingsView } from '../components/SettingsView';
import { Wallpaper, DeviceProfile } from '../core/Wallpaper';
import { WallhavenService } from '../services/WallhavenService';
import { TokenStore } from '../services/TokenStore';
import { getDeviceProfile } from '../services/DeviceProfile';

@Entry
@Component
struct Index {
  @StorageLink('deviceProfile') private deviceProfile: DeviceProfile = { name: '', width: 0, height: 0 };
  @State private ready: boolean = false;
  @State private errorText: string = '';
  @State private page: string = 'home';
  @State private cropFullscreen: boolean = false;
  @State private tokenRevision: number = 0;
  @State private selected: Wallpaper | undefined = undefined;
  private busy: boolean = false;
  private service: WallhavenService = new WallhavenService();

  aboutToAppear(): void { this.initialize(); }

  aboutToDisappear(): void { this.service.cancel(); }

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
    return false;
  }

  private async initialize(): Promise<void> {
    this.errorText = '';
    try {
      AppStorage.setOrCreate('deviceProfile', getDeviceProfile());
      const token = await new TokenStore().read();
      this.service.setToken(token);
      this.ready = true;
    } catch (error) {
      this.errorText = (error as Error).message;
    }
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor($r('app.color.background'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .hitTestBehavior(HitTestMode.None)
      if (this.ready) {
        HomeView({
          service: this.service, tokenRevision: this.tokenRevision,
          onSettings: () => this.page = 'settings',
          onOpen: (item: Wallpaper) => {
            this.selected = item;
            this.page = 'preview';
          }
        }).visibility(this.page === 'home' ? Visibility.Visible : Visibility.Hidden)
        if (this.page === 'settings') {
          SettingsView({
            deviceProfile: this.deviceProfile,
            onBusy: (busy: boolean) => this.busy = busy,
            onBack: () => this.page = 'home',
            onSaved: (token: string) => {
              this.service.setToken(token);
              this.tokenRevision++;
              this.page = 'home';
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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
