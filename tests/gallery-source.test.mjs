import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const sourceUrl = moduleUrl('entry/src/main/ets/core/GallerySource.ets');
const { GallerySource, gallerySourceLabel } = await import(sourceUrl);
let value;
let flushCount = 0;
let flushError = false;
globalThis.__galleryPrefs = {
  async getPreferences(_context, options) {
    assert.equal(options.name, 'wallpaper_settings');
    return {
      async get(key, fallback) {
        assert.equal(key, 'gallery_source');
        return value ?? fallback;
      },
      async put(key, next) {
        assert.equal(key, 'gallery_source');
        value = next;
      },
      async flush() {
        flushCount++;
        if (flushError) throw new Error('storage unavailable');
      }
    };
  }
};
const { GallerySourceStore } = await import(moduleUrl('entry/src/main/ets/services/GallerySourceStore.ets', [
  ['@kit.ArkData', 'data:text/javascript,export const preferences = globalThis.__galleryPrefs'],
  ['../core/GallerySource', sourceUrl]
]));

test('local gallery preferences default to 360, persist CC, and reject an unsupported stored source', async () => {
  const store = new GallerySourceStore();
  assert.equal(await store.read({}), GallerySource.Gallery360);
  assert.equal(gallerySourceLabel(GallerySource.Gallery360), '360 壁纸');
  await store.save({}, GallerySource.Wallhaven);
  assert.equal(flushCount, 1);
  assert.equal(await new GallerySourceStore().read({}), GallerySource.Wallhaven);
  assert.equal(gallerySourceLabel(GallerySource.Wallhaven), 'Wallhaven (CC)');
  value = 'bing';
  assert.equal(await store.read({}), GallerySource.Gallery360);
});

test('a failed write reverts the in-memory Preferences value', async () => {
  const store = new GallerySourceStore();
  value = GallerySource.Wallhaven;
  flushError = true;
  await assert.rejects(store.save({}, GallerySource.Gallery360), /保存图库来源/);
  assert.equal(await store.read({}), GallerySource.Wallhaven);
});