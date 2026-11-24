import { curves, uiMaterial } from '@kit.ArkUI';
import { FLOATING_NAV_HEIGHT, navigationGlowCenter } from '../core/FloatingNavigation';
import { createNavigationMaterial } from '../services/NavigationMaterial';

@Component
export struct FloatingNav {
  @Prop selected: number = 0;
  @Prop hidden: boolean = false;
  @Prop keyboardVisible: boolean = false;
  onSelect: (index: number) => void = () => {};
  @State private trackWidth: number = 0;
  @State private pressedIndex: number = -1;
  @State private glowX: string = '50%';
  @State private glowY: string = '50%';
  @State private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void {
    this.material = createNavigationMaterial();
  }

  private updateGlow(index: number, event: TouchEvent): void {
    if (event.type === TouchType.Down && event.touches.length > 0) {
      this.glowX = (navigationGlowCenter(event.touches[0].x, this.trackWidth / 3) * 100) + '%';
      this.glowY = (navigationGlowCenter(event.touches[0].y, FLOATING_NAV_HEIGHT - 8) * 100) + '%';
      this.pressedIndex = index;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedIndex = -1;
    }
  }

  @Builder
  private item(index: number, label: string, icon: Resource, activeIcon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Stack() {
        Row().width('100%').height('100%').borderRadius(22)
          .radialGradient({ center: [this.glowX, this.glowY], radius: 30,
            colors: [[$r('app.color.nav_press_light'), 0], [Color.Transparent, 1]] })
          .opacity(this.pressedIndex === index ? 1 : 0)
          .animation({ duration: this.pressedIndex === index ? 85 : 200, curve: Curve.EaseOut })
          .hitTestBehavior(HitTestMode.None)
        Column({ space: 1 }) {
          SymbolGlyph(this.selected === index ? activeIcon : icon).fontSize(20)
            .fontColor([this.selected === index ? $r('app.color.nav_active_text') : $r('app.color.text')])
            .accessibilityLevel('no')
          Text(label).fontSize(11).maxLines(1)
            .fontWeight(this.selected === index ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(this.selected === index ? $r('app.color.nav_active_text') : $r('app.color.text'))
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).hitTestBehavior(HitTestMode.None)
      }.width('100%').height('100%')
    }.height(FLOATING_NAV_HEIGHT - 8).layoutWeight(1).padding(0).borderRadius(22).backgroundColor(Color.Transparent)
      .stateEffect(false).onTouch((event: TouchEvent) => this.updateGlow(index, event))
      .focusable(!this.hidden && !this.keyboardVisible)
      .accessibilityText(label).accessibilitySelected(this.selected === index).onClick(() => this.onSelect(index))
  }

  @Builder
  private items() {
    if (this.trackWidth > 0) {
      Row().width(Math.max(0, this.trackWidth / 3 - 4)).height(FLOATING_NAV_HEIGHT - 10).borderRadius(21)
        .backgroundColor($r('app.color.nav_selected'))
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.nav_selected_light'), 0], [Color.Transparent, 1]] })
        .border({ width: 1, color: $r('app.color.nav_selected_rim') })
        .translate({ x: 2 + this.selected * this.trackWidth / 3 })
        .animation({ curve: curves.springMotion(0.38, 0.82) }).hitTestBehavior(HitTestMode.None)
    }
    Row() {
      this.item(0, '发现', $r('sys.symbol.compass'), $r('sys.symbol.compass'))
      this.item(1, '图库', $r('sys.symbol.picture'), $r('sys.symbol.picture_fill'))
      this.item(2, '我的收藏', $r('sys.symbol.heart'), $r('sys.symbol.heart_fill'))
    }.width('100%').onAreaChange((_old: Area, area: Area) => this.trackWidth = Number(area.width))
  }

  build() {
    Stack() {
      if (this.material) {
        Row().width('100%').height('100%').borderRadius(26)
          .systemMaterial(this.material).hitTestBehavior(HitTestMode.None)
      }
      Row().width('100%').height('100%').borderRadius(26)
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.nav_glass_light'), 0], [$r('app.color.nav_glass'), 0.42],
            [$r('app.color.nav_glass'), 1]] })
        .border({ width: 1, color: $r('app.color.nav_rim') }).hitTestBehavior(HitTestMode.None)
      Stack({ alignContent: Alignment.Start }) {
        this.items()
      }.width('100%').height('100%').padding(4)
    }.width('74%').constraintSize({ maxWidth: 296 }).height(FLOATING_NAV_HEIGHT).borderRadius(26)
      .shadow({ radius: 12, color: $r('app.color.nav_shadow'), offsetX: 0, offsetY: 4 })
      .translate({ y: this.hidden ? FLOATING_NAV_HEIGHT + 24 : 0 }).opacity(this.hidden ? 0 : 1)
      .animation({ duration: 235, curve: Curve.Friction })
      .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
      .accessibilityLevel(this.hidden || this.keyboardVisible ? 'no-hide-descendants' : 'auto')
      .hitTestBehavior(this.hidden || this.keyboardVisible ? HitTestMode.None : HitTestMode.Default)
  }
}