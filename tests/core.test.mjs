import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const coreUrl = moduleUrl('entry/src/main/ets/core/Wallpaper.ets');
const core = await import(coreUrl);
const wallpaper = {
  id: 'abc123', path: 'https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg',
  thumbs: { large: 'https://th.wallhaven.cc/lg/ab/abc123.jpg', original: '', small: '' },
  dimension_x: 3840, dimension_y: 2160, resolution: '3840x2160',
  file_size: 12000, file_type: 'image/jpeg'
};

test('search percent-encodes keywords and keeps SFW discovery explicit', () => {
  const path = core.searchPath({ text: '  山 & sky/#?  ', sorting: 'toplist', page: 2 });
  assert.equal(path, '/search?purity=100&categories=111&order=desc&sorting=toplist&page=2&topRange=1M&q=' + encodeURIComponent('山 & sky/#?'));
});
test('latest sorting omits toplist-only options', () => {
  assert.equal(core.searchPath({ text: '', sorting: 'date_added', page: 1 }), '/search?purity=100&categories=111&order=desc&sorting=date_added&page=1');
});
test('Wallhaven categories use General, Anime and People bit order independently of purity', () => {
  const all = core.ALL_WALLHAVEN_CATEGORIES;
  assert.equal(all, '111');
  for (const [index, mask] of [[0, '011'], [1, '101'], [2, '110']]) {
    assert.equal(core.toggleCategory(all, index), mask);
    assert.equal(core.toggleCategory(mask, index), all);
  }
  assert.equal(core.toggleCategory('010', 1), '010');
  assert.equal(core.toggleCategory('010', 2), '011');
  const path = core.searchPath({ text: 'night sky', sorting: 'date_added', page: 3, purity: '110', categories: '001' });
  assert.equal(path, '/search?purity=110&categories=001&order=desc&sorting=date_added&page=3&q=night%20sky');
  for (const categories of ['000', '1', '1110', '1a1', '111&purity=111']) {
    assert.throws(() => core.searchPath({ text: '', sorting: 'toplist', page: 1, categories }), /分类参数无效/);
  }
  assert.throws(() => core.toggleCategory(all, 3), /分类参数无效/);
});
test('collection details require an explicit safe username and valid ID', () => {
  assert.equal(core.collectionPath('my_wallpapers', 123, 2), '/collections/my_wallpapers/123?page=2');
  for (const id of [0, -1, 1.5, NaN]) assert.throws(() => core.collectionPath('alice', id));
  for (const name of ['', '../alice', 'alice/bob', 'alice?x=1', 'alice%2fbob']) {
    assert.throws(() => core.collectionPath(name, 123));
  }
});
test('image origin allowlist rejects credentials, subdomain tricks and HTTP', () => {
  assert.equal(core.isOfficialImage(wallpaper.path), true);
  for (const url of [
    'http://w.wallhaven.cc/full/a.jpg', 'https://w.wallhaven.cc.evil.test/a.jpg',
    'https://w.wallhaven.cc@evil.test/a.jpg', 'https://evil.test/a.jpg',
    'https://w.wallhaven.cc/a.jpg?apikey=secret', 'file:///data/a.jpg'
  ]) assert.equal(core.isOfficialImage(url), false, url);
});
test('pagination validates the requested page before it can update state', () => {
  const page = { data: [wallpaper], meta: { current_page: 1, last_page: 2, total: 30 } };
  assert.equal(core.validatePage(page, 1), page);
  assert.throws(() => core.validatePage(page, 2));
  assert.throws(() => core.validatePage({ data: [], meta: { current_page: 1, last_page: -1, total: 0 } }, 1));
  assert.doesNotThrow(() => core.validatePage({ data: [], meta: { current_page: 1, last_page: 0, total: 0 } }, 1));
});
test('malformed images and collection results are rejected', () => {
  for (const patch of [{ path: 'https://example.com/a.jpg' }, { dimension_x: 0 }, { thumbs: null }, { id: '../abc' }]) {
    assert.throws(() => core.validatePage({ data: [{ ...wallpaper, ...patch }], meta: { current_page: 1, last_page: 1, total: 1 } }, 1));
  }
  assert.deepEqual(core.validateCollections({ data: [] }), []);
  assert.throws(() => core.validateCollections({ data: [{ id: 1, label: 'a', count: -1 }] }));
});
test('pagination deduplicates across and within batches without mutation', () => {
  const old = [wallpaper];
  const next = { ...wallpaper, id: 'def456' };
  const result = core.appendWallpapers(old, [wallpaper, next, next]);
  assert.deepEqual(result.map(item => item.id), ['abc123', 'def456']);
  assert.equal(old.length, 1);
});
test('Pura X full-frame crop keeps 1320x2120 pixels exactly', () => {
  assert.deepEqual(core.cropRectangle(1320, 2120, { zoom: 1, centerX: 0.5, centerY: 0.5 }), {
    x: 0, y: 0, width: 1320, height: 2120
  });
});
test('landscape is center-cropped and never stretched', () => {
  assert.deepEqual(core.cropRectangle(3840, 2160, { zoom: 1, centerX: 0.5, centerY: 0.5 }), {
    x: 1260, y: 20, width: 1320, height: 2120
  });
});
test('all sampled crops stay inside source bounds at the exact target aspect ratio', () => {
  let count = 0;
  for (const [width, height] of [[1320, 2120], [3840, 2160], [1080, 2400], [7680, 4320], [100, 100], [33, 53]]) {
    for (const zoom of [0.1, 1, 1.2, 2, 3, 20]) {
      for (const centerX of [-1, 0, 0.2, 0.5, 1, 2]) {
        for (const centerY of [-1, 0, 0.5, 1, 2]) {
          const rect = core.cropRectangle(width, height, { zoom, centerX, centerY });
          assert.ok(rect.x >= 0 && rect.y >= 0);
          assert.ok(rect.x + rect.width <= width && rect.y + rect.height <= height);
          assert.equal(rect.width * 53, rect.height * 33);
          for (const value of Object.values(rect)) assert.ok(Number.isInteger(value));
          count++;
        }
      }
    }
  }
  assert.equal(count, 1080);
});
test('invalid crop values cannot reach the native decoder', () => {
  for (const [width, height, selection] of [
    [0, 2120, { zoom: 1, centerX: 0.5, centerY: 0.5 }],
    [1320, Infinity, { zoom: 1, centerX: 0.5, centerY: 0.5 }],
    [1320, 2120, { zoom: NaN, centerX: 0.5, centerY: 0.5 }]
  ]) assert.throws(() => core.cropRectangle(width, height, selection));
});

let calls = [];
let pending = [];
globalThis.__wallpaperHttp = {
  RequestMethod: { GET: 1 }, HttpDataType: { STRING: 0, ARRAY_BUFFER: 1 },
  createHttp() {
    const call = { destroyed: false, destroyCount: 0 };
    calls.push(call);
    return {
      async request(url, options) {
        Object.assign(call, { url, options });
        const result = pending.shift();
        if (result instanceof Error) throw result;
        return result;
      },
      destroy() { call.destroyed = true; call.destroyCount++; }
    };
  }
};
const mockUrl = 'data:text/javascript,export const http = globalThis.__wallpaperHttp';
const serviceUrl = moduleUrl('entry/src/main/ets/services/WallhavenService.ets', [
  ['@kit.NetworkKit', mockUrl], ['../core/Wallpaper', coreUrl]
]);
const { WallhavenService } = await import(serviceUrl);
test('API key is sent in a header, never in the API URL', async () => {
  calls = [];
  pending = [{ responseCode: 200, result: JSON.stringify({ data: [] }) }];
  const service = new WallhavenService();
  service.setToken('example-secret');
  await service.collections();
  assert.equal(calls[0].url, 'https://wallhaven.cc/api/v1/collections');
  assert.equal(calls[0].options.header['X-API-Key'], 'example-secret');
  assert.ok(!calls[0].url.includes('example-secret'));
  assert.equal(calls[0].destroyed, true);
});
test('no collection list or details are requested as a guest', async () => {
  calls = [];
  const service = new WallhavenService();
  await assert.rejects(() => service.collections(), /API Key/);
  await assert.rejects(() => service.collection('my_wallpapers', 15, 1), /API Key/);
  assert.equal(calls.length, 0);
});
test('image downloads never receive the API key', async () => {
  calls = [];
  pending = Array.from({ length: 2 }, () => ({ responseCode: 200, result: new ArrayBuffer(10) }));
  const service = new WallhavenService();
  service.setToken('example-secret');
  await service.image(wallpaper.path);
  await service.image('https://cdn-hsyq-static.shanhutech.cn/bizhi/staticwp/202411/example--123.jpg');
  for (const call of calls) {
    assert.equal(call.options.header, undefined);
    assert.equal(call.destroyed, true);
  }
  await assert.rejects(() => service.image('https://example.com/a.jpg'), /图片地址无效/);
  assert.equal(calls.length, 2);
});
test('HTTP failures and transport failures release native requests', async () => {
  for (const response of [{ responseCode: 401 }, { responseCode: 429 }, new Error('offline')]) {
    calls = [];
    pending = [response];
    const service = new WallhavenService();
    service.setToken('example-secret');
    await assert.rejects(() => service.collections());
    assert.equal(calls[0].destroyed, true);
  }
});
test('Bing preview uses only the paired landscape fallback when portrait is missing, without credentials', async () => {
  calls = [];
  const base = 'https://cn.bing.com/th?id=OHR.Test_ZH-CN123';
  const portrait = base + '_1080x1920.jpg&pid=hp';
  const landscape = base + '_1920x1080.jpg&pid=hp';
  const body = new ArrayBuffer(10);
  pending = [{ responseCode: 404 }, { responseCode: 200, result: body }];
  const service = new WallhavenService();
  service.setToken('example-secret');
  assert.equal(await service.image(portrait, landscape), body);
  assert.deepEqual(calls.map(call => call.url), [portrait, landscape]);
  assert.ok(calls.every(call => !call.options.header && call.destroyCount === 1));
  await assert.rejects(() => service.image(portrait, landscape.replace('Test', 'Other')), /备用图片/);
  await assert.rejects(() => service.image(portrait, 'https://example.com/a.jpg'), /备用图片/);
  assert.equal(calls.length, 2);
});
test('zero-length and oversized image bodies are rejected', async () => {
  for (const data of [new ArrayBuffer(0), new ArrayBuffer(core.MAX_IMAGE_BYTES + 1)]) {
    pending = [{ responseCode: 200, result: data }];
    await assert.rejects(() => new WallhavenService().image(wallpaper.path), /图片文件无效/);
  }
});


test('cancellation and completion release the same native request only once', async () => {
  calls = [];
  let complete;
  pending = [new Promise(resolve => { complete = resolve; })];
  const service = new WallhavenService();
  service.setToken('example-secret');
  const result = service.collections();
  service.cancel();
  complete({ responseCode: 200, result: JSON.stringify({ data: [] }) });
  await result;
  assert.equal(calls[0].destroyCount, 1);
});

test('all seven nonempty purity combinations are encoded in search and collection pagination', () => {
  for (const purity of ['100', '010', '001', '110', '101', '011', '111']) {
    assert.ok(core.searchPath({ text: '', sorting: 'date_added', page: 3, purity }).includes('purity=' + purity));
    assert.equal(core.collectionPath('alice', 15, 3, purity), '/collections/alice/15?page=3&purity=' + purity);
  }
  for (const purity of ['000', '', '11', '1000', 'abc', '100&x=1']) {
    assert.throws(() => core.searchPath({ text: '', sorting: 'toplist', page: 1, purity }));
    assert.throws(() => core.collectionPath('alice', 15, 1, purity));
  }
});
test('purity toggles preserve at least one selection and use SFW Sketchy NSFW bit order', () => {
  assert.equal(core.togglePurity('100', 0), '100');
  assert.equal(core.togglePurity('100', 1), '110');
  assert.equal(core.togglePurity('110', 2), '111');
  assert.equal(core.togglePurity('101', 0), '001');
  for (const index of [-1, 3, 0.5]) assert.throws(() => core.togglePurity('100', index));
});
test('wallpaper purity metadata retains official labels and supports older responses without purity', () => {
  for (const [purity, label] of [['sfw', 'SFW'], ['sketchy', 'Sketchy'], ['nsfw', 'NSFW']]) {
    const page = { data: [{ ...wallpaper, purity }], meta: { current_page: 1, last_page: 1, total: 1 } };
    assert.equal(core.validatePage(page, 1).data[0].purity, purity);
    assert.equal(core.purityLabel(purity), label);
  }
  assert.equal(core.purityLabel(undefined), '');
  assert.throws(() => core.validatePage({ data: [{ ...wallpaper, purity: 'unknown' }], meta: { current_page: 1, last_page: 1, total: 1 } }, 1));
});
test('NSFW requests require the saved API key and carry the selected filter to all pages', async () => {
  calls = [];
  const service = new WallhavenService();
  assert.equal(service.hasToken(), false);
  await assert.rejects(() => service.search({ text: '', sorting: 'toplist', page: 1, purity: '001' }), /API Key/);
  await assert.rejects(() => service.collection('alice', 15, 2, '111'), /API Key/);
  assert.equal(calls.length, 0);
  service.setToken('example-secret');
  assert.equal(service.hasToken(), true);
  pending = [
    { responseCode: 200, result: JSON.stringify({ data: [], meta: { current_page: 2, last_page: 2, total: 0 } }) },
    { responseCode: 200, result: JSON.stringify({ data: [], meta: { current_page: 3, last_page: 3, total: 0 } }) }
  ];
  await service.search({ text: 'nature', sorting: 'date_added', page: 2, purity: '001' });
  await service.collection('alice', 15, 3, '111');
  assert.ok(calls[0].url.includes('purity=001'));
  assert.ok(calls[0].url.includes('page=2'));
  assert.equal(calls[1].url, 'https://wallhaven.cc/api/v1/collections/alice/15?page=3&purity=111');
  for (const call of calls) {
    assert.equal(call.options.header['X-API-Key'], 'example-secret');
    assert.ok(!call.url.includes('example-secret'));
  }
  service.setToken('');
  await assert.rejects(() => service.collection('alice', 15, 1, '001'), /API Key/);
});

test('explicit screen targets crop landscape portrait square and coprime resolutions inside source bounds', () => {
  const targets = [{ width: 1320, height: 2120 }, { width: 1080, height: 2340 },
    { width: 1179, height: 2556 }, { width: 1081, height: 2401 }, { width: 2120, height: 1320 }, { width: 2048, height: 2048 }];
  for (const target of targets) {
    for (const [width, height] of [[3840, 2160], [1320, 2120], [100, 100]]) {
      for (const zoom of [1, 1.2, 2, 3]) {
        for (const center of [0, 0.5, 1]) {
          const rect = core.cropRectangle(width, height, { zoom, centerX: center, centerY: center }, target);
          assert.ok(rect.x >= 0 && rect.y >= 0);
          assert.ok(rect.width >= 1 && rect.height >= 1);
          assert.ok(rect.x + rect.width <= width && rect.y + rect.height <= height);
          assert.ok(Math.abs(rect.width * target.height - rect.height * target.width) <= target.width + target.height);
          for (const value of Object.values(rect)) assert.ok(Number.isInteger(value));
        }
      }
    }
  }
});

test('invalid explicit targets are rejected while a matching target uses the entire source', () => {
  const selection = { zoom: 1, centerX: 0.5, centerY: 0.5 };
  assert.deepEqual(core.cropRectangle(1081, 2401, selection, { width: 1081, height: 2401 }), {
    x: 0, y: 0, width: 1081, height: 2401
  });
  for (const target of [{ width: 0, height: 100 }, { width: 100, height: Infinity }, { width: 1.5, height: 100 }]) {
    assert.throws(() => core.cropRectangle(3840, 2160, selection, target));
  }
});
