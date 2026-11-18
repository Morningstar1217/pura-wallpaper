@Component
export struct BackButton {
  @Prop label: string = '返回';
  @Prop isEnabled: boolean = true;
  @Prop foreground: ResourceColor = $r('app.color.accent');
  @Prop buttonBackground: ResourceColor = Color.Transparent;
  onBack: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.chevron_backward')).fontSize(20)
          .fontWeight(FontWeight.Medium).fontColor([this.foreground]).accessibilityLevel('no')
        Text(this.label).fontSize(15).fontColor(this.foreground)
      }.justifyContent(FlexAlign.Center)
    }.height(44).padding({ left: 10, right: 12 }).borderRadius(22)
      .backgroundColor(this.buttonBackground).enabled(this.isEnabled)
      .accessibilityText(this.label).onClick(() => this.onBack())
  }
}
