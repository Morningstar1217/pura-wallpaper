import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const token = 'A'.repeat(32);
const empty = { token: '', username: '' };
const username = 'my_wallpapers';
const tag = { ALIAS: 1, SECRET: 2, RETURN_TYPE: 3, ACCESSIBILITY: 4, CONFLICT_RESOLUTION: 5 };
const alias = 'purawallpaper.wallhaven.apikey';
let secret;
globalThis.__wallpaperAsset = {
  Tag: tag, ErrorCode: { NOT_FOUND: 404 }, ReturnType: { ALL: 1 }, Accessibility: { DEVICE_UNLOCKED: 1 },
  ConflictResolution: { OVERWRITE: 1 },
  async query(query) {
    assert.equal(new TextDecoder().decode(query.get(tag.ALIAS)), alias);
    if (!secret) throw { code: 404 };
    return [new Map([[tag.SECRET, secret]])];
  },
  async add(attributes) { secret = attributes.get(tag.SECRET); },
  async remove() { secret = undefined; }
};
const { TokenStore } = await import(moduleUrl('entry/src/main/ets/services/TokenStore.ets', [
  ['@kit.AssetStoreKit', 'data:text/javascript,export const asset = globalThis.__wallpaperAsset'],
  ['@kit.ArkTS', 'data:text/javascript,export const util = { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value) } }, TextDecoder: { create: () => ({ decodeToString: value => new TextDecoder().decode(value) }) } }'],
  ['../core/Wallpaper', moduleUrl('entry/src/main/ets/core/Wallpaper.ets')]
]));

test('upgrading preserves an existing Key without choosing any collection owner', async () => {
  secret = new TextEncoder().encode(token);
  const store = new TokenStore();
  assert.deepEqual(await store.read(), { token, username: '' });
  await store.save({ token, username });
  assert.deepEqual(await store.read(), { token, username });
  await store.save({ token: '', username });
  assert.deepEqual(await store.read(), empty);
});

test('invalid saved account data never falls back to a default username', async () => {
  const store = new TokenStore();
  await assert.rejects(() => store.save({ token, username: 'alice/../bob' }), /用户名/);
  secret = new TextEncoder().encode(JSON.stringify({ token, username: 'alice/../bob' }));
  await assert.rejects(() => store.read(), /安全存储/);
});