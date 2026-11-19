import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Wallpaper, WallpaperSize, DeviceProfile, CropSelection, cropRectangle, clamp, purityLabel } from '../core/Wallpaper';
import { WallhavenService } from '../services/WallhavenService';
import { WallpaperImage, saveToGallery } from '../services/WallpaperImage';
import { BackButton } from './BackButton';

@Component
export struct PreviewView {
  @Require @Prop wallpaper: Wallpaper;
  @Link cropFullscreen: boolean;
  @Require @Prop @Watch('onDeviceProfileChanged') deviceProfile: DeviceProfile;
  onBack: () => void = () => {};
  onBusy: (busy: boolean) => void = () => {};
  @Prop favorite: boolean = false;
  @Prop favoritesAvailable: boolean = false;
  onFavorite: (item: Wallpaper, data?: ArrayBuffer) => void = () => {};
  readLocal: (id: string) => Promise<ArrayBuffer> = async () => new ArrayBuffer(0);
  @State private pixels: image.PixelMap | undefined = undefined;
  @State private loading: boolean = true;
  @State private exporting: boolean = false;
  @State private saving: boolean = false;
  @State private originalView: boolean = false;
  @State private readyToSave: boolean = false;
  @State private errorText: string = '';
  @State private statusText: string = '';
  @State private zoom: number = 1;
  @State private centerX: number = 0.5;
  @State private centerY: number = 0.5;
  @State private frameWidth: number = 240;
  @State private frameHeight: number = 386;
  @State private wide: boolean = false;
  @State private fullscreenWidth: number = 240;
  @State private fullscreenHeight: number = 386;
  @State private fullscreenTopInset: number = 0;
  private session?: WallpaperImage;
  private prepared?: ArrayBuffer;
  private original?: ArrayBuffer;
  private service: WallhavenService = new WallhavenService();
  private active: boolean = false;
  private generation: number = 0;
  private panX: number = 0.5;
  private panY: number = 0.5;
  private pinchZoom: number = 1;
  private previewWidth: number = 0;
  private previewHeight: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.load();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.cropFullscreen = false;
    this.generation++;
    this.service.cancel();
    this.prepared = undefined;
    this.original = undefined;
    this.pixels = undefined;
    if (!this.exporting) this.releaseSession();
  }

  private async releaseSession(): Promise<void> {
    const session = this.session;
    this.session = undefined;
    if (session) {
      try { await session.release(); } catch { console.warn('Image release failed'); }
    }
  }

  private async load(): Promise<void> {
    const generation = ++this.generation;
    this.loading = true;
    this.errorText = '';
    const session = new WallpaperImage();
    try {
      const data = this.favorite ? await this.readLocal(this.wallpaper.id) :
        await this.service.image(this.wallpaper.path, this.wallpaper.fallbackPath);
      if (!this.active || generation !== this.generation) return;
      await session.load(data);
      if (!this.active || generation !== this.generation) {
        await session.release();
        return;
      }
      this.session = session;
      this.original = data;
      this.pixels = session.preview;
    } catch {
      if (this.active && generation === this.generation) {
        this.errorText = '原图加载失败，请检查网络后重试';
      }
    } finally {
      if (this.active && generation === this.generation) this.loading = false;
    }
  }

  private selection(): CropSelection {
    return { zoom: this.zoom, centerX: this.centerX, centerY: this.centerY };
  }

  private imageWidth(width: number = this.frameWidth): number {
    if (!this.session) return width;
    const crop = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
    return this.session.width * width / crop.width;
  }

  private imageHeight(height: number = this.frameHeight): number {
    if (!this.session) return height;
    const crop = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
    return this.session.height * height / crop.height;
  }

  private imageOffsetX(width: number = this.frameWidth): number {
    if (!this.session) return 0;
    const crop = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
    return -crop.x * width / crop.width;
  }

  private imageOffsetY(height: number = this.frameHeight): number {
    if (!this.session) return 0;
    const crop = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
    return -crop.y * height / crop.height;
  }

  private invalidateExport(): void {
    this.readyToSave = false;
    this.prepared = undefined;
    this.errorText = '';
    this.statusText = '';
  }

  private move(event: GestureEvent): void {
    if (!this.session || this.exporting || this.saving) return;
    const crop = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
    const x = this.panX - event.offsetX * crop.width / this.frameWidth / this.session.width;
    const y = this.panY - event.offsetY * crop.height / this.frameHeight / this.session.height;
    this.centerX = clamp(x, crop.width / 2 / this.session.width, 1 - crop.width / 2 / this.session.width);
    this.centerY = clamp(y, crop.height / 2 / this.session.height, 1 - crop.height / 2 / this.session.height);
    this.invalidateExport();
  }

  private async prepare(): Promise<void> {
    if (!this.session || this.exporting || this.saving) return;
    this.exporting = true;
    this.errorText = '';
    this.statusText = '';
    try {
      const target: WallpaperSize = { width: this.deviceProfile.width, height: this.deviceProfile.height };
      const data = await this.session.exportJpeg(this.selection(), target);
      if (this.active && this.deviceProfile.width === target.width && this.deviceProfile.height === target.height) {
        this.prepared = data;
        this.readyToSave = true;
      }
    } catch {
      if (this.active) this.errorText = '生成壁纸失败，请重试';
    } finally {
      this.exporting = false;
      if (!this.active) this.releaseSession();
    }
  }

  private async save(result: SaveButtonOnClickResult): Promise<void> {
    if (result !== SaveButtonOnClickResult.SUCCESS) {
      if (result === SaveButtonOnClickResult.TEMPORARY_AUTHORIZATION_FAILED) {
        this.errorText = '未获得保存授权，请重试';
      }
      return;
    }
    const data = this.prepared;
    if (!data || this.saving) return;
    this.saving = true;
    this.onBusy(true);
    this.errorText = '';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await saveToGallery(context, data, this.wallpaper.id);
      if (this.active) {
        this.statusText = '已保存到图库，可在图库中设为壁纸';
        this.readyToSave = false;
        this.prepared = undefined;
      }
    } catch {
      if (this.active) this.errorText = '保存到图库失败，请重试';
    } finally {
      if (this.active) this.saving = false;
      this.onBusy(false);
    }
  }

  @Builder
  private previewFrame() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.pixels) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.pixels).objectFit(ImageFit.Fill)
            .width(this.imageWidth()).height(this.imageHeight())
            .position({ x: this.imageOffsetX(), y: this.imageOffsetY() })
            .draggable(false).alt(this.deviceProfile.name + ' 壁纸裁剪预览')
        }.width(this.frameWidth).height(this.frameHeight).clip(true).borderRadius(20).id('cropEditorFrame')
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            PinchGesture().onActionStart(() => {
              this.pinchZoom = this.zoom;
            }).onActionUpdate((event: GestureEvent) => {
              if (this.exporting || this.saving) return;
              this.zoom = clamp(this.pinchZoom * event.scale, 1, 3);
              this.invalidateExport();
            }),
            PanGesture().onActionStart(() => {
              if (!this.session) return;
              const rect = cropRectangle(this.session.width, this.session.height, this.selection(), this.deviceProfile);
              this.panX = (rect.x + rect.width / 2) / this.session.width;
              this.panY = (rect.y + rect.height / 2) / this.session.height;
            }).onActionUpdate((event: GestureEvent) => this.move(event)),
            TapGesture().onAction(() => this.showCroppedPreview())
          )
        )
        .bindContentCover($$this.cropFullscreen, this.fullCropPreview(), {
          modalTransition: ModalTransition.ALPHA, backgroundColor: '#000000'
        })
      } else if (this.loading) {
        LoadingProgress().width(40).height(40).color($r('app.color.accent'))
      } else {
        Column({ space: 16 }) {
          Text(this.errorText).fontSize(14).fontColor($r('app.color.error')).textAlign(TextAlign.Center)
          Button('重新加载').backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
            .onClick(() => this.load())
        }.padding(24)
      }
    }.layoutWeight(1).height('100%').width('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.previewWidth = Number(area.width);
      this.previewHeight = Number(area.height);
      this.updateFrameSize();
    })
  }

  private showCroppedPreview(): void {
    if (!this.pixels || !this.session || this.exporting || this.saving) return;
    const context = this.getUIContext();
    try {
      const host = context.getHostContext() as common.UIAbilityContext;
      const area = host.windowStage.getMainWindowSync().getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.fullscreenTopInset = context.px2vp(area.topRect.height);
    } catch {
      console.warn('Full-screen safe area is unavailable');
    }
    this.fullscreenWidth = context.px2vp(this.deviceProfile.width);
    this.fullscreenHeight = context.px2vp(this.deviceProfile.height);
    this.cropFullscreen = true;
  }

  @Builder
  private fullCropPreview() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.pixels) {
          Stack({ alignContent: Alignment.TopStart }) {
            Image(this.pixels).objectFit(ImageFit.Fill)
              .width(this.imageWidth(this.fullscreenWidth)).height(this.imageHeight(this.fullscreenHeight))
              .position({ x: this.imageOffsetX(this.fullscreenWidth), y: this.imageOffsetY(this.fullscreenHeight) })
              .draggable(false).alt(this.deviceProfile.name + ' 全屏裁剪预览')
          }.width(this.fullscreenWidth).height(this.fullscreenHeight).clip(true).id('fullscreenCropFrame')
        }
      }.width(LayoutPolicy.matchParent).height(LayoutPolicy.matchParent).backgroundColor('#000000')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .onAreaChange((_old: Area, area: Area) => {
        const ratio = this.deviceProfile.width / this.deviceProfile.height;
        this.fullscreenWidth = Math.max(1, Math.min(Number(area.width), Number(area.height) * ratio));
        this.fullscreenHeight = this.fullscreenWidth / ratio;
      })
      .onClick(() => this.cropFullscreen = false)
      BackButton({ label: '裁剪预览', foreground: '#FFFFFF', buttonBackground: '#88000000',
        onBack: () => this.cropFullscreen = false }).margin({ top: 16 + this.fullscreenTopInset, left: 16 })
    }.width('100%').height('100%').backgroundColor('#000000')
  }

  private onDeviceProfileChanged(): void {
    this.cropFullscreen = false;
    this.invalidateExport();
    this.updateFrameSize();
  }

  private updateFrameSize(): void {
    if (this.previewWidth <= 0 || this.previewHeight <= 0) return;
    const ratio = this.deviceProfile.width / this.deviceProfile.height;
    this.frameWidth = Math.max(1, Math.min(this.previewWidth, this.previewHeight * ratio));
    this.frameHeight = this.frameWidth / ratio;
  }

  @Builder
  private controls() {
    Column({ space: 14 }) {
      Row() {
        Text(this.deviceProfile.name).fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ right: 12 })
        Text(this.deviceProfile.width + ' × ' + this.deviceProfile.height).fontSize(13).fontColor($r('app.color.muted'))
      }.width('100%')
      Row({ space: 8 }) {
        Button('查看原图').height(36).fontSize(13)
          .backgroundColor($r('app.color.surface')).fontColor($r('app.color.accent'))
          .enabled(this.pixels !== undefined && !this.exporting && !this.saving)
          .onClick(() => this.originalView = true)
        Blank()
        Button('重置').height(36).fontSize(13)
          .backgroundColor(Color.Transparent).fontColor($r('app.color.muted'))
          .enabled(!this.exporting && !this.saving)
          .onClick(() => {
            this.zoom = 1;
            this.centerX = 0.5;
            this.centerY = 0.5;
            this.invalidateExport();
          })
      }.width('100%')
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('缩放').fontSize(13).fontColor($r('app.color.muted'))
          Slider({ value: this.zoom, min: 1, max: 3, step: 0.01 })
            .layoutWeight(1).selectedColor($r('app.color.accent'))
            .enabled(!this.exporting && !this.saving)
            .onChange((value: number) => {
              this.zoom = value;
              this.invalidateExport();
            })
          Text(this.zoom.toFixed(1) + '×').fontSize(13).width(36).fontColor($r('app.color.muted'))
        }.width('100%')
        Text('拖动调整位置，双指缩放').fontSize(12).fontColor($r('app.color.muted'))
          .alignSelf(ItemAlign.Start)
      }
      if (this.statusText.length > 0) {
        Text(this.statusText).fontSize(14).fontColor($r('app.color.accent')).lineHeight(22)
      }
      if (this.errorText.length > 0 && this.pixels) {
        Text(this.errorText).fontSize(14).fontColor($r('app.color.error')).lineHeight(22)
      }
      if (this.readyToSave) {
        SaveButton({ icon: SaveIconStyle.FULL_FILLED, text: SaveDescription.SAVE_IMAGE, buttonType: ButtonType.Capsule })
          .width('100%').height(48).fontSize(16)
          .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
          .enabled(!this.saving).userCancelEvent(true)
          .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => this.save(result))
      } else {
        Button(this.exporting ? '生成中…' : this.saving ? '保存中…' : '生成壁纸')
          .width('100%').height(48).fontSize(16)
          .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
          .enabled(this.pixels !== undefined && !this.exporting && !this.saving)
          .onClick(() => this.prepare())
      }
    }.width('100%').padding(18).borderRadius(24).backgroundColor($r('app.color.surface'))
  }

  build() {
    if (this.originalView && this.pixels) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.pixels).width('100%').height('100%').objectFit(ImageFit.Contain).alt('壁纸原图预览')
        BackButton({ label: '裁剪预览', foreground: '#FFFFFF', buttonBackground: '#88000000',
          onBack: () => this.originalView = false }).margin(16)
      }.width('100%').height('100%').backgroundColor('#111111')
    } else {
      Column({ space: 14 }) {
        Row() {
          BackButton({ isEnabled: !this.saving, onBack: () => this.onBack() })
          Blank()
          Text(purityLabel(this.wallpaper.purity)).fontSize(13).fontColor($r('app.color.muted')).margin({ right: 10 })
          Text(this.session ? this.session.width + 'x' + this.session.height : this.wallpaper.resolution)
            .fontSize(13).fontColor($r('app.color.muted'))
          Text('#' + this.wallpaper.id).fontSize(13).fontColor($r('app.color.muted')).margin({ left: 12 })
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.favorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
              .fontSize(23).fontColor([$r('app.color.accent')]).accessibilityLevel('no')
          }.width(44).height(44).padding(0).margin({ left: 6 }).backgroundColor(Color.Transparent)
            .enabled(this.favoritesAvailable && (this.favorite || this.pixels !== undefined))
            .accessibilityText(this.favorite ? '取消本机收藏' : '收藏到本机')
            .accessibilitySelected(this.favorite)
            .onClick(() => this.onFavorite(this.wallpaper, this.original))
        }.width('100%')
        if (this.wide) {
          Row({ space: 20 }) {
            this.previewFrame()
            Scroll() {
              this.controls()
            }.width(310).height('100%').scrollBar(BarState.Off)
          }.width('100%').layoutWeight(1)
        } else {
          this.previewFrame()
          this.controls()
        }
      }.width('100%').height('100%').padding({ top: 8, left: 20, right: 20, bottom: 12 })
      .backgroundColor($r('app.color.background'))
      .onAreaChange((_old: Area, area: Area) => {
        this.wide = Number(area.width) >= 680 || Number(area.width) > Number(area.height) * 1.1;
      })
    }
  }
}
