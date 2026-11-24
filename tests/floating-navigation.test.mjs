import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { moduleUrl } from './source-loader.mjs';

const { NavigationScroll, navigationGlowCenter, FLOATING_NAV_HEIGHT, FLOATING_NAV_BOTTOM_GAP, FLOATING_NAV_CONTENT_INSET } =
  await import(moduleUrl('entry/src/main/ets/core/FloatingNavigation.ets'));

test('floating navigation hides while scrolling deeper, then reappears sooner on reversal', () => {
  const motion = new NavigationScroll();
  assert.equal(motion.update(20, false, true), false);
  assert.equal(motion.update(27, false, true), false);
  assert.equal(motion.update(1, false, true), true);
  assert.equal(motion.update(107, true, true), true);
  assert.equal(motion.update(-7, true, true), true);
  assert.equal(motion.update(-5, true, true), false);
});

test('a new reverse drag reveals the bar after momentum without relying on raw touch events', () => {
  const motion = new NavigationScroll();
  assert.equal(motion.update(53, false, true), true);
  motion.reset();
  assert.equal(motion.update(180, true, false), true);
  assert.equal(motion.update(-90, true, false), true);
  assert.equal(motion.update(-12, true, true), false);
});

test('reversals discard jitter and invalid or programmatic deltas do not count', () => {
  const motion = new NavigationScroll();
  assert.equal(motion.update(100, false, false), false);
  assert.equal(motion.update(Number.NaN, false, true), false);
  assert.equal(motion.update(47, false, true), false);
  assert.equal(motion.update(-1, false, true), false);
  assert.equal(motion.update(1, false, true), false);
  motion.reset();
  assert.equal(motion.update(-11, true, true), true);
  assert.equal(motion.update(1, true, true), true);
  assert.equal(motion.update(-1, true, true), true);
});

test('scrollable pages reserve enough end space to clear the floating capsule', () => {
  assert.ok(FLOATING_NAV_CONTENT_INSET > FLOATING_NAV_HEIGHT + FLOATING_NAV_BOTTOM_GAP);
});

test('touch glow follows a local touch point and clamps edge cases', () => {
  assert.equal(navigationGlowCenter(20, 80), 0.25);
  assert.equal(navigationGlowCenter(33, 44), 0.75);
  assert.equal(navigationGlowCenter(-1, 44), 0);
  assert.equal(navigationGlowCenter(101, 80), 1);
  assert.equal(navigationGlowCenter(10, 0), 0.5);
  assert.equal(navigationGlowCenter(NaN, 44), 0.5);
});

function rgb(hex) {
  return [0, 2, 4].map(index => parseInt(hex.slice(-6).slice(index, index + 2), 16));
}

function blend(hex, background) {
  const alpha = hex.length === 9 ? parseInt(hex.slice(1, 3), 16) / 255 : 1;
  return rgb(hex).map((value, index) => value * alpha + background[index] * (1 - alpha));
}

function luminance(channels) {
  return channels.reduce((sum, channel, index) => {
    const value = channel / 255;
    const linear = value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    return sum + [0.2126, 0.7152, 0.0722][index] * linear;
  }, 0);
}

test('both navigation palettes keep normal and selected labels readable over extreme wallpaper colors', () => {
  for (const theme of ['base', 'dark']) {
    const file = new URL(`../entry/src/main/resources/${theme}/element/color.json`, import.meta.url);
    const colors = Object.fromEntries(JSON.parse(readFileSync(file, 'utf8')).color.map(item => [item.name, item.value]));
    const container = ['nav_glass_light', 'nav_glass'].flatMap(key =>
      [[0, 0, 0], [255, 255, 255]].map(background => blend(colors[key], background)));
    const selected = [rgb(colors.nav_selected), blend(colors.nav_selected_light, rgb(colors.nav_selected))];
    for (const [label, backgrounds] of [[colors.text, container], [colors.nav_active_text, selected]]) {
      for (const background of backgrounds) {
        for (const fill of [background, blend(colors.nav_press_light, background)]) {
          const foregroundLight = luminance(rgb(label));
          const backgroundLight = luminance(fill);
          const ratio = (Math.max(foregroundLight, backgroundLight) + 0.05) /
            (Math.min(foregroundLight, backgroundLight) + 0.05);
          assert.ok(ratio >= 4.5, `${theme}: contrast ${ratio.toFixed(2)} is below 4.5`);
        }
      }
    }
  }
});