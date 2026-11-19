@Component
export struct SettingsButton {
  onSettings: () => void = () => {};

  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor([$r('app.color.text')])
        .accessibilityLevel('no')
    }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
      .accessibilityText('设置').onClick(() => this.onSettings())
  }
}

@Component
export struct MainTitle {
  @Require @Prop title: string;
  @Prop showSettings: boolean = true;
  onSettings: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Text(this.title).fontSize(32).fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).accessibilityGroup(true)
      if (this.showSettings) {
        SettingsButton({ onSettings: () => this.onSettings() })
      }
    }.width('100%').height(56).alignItems(VerticalAlign.Center)
  }
}