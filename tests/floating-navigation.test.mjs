import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const { NavigationScroll, FLOATING_NAV_HEIGHT, FLOATING_NAV_BOTTOM_GAP, FLOATING_NAV_CONTENT_INSET } =
  await import(moduleUrl('entry/src/main/ets/core/FloatingNavigation.ets'));

test('floating navigation hides while scrolling deeper, then reappears sooner on reversal', () => {
  const motion = new NavigationScroll();
  motion.start(0);
  assert.equal(motion.update(20, false), false);
  assert.equal(motion.update(47, false), false);
  assert.equal(motion.update(48, false), true);
  assert.equal(motion.update(155, true), true);
  assert.equal(motion.update(128, true), true);
  assert.equal(motion.update(127, true), false);
  assert.equal(motion.update(174, false), false);
  assert.equal(motion.update(175, false), true);
});

test('programmatic scrolls do not toggle the bar; reaching the top during a gesture reveals it', () => {
  const motion = new NavigationScroll();
  assert.equal(motion.update(150, false), false);
  motion.start(190);
  assert.equal(motion.update(8, true), false);
  assert.equal(motion.update(Number.NaN, false), false);
  motion.stop();
  assert.equal(motion.update(200, false), false);
  motion.start(100);
  assert.equal(motion.update(147, false), false);
  assert.equal(motion.update(149, false), true);
});

test('scrollable pages reserve enough end space to clear the floating capsule', () => {
  assert.ok(FLOATING_NAV_CONTENT_INSET > FLOATING_NAV_HEIGHT + FLOATING_NAV_BOTTOM_GAP);
});