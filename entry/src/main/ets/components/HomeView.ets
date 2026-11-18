import { BackButton } from './BackButton';
import { Wallpaper, Collection, appendWallpapers, togglePurity, purityLabel } from '../core/Wallpaper';
import { WallhavenService } from '../services/WallhavenService';

@Component
export struct HomeView {
  service: WallhavenService = new WallhavenService();
  @Prop @Watch('onTokenChanged') tokenRevision: number = 0;
  onOpen: (wallpaper: Wallpaper) => void = () => {};
  onSettings: () => void = () => {};
  @State private tab: string = 'discover';
  @State private sorting: string = 'toplist';
  @State private purity: string = '100';
  @State private tokenAvailable: boolean = false;
  @State private query: string = '';
  @State private submittedQuery: string = '';
  @State private wallpapers: Wallpaper[] = [];
  @State private collections: Collection[] = [];
  @State private selectedCollection: Collection | undefined = undefined;
  @State private loading: boolean = false;
  @State private errorText: string = '';
  @State private columns: number = 2;
  @State private cardWidth: number = 203;
  private page: number = 0;
  private lastPage: number = 0;
  private generation: number = 0;
  private initialized: boolean = false;

  aboutToAppear(): void {
    this.initialized = true;
    this.onTokenChanged();
  }

  aboutToDisappear(): void {
    this.generation++;
  }

  private onTokenChanged(): void {
    this.tokenAvailable = this.service.hasToken();
    if (!this.tokenAvailable && this.purity.charAt(2) === '1') {
      const publicPurity = this.purity.slice(0, 2) + '0';
      this.purity = publicPurity === '000' ? '100' : publicPurity;
    }
    if (this.initialized) this.reload();
  }

  private async reload(): Promise<void> {
    const generation = ++this.generation;
    this.loading = true;
    this.errorText = '';
    this.wallpapers = [];
    this.collections = [];
    this.page = 0;
    this.lastPage = 0;
    try {
      if (this.tab === 'collections' && !this.selectedCollection) {
        const collections = await this.service.collections();
        if (generation === this.generation) this.collections = collections;
      } else {
        const result = this.selectedCollection
          ? await this.service.collection(this.selectedCollection.id, 1, this.purity)
          : await this.service.search({ text: this.submittedQuery, sorting: this.sorting, page: 1, purity: this.purity });
        if (generation === this.generation) {
          this.wallpapers = result.data;
          this.page = 1;
          this.lastPage = result.meta.last_page;
        }
      }
    } catch (error) {
      if (generation === this.generation) this.errorText = this.describeError(error as Error);
    } finally {
      if (generation === this.generation) this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.errorText.length > 0 || this.page < 1 || this.page >= this.lastPage) return;
    const generation = this.generation;
    const nextPage = this.page + 1;
    this.loading = true;
    try {
      const result = this.selectedCollection
        ? await this.service.collection(this.selectedCollection.id, nextPage, this.purity)
        : await this.service.search({ text: this.submittedQuery, sorting: this.sorting, page: nextPage, purity: this.purity });
      if (generation === this.generation) {
        this.wallpapers = appendWallpapers(this.wallpapers, result.data);
        this.page = nextPage;
        this.lastPage = result.meta.last_page;
      }
    } catch (error) {
      if (generation === this.generation) this.errorText = this.describeError(error as Error);
    } finally {
      if (generation === this.generation) this.loading = false;
    }
  }

  private describeError(error: Error): string {
    if (error.message && !error.message.startsWith('BusinessError')) return error.message;
    return '网络连接失败，请检查网络后重试';
  }

  private switchTab(tab: string): void {
    if (this.tab === tab && !this.selectedCollection) return;
    this.tab = tab;
    this.selectedCollection = undefined;
    this.reload();
  }

  @Builder
  private tabButton(label: string, tab: string) {
    Button(label, { type: ButtonType.Normal })
      .fontSize(15).fontWeight(this.tab === tab ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.tab === tab ? $r('app.color.text') : $r('app.color.muted'))
      .backgroundColor(this.tab === tab ? $r('app.color.surface') : Color.Transparent)
      .borderRadius(12).height(32).layoutWeight(1)
      .onClick(() => this.switchTab(tab))
  }

  @Builder
  private sortButton(label: string, sorting: string) {
    Button(label, { type: ButtonType.Normal })
      .height(32).fontSize(13).borderRadius(16)
      .backgroundColor(this.sorting === sorting ? $r('app.color.surface') : Color.Transparent)
      .fontColor(this.sorting === sorting ? $r('app.color.accent') : $r('app.color.muted'))
      .fontWeight(this.sorting === sorting ? FontWeight.Bold : FontWeight.Regular)
      .onClick(() => {
        if (this.sorting === sorting) return;
        this.sorting = sorting;
        this.reload();
      })
  }

  @Builder
  private purityButton(label: string, index: number) {
    Button(label, { type: ButtonType.Normal })
      .height(32).fontSize(12).padding({ left: 8, right: 8 }).borderRadius(16)
      .backgroundColor(this.purity.charAt(index) === '1' ? $r('app.color.surface') : Color.Transparent)
      .fontColor(this.purity.charAt(index) === '1' ? $r('app.color.text') : $r('app.color.muted'))
      .fontWeight(this.purity.charAt(index) === '1' ? FontWeight.Bold : FontWeight.Regular)
      .enabled(index !== 2 || this.tokenAvailable)
      .accessibilitySelected(this.purity.charAt(index) === '1')
      .onClick(() => {
        const next = togglePurity(this.purity, index);
        if (next === this.purity) return;
        this.purity = next;
        this.reload();
      })
  }

  @Builder
  private emptyState() {
    Column({ space: 16 }) {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color($r('app.color.accent'))
        Text('加载中').fontSize(14).fontColor($r('app.color.muted'))
      } else if (this.errorText.length > 0) {
        Text(this.errorText).fontSize(15).fontColor($r('app.color.error')).textAlign(TextAlign.Center)
        Button('重试').onClick(() => this.reload())
          .backgroundColor($r('app.color.accent')).fontColor($r('app.color.background'))
      } else if (this.tab === 'collections' && !this.selectedCollection) {
        Text('暂无可访问的收藏集').fontSize(17).fontColor($r('app.color.text'))
        Text('私有收藏集需要填写 Wallhaven API Key')
          .fontSize(14).fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        Button('填写 API Key').onClick(() => this.onSettings())
          .backgroundColor($r('app.color.accent')).fontColor($r('app.color.background'))
      } else {
        Text('暂无壁纸').fontSize(17).fontColor($r('app.color.text'))
      }
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(32)
  }

  @Builder
  private wallpaperGrid() {
    WaterFlow() {
      ForEach(this.wallpapers, (item: Wallpaper) => {
        FlowItem() {
          Column({ space: 6 }) {
            Image(item.thumbs.large).width(this.cardWidth).aspectRatio(1.7)
              .objectFit(ImageFit.Cover).borderRadius(12)
              .backgroundColor($r('app.color.line')).alt('Wallhaven 壁纸 ' + item.id)
            Row() {
              Text(item.resolution).fontSize(11).fontColor($r('app.color.muted'))
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              Text(purityLabel(item.purity)).fontSize(11).fontColor($r('app.color.muted')).margin({ right: 6 })
              Text('#' + item.id).fontSize(11).fontColor($r('app.color.muted'))
            }.width(this.cardWidth).padding({ left: 3, right: 3 })
          }.width(this.cardWidth)
        }.width(this.cardWidth).clip(true).onClick(() => this.onOpen(item))
        .accessibilityText('预览壁纸 ' + item.id + '，' + item.resolution +
          (item.purity === undefined ? '' : '，' + purityLabel(item.purity)))
      }, (item: Wallpaper) => item.id)
    }
    .columnsTemplate('1fr '.repeat(this.columns).trim()).columnsGap(10).rowsGap(14)
    .layoutWeight(1).width('100%').cachedCount(this.columns * 2)
    .scrollBar(BarState.Off).onReachEnd(() => this.loadMore())
    if (this.errorText.length > 0) {
      Row({ space: 12 }) {
        Text(this.errorText).fontSize(13).fontColor($r('app.color.error')).layoutWeight(1)
        Button('重试').fontSize(13).height(34).onClick(() => {
          this.errorText = '';
          this.loadMore();
        }).backgroundColor($r('app.color.surface')).fontColor($r('app.color.accent'))
      }.padding({ top: 10, bottom: 8 })
    } else if (this.loading) {
      LoadingProgress().width(24).height(24).color($r('app.color.accent')).margin({ top: 8 })
    }
  }

  @Builder
  private collectionList() {
    List({ space: 12 }) {
      ForEach(this.collections, (item: Collection) => {
        ListItem() {
          Row({ space: 16 }) {
            Column({ space: 6 }) {
              Text(item.label).fontSize(18).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(item.count + ' 张壁纸').fontSize(13).fontColor($r('app.color.muted'))
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(28).fontColor($r('app.color.accent'))
          }.width('100%').padding(20).borderRadius(20).backgroundColor($r('app.color.surface'))
        }.onClick(() => {
          this.selectedCollection = item;
          this.reload();
        }).accessibilityText('打开收藏集 ' + item.label)
      }, (item: Collection) => item.id.toString())
    }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text('映壁').fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
        Blank()
        Row({ space: 2 }) {
          this.tabButton('发现', 'discover')
          this.tabButton('收藏集', 'collections')
        }.width(168).height(36).padding(2)
          .backgroundColor($r('app.color.line')).borderRadius(14)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22)
            .fontWeight(FontWeight.Normal).fontColor([$r('app.color.accent')]).accessibilityLevel('no')
        }.height(44).width(44).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('设置').id('settingsButton')
          .onClick(() => this.onSettings())
      }.width('100%').height(44)
      if (this.tab === 'discover') {
        Search({ value: this.query, placeholder: '搜索 Wallhaven 壁纸' })
          .height(40).margin(0).backgroundColor($r('app.color.surface')).fontColor($r('app.color.text'))
          .onChange((value: string) => this.query = value)
          .onSubmit(() => {
            this.submittedQuery = this.query.trim();
            this.reload();
          })
        Row({ space: 4 }) {
          this.sortButton('热门', 'toplist')
          this.sortButton('最新', 'date_added')
          Blank()
          this.purityButton('SFW', 0)
          this.purityButton('Sketchy', 1)
          this.purityButton('NSFW', 2)
          Button('刷新').fontSize(13).height(32).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.muted')).onClick(() => this.reload())
        }.width('100%')
      } else if (this.selectedCollection) {
        Row({ space: 8 }) {
          BackButton({ label: '收藏集', onBack: () => {
            this.selectedCollection = undefined;
            this.reload();
          } })

          Text(this.selectedCollection.label).fontSize(15).layoutWeight(1)
            .fontColor($r('app.color.text')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          this.purityButton('SFW', 0)
          this.purityButton('Sketchy', 1)
          this.purityButton('NSFW', 2)
          Button('刷新').height(36).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.muted')).onClick(() => this.reload())
        }.width('100%')
      } else {
        Row() {
          Text('pangdunqing').fontSize(14).fontColor($r('app.color.text')).fontWeight(FontWeight.Medium)
          Blank()
          Button('刷新').height(36).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.muted')).onClick(() => this.reload())
        }.width('100%')
      }
      if (this.wallpapers.length > 0) {
        this.wallpaperGrid()
      } else if (this.collections.length > 0) {
        this.collectionList()
      } else {
        this.emptyState()
      }
    }.width('100%').height('100%').padding({ left: 12, right: 12, top: 4, bottom: 0 })
    .backgroundColor($r('app.color.background'))
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      this.columns = width >= 840 ? 4 : width >= 600 ? 3 : width < 300 ? 1 : 2;
      this.cardWidth = Math.max(1, (width - 24 - (this.columns - 1) * 10) / this.columns);
    })
  }
}

