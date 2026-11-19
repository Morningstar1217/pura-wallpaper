import test from 'node:test';
import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { moduleUrl } from './source-loader.mjs';

let failManifest = false;
let shortWrite = false;
globalThis.__favoritesFileIo = {
  OpenMode: { CREATE: 1, WRITE_ONLY: 2, TRUNC: 4, READ_ONLY: 0 },
  async access(path) { return fs.access(path).then(() => true, () => false); },
  mkdir: (path, recursive) => fs.mkdir(path, { recursive }), listFile: path => fs.readdir(path),
  readText: path => fs.readFile(path, 'utf8'), stat: path => fs.stat(path),
  async open(path, mode) { return { fd: await fs.open(path, mode ? 'w' : 'r') }; },
  close: file => file.fd.close(), unlink: path => fs.unlink(path),
  async write(fd, data) {
    const { bytesWritten } = await fd.write(Buffer.from(data));
    return shortWrite ? bytesWritten - 1 : bytesWritten;
  },
  async read(fd, data) { return (await fd.read(Buffer.from(data))).bytesRead; },
  async rename(from, to) {
    if (failManifest && to.endsWith('/index.json')) throw new Error('manifest unavailable');
    await fs.rename(from, to);
  }
};
const { FavoritesStore } = await import(moduleUrl('entry/src/main/ets/services/FavoritesStore.ets', [
  ['@kit.CoreFileKit', 'data:text/javascript,export const fileIo = globalThis.__favoritesFileIo'],
  ['@kit.ArkTS', 'data:text/javascript,export const util = { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value) } } }'],
  ['../core/Wallpaper', moduleUrl('entry/src/main/ets/core/Wallpaper.ets')]
]));

const item = id => ({ id, path: 'https://source.example/picture.jpg', thumbs: {}, dimension_x: 2, dimension_y: 2,
  resolution: '2x2', file_type: 'image/jpeg', file_size: 0, title: '壁纸' });
const bytes = Uint8Array.of(23, 56, 78).buffer;
async function sandbox(t) {
  const folder = await fs.mkdtemp(join(tmpdir(), 'pura-favorites-'));
  t.after(() => fs.rm(folder, { recursive: true, force: true }));
  return folder;
}

test('favorites save full bytes, deduplicate, reopen offline and remove independently of source', async t => {
  const directory = await sandbox(t);
  const store = new FavoritesStore();
  assert.deepEqual(await store.open(directory), []);
  await store.add(item('bing-20261119'), bytes);
  await store.add(item('360-11'), bytes);
  await store.add(item('abc123'), bytes);
  assert.equal((await store.add(item('abc123'), bytes)).length, 3);
  const reopened = new FavoritesStore();
  assert.deepEqual((await reopened.open(directory)).map(record => record.id), ['abc123', '360-11', 'bing-20261119']);
  assert.deepEqual(await reopened.readImage('360-11'), bytes);
  assert.equal((await reopened.remove('360-11')).length, 2);
  await assert.rejects(reopened.readImage('360-11'), /ENOENT/);
  await assert.rejects(reopened.readImage('../index.json'), /编号无效/);
});

test('failed local writes preserve the index and do not leave partial favorite images', async t => {
  const directory = await sandbox(t);
  const store = new FavoritesStore();
  await store.open(directory);
  await store.add(item('abc123'), bytes);
  failManifest = true;
  try {
    await assert.rejects(store.add(item('360-11'), bytes), /manifest unavailable/);
    await assert.rejects(store.remove('abc123'), /manifest unavailable/);
  } finally { failManifest = false; }
  shortWrite = true;
  try { await assert.rejects(store.add(item('360-12'), bytes), /写入不完整/); }
  finally { shortWrite = false; }
  assert.deepEqual((await store.open(directory)).map(record => record.id), ['abc123']);
  assert.deepEqual((await fs.readdir(join(directory, 'favorite-wallpapers'))).sort(), ['abc123.img', 'index.json']);
});

test('reopening removes unindexed private cache files after interrupted operations', async t => {
  const directory = await sandbox(t);
  const store = new FavoritesStore();
  await store.open(directory);
  await store.add(item('abc123'), bytes);
  for (const name of ['360-12.img', 'bing-20261118.img.tmp', 'index.json.tmp']) {
    await fs.writeFile(join(directory, 'favorite-wallpapers', name), 'interrupted');
  }
  assert.equal((await store.open(directory)).length, 1);
  assert.deepEqual((await fs.readdir(join(directory, 'favorite-wallpapers'))).sort(), ['abc123.img', 'index.json']);
});