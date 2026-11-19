@Component
export struct MainTitle {
  @Require @Prop title: string;
  onSettings: () => void = () => {};

  build() {
    Row() {
      Text(this.title).fontSize(32).fontWeight(FontWeight.Bold).fontColor($r('app.color.text')).maxLines(1)
        .accessibilityGroup(true)
      Blank()
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.gearshape')).fontSize(24).fontColor([$r('app.color.text')])
          .accessibilityLevel('no')
      }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
        .accessibilityText('设置').onClick(() => this.onSettings())
    }.width('100%').height(56)
  }
}