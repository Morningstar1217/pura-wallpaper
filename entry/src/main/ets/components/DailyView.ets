import { Wallpaper } from '../core/Wallpaper';
import { BingDailyService } from '../services/BingDailyService';
import { MainTitle } from './MainTitle';

@Component
export struct DailyView {
  @Prop @Watch('refreshIfActive') active: boolean = false;
  @StorageLink('foregroundRevision') @Watch('refreshIfActive') private foregroundRevision: number = 0;
  onSettings: () => void = () => {};
  onGallery: () => void = () => {};
  onOpen: (item: Wallpaper) => void = () => {};
  @State private daily?: Wallpaper = undefined;
  @State private loading: boolean = false;
  @State private failed: boolean = false;
  @State private imageIndex: number = 0;
  @State private imageReady: boolean = false;
  @State private imageFailed: boolean = false;
  private service: BingDailyService = new BingDailyService();
  private lastChecked: number = 0;
  private generation: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.refreshIfActive();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
    this.service.cancel();
    this.loading = false;
  }

  private refreshIfActive(): void {
    if (!this.mounted || !this.active || this.loading) return;
    if (!this.daily || Date.now() - this.lastChecked >= 15 * 60 * 1000) this.load();
  }

  private async load(): Promise<void> {
    if (this.loading) return;
    const generation = ++this.generation;
    this.loading = true;
    this.failed = false;
    try {
      const daily = await this.service.load();
      if (generation !== this.generation) return;
      this.lastChecked = Date.now();
      if (this.daily?.path !== daily.path || this.imageFailed) {
        this.imageIndex = 0;
        this.imageReady = false;
        this.imageFailed = false;
        this.daily = daily;
      }
    } catch {
      if (generation === this.generation && !this.daily) this.failed = true;
    } finally {
      if (generation === this.generation) this.loading = false;
    }
  }

  private openDaily(): void {
    if (this.daily && this.imageReady) this.onOpen(this.daily);
  }

  @Builder
  private dailyCard(item: Wallpaper) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.imageIndex === 0 ? item.path : item.fallbackPath)
        .width('100%').height('100%').objectFit(ImageFit.Cover).accessibilityLevel('no')
        .onComplete((event) => {
          if (event?.loadingStatus === 1) this.imageReady = true;
        })
        .onError(() => {
          this.imageReady = false;
          if (this.imageIndex === 0 && item.fallbackPath) this.imageIndex = 1;
          else this.imageFailed = true;
        })
      Column({ space: 5 }) {
        Text(item.title ?? '必应每日壁纸').fontSize(25).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('必应每日壁纸').fontSize(14).fontColor('#F5F5F5')
        if (item.attribution) {
          Text(item.attribution).fontSize(12).fontColor('#EEEEEE').maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 18, right: 18, top: 36, bottom: 17 })
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[Color.Transparent, 0], ['#D9000000', 1]] })
      if (!this.imageReady) {
        Column() {
          LoadingProgress().width(32).height(32).color(Color.White)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }
    }.width('100%').layoutWeight(1).borderRadius(20).clip(true).backgroundColor('#354C55')
      .accessibilityGroup(true).accessibilityText('预览每日推荐：' + (item.title ?? '必应每日壁纸'))
      .focusable(this.imageReady).onClick(() => this.openDaily())
  }

  build() {
    Column({ space: 12 }) {
      MainTitle({ title: '映壁', onSettings: () => this.onSettings() })
      Text('每日推荐').width('100%').fontSize(21).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
      if (this.daily && !this.imageFailed) {
        this.dailyCard(this.daily)
      } else {
        Column({ space: 12 }) {
          if (this.loading || (!this.failed && !this.imageFailed)) {
            LoadingProgress().width(32).height(32).color($r('app.color.accent'))
            Text('正在加载每日壁纸').fontSize(14).fontColor($r('app.color.muted'))
          } else {
            SymbolGlyph($r('sys.symbol.picture')).fontSize(30).fontColor([$r('app.color.muted')])
              .accessibilityLevel('no')
            Text('每日推荐暂不可用').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
            Button('重试').height(44).backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
              .onClick(() => this.load())
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(14)
          .borderRadius(20).backgroundColor($r('app.color.control_fill'))
      }
      Button({ type: ButtonType.Normal }) {
        Row() {
          Text('浏览壁纸库').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_forward')).fontSize(17).fontColor([$r('app.color.muted')])
            .accessibilityLevel('no')
        }.width('100%')
      }.width('100%').height(46).padding({ left: 16, right: 16 }).borderRadius(14)
        .backgroundColor($r('app.color.control_fill')).onClick(() => this.onGallery())
    }.width('100%').height('100%').constraintSize({ maxWidth: 600 })
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })
  }
}