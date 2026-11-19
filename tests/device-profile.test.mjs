import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

globalThis.__wallpaperDeviceInfo = { marketName: 'Pura X', productModel: 'VDE-AL00' };
globalThis.__wallpaperPhysicalDisplay = { width: 1320, height: 2120 };
const { getDeviceProfile } = await import(moduleUrl('entry/src/main/ets/services/DeviceProfile.ets', [
  ['@kit.BasicServicesKit', 'data:text/javascript,export const deviceInfo = globalThis.__wallpaperDeviceInfo'],
  ['@kit.ArkUI', 'data:text/javascript,export const display = {getDefaultDisplaySync(){return globalThis.__wallpaperPhysicalDisplay}}']
]));

test('device profile uses the system marketing name and physical pixels', () => {
  assert.deepEqual(getDeviceProfile(), { name: 'Pura X', width: 1320, height: 2120 });
  globalThis.__wallpaperDeviceInfo.marketName = '  Other phone  ';
  globalThis.__wallpaperPhysicalDisplay = { width: 1179, height: 2556 };
  assert.deepEqual(getDeviceProfile(), { name: 'Other phone', width: 1179, height: 2556 });
});

test('missing marketing name falls back to product model and follows changed screen dimensions', () => {
  globalThis.__wallpaperDeviceInfo.marketName = ' ';
  globalThis.__wallpaperPhysicalDisplay = { width: 2120, height: 1320 };
  assert.deepEqual(getDeviceProfile(), { name: 'VDE-AL00', width: 2120, height: 1320 });
});

test('only the leading Huawei brand is omitted and the full model remains', () => {
  globalThis.__wallpaperPhysicalDisplay = { width: 1276, height: 2848 };
  for (const name of ['HUAWEI Pura 80 Ultra', '  hUaWeI\tPura 80 Ultra  ', '华为Pura 80 Ultra']) {
    globalThis.__wallpaperDeviceInfo.marketName = name;
    assert.deepEqual(getDeviceProfile(), { name: 'Pura 80 Ultra', width: 1276, height: 2848 });
  }
  globalThis.__wallpaperDeviceInfo.marketName = 'HUAWEI';
  assert.equal(getDeviceProfile().name, 'VDE-AL00');
  globalThis.__wallpaperDeviceInfo.marketName = 'Test HUAWEI Edition';
  assert.equal(getDeviceProfile().name, 'Test HUAWEI Edition');
});

test('invalid physical display sizes cannot become wallpaper targets', () => {
  for (const size of [{ width: 0, height: 100 }, { width: 100, height: -1 }, { width: NaN, height: 100 }, { width: 100, height: 2.5 }]) {
    globalThis.__wallpaperPhysicalDisplay = size;
    assert.throws(getDeviceProfile, /图片尺寸/);
  }
});
