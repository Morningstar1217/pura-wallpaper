import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const { NavigationScroll, FLOATING_NAV_HEIGHT, FLOATING_NAV_BOTTOM_GAP, FLOATING_NAV_CONTENT_INSET } =
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