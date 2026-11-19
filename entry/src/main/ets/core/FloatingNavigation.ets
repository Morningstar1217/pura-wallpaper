export const FLOATING_NAV_HEIGHT: number = 58;
export const FLOATING_NAV_BOTTOM_GAP: number = 12;
export const FLOATING_NAV_CONTENT_INSET: number = FLOATING_NAV_HEIGHT + FLOATING_NAV_BOTTOM_GAP + 12;

export class NavigationScroll {
  private anchor: number = 0;
  private tracking: boolean = false;

  start(offset: number): void {
    this.anchor = Math.max(0, offset);
    this.tracking = true;
  }

  stop(): void {
    this.tracking = false;
  }

  update(offset: number, hidden: boolean): boolean {
    if (!this.tracking || !Number.isFinite(offset)) return hidden;
    const top = Math.max(0, offset);
    if (top <= 8) {
      this.anchor = top;
      return false;
    }
    const delta = top - this.anchor;
    if (hidden ? delta > 0 : delta < 0) {
      this.anchor = top;
      return hidden;
    }
    if (hidden ? delta <= -28 : delta >= 48) {
      this.anchor = top;
      return !hidden;
    }
    return hidden;
  }
}