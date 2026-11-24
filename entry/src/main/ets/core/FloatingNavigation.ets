export const FLOATING_NAV_HEIGHT: number = 52;
export const FLOATING_NAV_BOTTOM_GAP: number = 8;
export const FLOATING_NAV_CONTENT_INSET: number = FLOATING_NAV_HEIGHT + FLOATING_NAV_BOTTOM_GAP + 8;

export function navigationGlowCenter(offset: number, size: number): number {
  if (!Number.isFinite(offset) || !Number.isFinite(size) || size <= 0) return 0.5;
  return Math.max(0, Math.min(1, offset / size));
}

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