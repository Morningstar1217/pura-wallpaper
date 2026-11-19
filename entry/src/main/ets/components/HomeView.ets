import { BackButton } from './BackButton';
import { Wallpaper, WallpaperPage, Collection, appendWallpapers, togglePurity, purityLabel } from '../core/Wallpaper';
import { GALLERY_TOPICS, GalleryTopic } from '../core/Gallery360';
import { WallhavenService } from '../services/WallhavenService';
import { Gallery360Service } from '../services/Gallery360Service';
import { GallerySource, gallerySourceLabel } from '../core/GallerySource';
import { MainTitle } from './MainTitle';

@Component
export struct HomeView {
  service: WallhavenService = new WallhavenService();
  @Prop @Watch('onActivated') active: boolean = false;
  @Prop @Watch('onSourceChanged') source: GallerySource = GallerySource.Gallery360;
  @Prop collectionsMode: boolean = false;
  @Prop @Watch('onAccountChanged') accountRevision: number = 0;
  getUsername: () => string = () => '';
  onOpen: (wallpaper: Wallpaper) => void = () => {};
  onSettings: () => void = () => {};
  @State private topic: string = 'all';
  @State private username: string = '';
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
  private page: number = 0;
  private lastPage: number = 0;
  private generation: number = 0;
  private initialized: boolean = false;
  private needsReload: boolean = true;
  private gallery: Gallery360Service = new Gallery360Service();

  aboutToAppear(): void {
    this.initialized = true;
    this.onAccountChanged();
    this.onActivated();
  }

  aboutToDisappear(): void {
    this.initialized = false;
    this.needsReload = true;
    this.generation++;
    this.gallery.cancel();
    this.service.cancel();
  }

  private onAccountChanged(): void {
    this.tokenAvailable = this.service.hasToken();
    this.username = this.getUsername();
    if (!this.tokenAvailable && this.purity.charAt(2) === '1') {
      const publicPurity = this.purity.slice(0, 2) + '0';
      this.purity = publicPurity === '000' ? '100' : publicPurity;
    }
    this.selectedCollection = undefined;
    if (this.collectionsMode || this.source === GallerySource.Wallhaven) this.invalidate();
  }

  private onSourceChanged(): void {
    if (this.collectionsMode) {
      this.selectedCollection = undefined;
    } else {
      this.query = '';
      this.submittedQuery = '';
    }
    this.invalidate();
  }

  private onActivated(): void {
    if (this.initialized && this.active && this.needsReload) this.reload();
  }

  private invalidate(): void {
    if (!this.initialized) return;
    this.needsReload = true;
    if (!this.active) {
      this.generation++;
      this.gallery.cancel();
      this.service.cancel();
      this.wallpapers = [];
      this.collections = [];
      this.errorText = '';
      this.loading = false;
    }
    this.onActivated();
  }

  private hasCollectionAccount(): boolean {
    return this.source === GallerySource.Wallhaven && this.tokenAvailable && this.username.length > 0;
  }

  private fetchPage(page: number): Promise<WallpaperPage> {
    if (this.selectedCollection) {
      return this.service.collection(this.username, this.selectedCollection.id, page, this.purity);
    }
    if (this.source === GallerySource.Gallery360) return this.gallery.search(this.submittedQuery, this.topic, page);
    return this.service.search({ text: this.submittedQuery, sorting: this.sorting, page: page, purity: this.purity });
  }

  private async reload(): Promise<void> {
    this.needsReload = false;
    const generation = ++this.generation;
    this.gallery.cancel();
    this.service.cancel();
    this.loading = true;
    this.errorText = '';
    this.wallpapers = [];
    this.collections = [];
    this.page = 0;
    this.lastPage = 0;
    try {
      if (this.collectionsMode && !this.selectedCollection) {
        if (!this.hasCollectionAccount()) return;
        const collections = await this.service.collections();
        if (generation === this.generation) this.collections = collections;
      } else {
        const result = await this.fetchPage(1);
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
    if (!this.active || this.needsReload || this.loading || this.errorText.length > 0 || this.page < 1 ||
      this.page >= this.lastPage) return;
    const generation = this.generation;
    const nextPage = this.page + 1;
    this.loading = true;
    try {
      const result = await this.fetchPage(nextPage);
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

  @Builder
  private filterButton(label: string, selected: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .fontSize(13).height(32).padding({ left: 10, right: 10 }).borderRadius(16)
      .backgroundColor(selected ? $r('app.color.accent') : $r('app.color.control_fill'))
      .fontColor(selected ? $r('app.color.on_accent') : $r('app.color.text'))
      .accessibilitySelected(selected).onClick(action)
  }

  private selectTopic(topic: string): void {
    if (this.topic === topic && this.query.length === 0 && this.submittedQuery.length === 0) return;
    this.topic = topic;
    this.query = '';
    this.submittedQuery = '';
    this.reload();
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
          .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
      } else if (this.collectionsMode && !this.selectedCollection) {
        if (this.hasCollectionAccount()) {
          Text('你的 Wallhaven 账户暂无收藏集').fontSize(17).fontColor($r('app.color.text'))
        } else {
          SymbolGlyph($r('sys.symbol.heart')).fontSize(33).fontColor([$r('app.color.accent')])
            .accessibilityLevel('no')
          Text('还未配置我的收藏').fontSize(17).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text('在设置里选择 Wallhaven (CC)，填写自己的账户后即可查看收藏。')
            .fontSize(14).fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
          Button('配置 Wallhaven').onClick(() => this.onSettings())
            .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
        }
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
          Image(item.thumbs.large).width('100%').aspectRatio(0.79)
            .objectFit(ImageFit.Cover).borderRadius(14).backgroundColor($r('app.color.control_fill'))
            .accessibilityLevel('no')
        }.width('100%').clip(true).focusable(true).onClick(() => this.onOpen(item))
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
      MainTitle({ title: this.collectionsMode ? '我的收藏' : '图库', onSettings: () => this.onSettings() })
      if (!this.collectionsMode) {
        Search({ value: this.query, placeholder: '搜索壁纸' })
          .height(44).margin(0).backgroundColor($r('app.color.control_fill')).fontColor($r('app.color.text'))
          .placeholderColor($r('app.color.muted'))
          .onChange((value: string) => {
            this.query = value;
            if (value.length === 0 && this.submittedQuery.length > 0) {
              this.submittedQuery = '';
              this.reload();
            }
          })
          .onSubmit((value: string) => {
            this.submittedQuery = value.trim();
            this.reload();
          })
        Row({ space: 4 }) {
          Text('来源：' + gallerySourceLabel(this.source)).fontSize(13).fontColor($r('app.color.muted'))
          if (this.source === GallerySource.Gallery360 && this.submittedQuery.length > 0) {
            Text('· 全库搜索').fontSize(12).fontColor($r('app.color.muted'))
          }
        }.width('100%').margin({ top: 3, bottom: 2 })
        if (this.source === GallerySource.Gallery360) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(GALLERY_TOPICS, (topic: GalleryTopic) => {
                this.filterButton(topic.label, this.submittedQuery.length === 0 && this.topic === topic.id,
                  () => this.selectTopic(topic.id))
              }, (topic: GalleryTopic) => topic.id)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        } else {
          Scroll() {
            Row({ space: 5 }) {
              this.sortButton('热门', 'toplist')
              this.sortButton('最新', 'date_added')
              this.purityButton('SFW', 0)
              this.purityButton('Sketchy', 1)
              this.purityButton('NSFW', 2)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        }
      } else if (this.selectedCollection) {
        Row({ space: 8 }) {
          BackButton({ label: '我的收藏', onBack: () => {
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
      } else if (this.hasCollectionAccount()) {
        Row() {
          Text('Wallhaven · ' + this.username).fontSize(14).layoutWeight(1).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.text')).fontWeight(FontWeight.Medium)
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
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .backgroundColor($r('app.color.background'))
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      this.columns = width >= 840 ? 4 : width >= 600 ? 3 : width < 300 ? 1 : 2;
    })
  }
}

