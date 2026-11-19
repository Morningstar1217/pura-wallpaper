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
          .fontColor([this.selected === index ? $r('app.color.accent') : $r('app.color.text')])
          .scale({ x: this.selected === index ? 1.08 : 1, y: this.selected === index ? 1.08 : 1 })
          .animation({ curve: curves.springMotion(0.32, 0.78) }).accessibilityLevel('no')
        Text(label).fontSize(11).maxLines(1)
          .fontWeight(this.selected === index ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.selected === index ? $r('app.color.accent') : $r('app.color.text'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.height(48).layoutWeight(1).padding(0).borderRadius(24).backgroundColor(Color.Transparent)
      .focusable(!this.hidden && !this.keyboardVisible)
      .accessibilityText(label).accessibilitySelected(this.selected === index).onClick(() => this.onSelect(index))
  }

  @Builder
  private items() {
    if (this.trackWidth > 0) {
      Row().width(this.trackWidth / 3).height(48).borderRadius(24)
        .backgroundColor($r('app.color.nav_selected'))
        .translate({ x: this.selected * this.trackWidth / 3 })
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
        Stack({ alignContent: Alignment.Start }) {
          this.items()
        }.width('100%').height('100%').padding(5).borderRadius(29)
          .systemMaterial(this.material)
      } else {
        Stack() {
          Stack({ alignContent: Alignment.Start }) {
            this.items()
          }.width('100%').height('100%').padding(5).borderRadius(29).clip(true)
            .backgroundColor($r('app.color.nav_glass'))
            .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, { colorMode: ThemeColorMode.SYSTEM })
            .border({ width: 1, color: $r('app.color.nav_rim') })
        }.width('100%').height('100%').borderRadius(29)
          .shadow({ radius: 18, color: '#42000000', offsetX: 0, offsetY: 6 })
      }
    }.width('80%').constraintSize({ maxWidth: 328 }).height(FLOATING_NAV_HEIGHT).borderRadius(29)
      .translate({ y: this.hidden ? FLOATING_NAV_HEIGHT + 24 : 0 }).opacity(this.hidden ? 0 : 1)
      .animation({ duration: 235, curve: Curve.Friction })
      .visibility(this.keyboardVisible ? Visibility.Hidden : Visibility.Visible)
      .accessibilityLevel(this.hidden || this.keyboardVisible ? 'no-hide-descendants' : 'auto')
      .hitTestBehavior(this.hidden || this.keyboardVisible ? HitTestMode.None : HitTestMode.Default)
  }
}