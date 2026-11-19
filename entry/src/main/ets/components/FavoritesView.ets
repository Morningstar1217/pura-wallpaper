import { Wallpaper } from '../core/Wallpaper';
import { MainTitle } from './MainTitle';
import { FLOATING_NAV_CONTENT_INSET, NavigationScroll } from '../core/FloatingNavigation';

@Component
export struct FavoritesView {
  @Prop items: Wallpaper[] = [];
  @Prop canViewRemote: boolean = false;
  @Prop storageError: string = '';
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop navHidden: boolean = false;
  @Prop keyboardVisible: boolean = false;
  onNavHidden: (hidden: boolean) => void = () => {};
  onSettings: () => void = () => {};
  onGallery: () => void = () => {};
  onRemote: () => void = () => {};
  onOpen: (item: Wallpaper) => void = () => {};
  localUri: (id: string) => string = () => '';
  @State private columns: number = 2;
  private gridScroller: Scroller = new Scroller();
  private navScroll: NavigationScroll = new NavigationScroll();

  private onActiveChanged(): void {
    if (!this.active) this.navScroll.stop();
  }

  private updateNavigation(): void {
    if (!this.active || this.keyboardVisible) return;
    const next = this.navScroll.update(this.gridScroller.currentOffset().yOffset, this.navHidden);
    if (next !== this.navHidden) this.onNavHidden(next);
  }

  build() {
    Column({ space: 10 }) {
      MainTitle({ title: '我的收藏', onSettings: () => this.onSettings() })
      if (this.canViewRemote) {
        Row() {
          Text('本机收藏 · ' + this.items.length).fontSize(13).fontColor($r('app.color.muted'))
          Blank()
          Button('Wallhaven 收藏集').height(40).fontColor($r('app.color.accent'))
            .backgroundColor($r('app.color.control_fill')).onClick(() => this.onRemote())
        }.width('100%')
      }
      if (this.items.length > 0) {
        WaterFlow({ scroller: this.gridScroller }) {
          ForEach(this.items, (item: Wallpaper) => {
            FlowItem() {
              Image(this.localUri(item.id)).width('100%').aspectRatio(0.79).objectFit(ImageFit.Cover)
                .borderRadius(14).backgroundColor($r('app.color.control_fill')).accessibilityLevel('no')
            }.width('100%').focusable(true).accessibilityText('预览收藏壁纸 ' + (item.title ?? item.id))
              .onClick(() => this.onOpen(item))
          }, (item: Wallpaper) => item.id)
        }.width('100%').layoutWeight(1).contentEndOffset(FLOATING_NAV_CONTENT_INSET).columnsGap(10).rowsGap(10)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) this.navScroll.start(this.gridScroller.currentOffset().yOffset);
            else if (event.type === TouchType.Cancel) this.navScroll.stop();
          })
          .onDidScroll(() => this.updateNavigation()).onScrollStop(() => this.navScroll.stop())
          .onReachEnd(() => this.onNavHidden(false))
          .columnsTemplate('1fr '.repeat(this.columns).trim()).scrollBar(BarState.Off)
      } else {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.heart')).fontSize(38).fontColor([$r('app.color.accent')])
            .accessibilityLevel('no')
          Text(this.storageError || '还没有本机收藏').fontSize(18).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text')).textAlign(TextAlign.Center)
          Text('打开任意壁纸，点爱心即可收藏。收藏的图片保存在本机，离线也能打开。')
            .fontSize(14).fontColor($r('app.color.muted')).textAlign(TextAlign.Center).lineHeight(22)
          Button('浏览图库').height(44).backgroundColor($r('app.color.accent'))
            .fontColor($r('app.color.on_accent')).onClick(() => this.onGallery())
        }.width('100%').layoutWeight(1).padding({ left: 20, right: 20, bottom: FLOATING_NAV_CONTENT_INSET })
          .justifyContent(FlexAlign.Center)
      }
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 4 })
      .onAreaChange((_old: Area, area: Area) => {
        const width = Number(area.width);
        this.columns = width >= 840 ? 4 : width >= 600 ? 3 : width < 300 ? 1 : 2;
      })
  }
}