export const FLOATING_NAV_HEIGHT: number = 62;
export const FLOATING_NAV_BOTTOM_GAP: number = 12;
export const FLOATING_NAV_CONTENT_INSET: number = FLOATING_NAV_HEIGHT + FLOATING_NAV_BOTTOM_GAP + 12;

export class NavigationScroll {
  private travel: number = 0;

  reset(): void {
    this.travel = 0;
  }

  // ArkUI reports positive deltas when the content moves up toward later items.
  update(delta: number, hidden: boolean, fromUser: boolean): boolean {
    if (!fromUser || !Number.isFinite(delta)) return hidden;
    if (hidden ? delta > 0 : delta < 0) {
      this.reset();
      return hidden;
    }
    this.travel += delta;
    if (hidden ? this.travel <= -12 : this.travel >= 48) {
      this.reset();
      return !hidden;
    }
    return hidden;
  }
}