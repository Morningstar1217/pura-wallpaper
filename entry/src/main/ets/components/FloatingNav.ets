import { curves, uiMaterial } from '@kit.ArkUI';
import { FLOATING_NAV_HEIGHT } from '../core/FloatingNavigation';
import { createNavigationMaterial } from '../services/NavigationMaterial';

@Component
export struct FloatingNav {
  @Prop selected: number = 0;
  @Prop hidden: boolean = false;
  @Prop keyboardVisible: boolean = false;
  onSelect: (index: number) => void = () => {};
  @State private trackWidth: number = 0;
  @State private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void {
    this.material = createNavigationMaterial();
  }

  @Builder
  private item(index: number, label: string, icon: Resource, activeIcon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 2 }) {
        SymbolGlyph(this.selected === index ? activeIcon : icon).fontSize(22)
          .fontColor([this.selected === index ? $r('app.color.nav_active_text') : $r('app.color.text')])
          .scale({ x: this.selected === index ? 1.08 : 1, y: this.selected === index ? 1.08 : 1 })
          .animation({ curve: curves.springMotion(0.32, 0.78) }).accessibilityLevel('no')
        Text(label).fontSize(12).maxLines(1)
          .fontWeight(this.selected === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selected === index ? $r('app.color.nav_active_text') : $r('app.color.text'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.height(FLOATING_NAV_HEIGHT - 10).layoutWeight(1).padding(0).borderRadius(24).backgroundColor(Color.Transparent)
      .stateStyles({
        normal: { .backgroundColor(Color.Transparent) },
        pressed: { .backgroundColor($r('app.color.nav_press_light')) }
      })
      .focusable(!this.hidden && !this.keyboardVisible)
      .accessibilityText(label).accessibilitySelected(this.selected === index).onClick(() => this.onSelect(index))
  }

  @Builder
  private items() {
    if (this.trackWidth > 0) {
      Row().width(Math.max(0, this.trackWidth / 3 - 4)).height(FLOATING_NAV_HEIGHT - 12).borderRadius(24)
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
        Row().width('100%').height('100%').borderRadius(31)
          .systemMaterial(this.material).hitTestBehavior(HitTestMode.None)
      }
      Row().width('100%').height('100%').borderRadius(31)
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.nav_glass_light'), 0], [$r('app.color.nav_glass'), 0.42],
            [$r('app.color.nav_glass'), 1]] })
        .border({ width: 1, color: $r('app.color.nav_rim') }).hitTestBehavior(HitTestMode.None)
      Stack({ alignContent: Alignment.Start }) {
        this.items()
      }.width('100%').height('100%').padding(5)
    }.width('86%').constraintSize({ maxWidth: 360 }).height(FLOATING_NAV_HEIGHT).borderRadius(31)
      .shadow({ radius: 18, color: $r('app.color.nav_shadow'), offsetX: 0, offsetY: 6 })
      .translate({ y: this.hidden ? FLOATING_NAV_HEIGHT + 24 : 0 }).opacity(this.hidden ? 0 : 1)
      .animation({ duration: 235, curve: Curve.Friction })
      .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
      .accessibilityLevel(this.hidden || this.keyboardVisible ? 'no-hide-descendants' : 'auto')
      .hitTestBehavior(this.hidden || this.keyboardVisible ? HitTestMode.None : HitTestMode.Default)
  }
}