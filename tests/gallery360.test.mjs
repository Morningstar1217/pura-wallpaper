import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const coreUrl = moduleUrl('entry/src/main/ets/core/Wallpaper.ets');
const galleryUrl = moduleUrl('entry/src/main/ets/core/Gallery360.ets', [['./Wallpaper', coreUrl]]);
const { galleryPath, normalizeGalleryPage } = await import(galleryUrl);
const image = 'https://cdn-hsyq-static.shanhutech.cn/bizhi/staticwp/202409/sample--123.jpg';
const entry = { id: '2063340', media: { image_url: image.replace('https:', 'http:'),
  thumbnail_url: 'https://cdn-hsyq-static.shanhutech.cn/bizhi/thumbnails/sample.jpg', width: 1920, height: 1080 } };
const payload = {
  success: true, data: [entry], pagination: { current_page: 2, total_pages: 4, total_items: 57 }
};

test('360 requests support numeric topics, paging, and a separate keyword mode', () => {
  assert.equal(galleryPath('', 'all', 1), '/api_360_bing.php?source=360&limit=16&page=1');
  assert.equal(galleryPath('', '26', 2), '/api_360_bing.php?source=360&limit=16&page=2&category=26');
  assert.equal(galleryPath(' 星河 & 湖 ', '26', 3),
    '/api_360_bing.php?source=360&limit=16&page=3&search=' + encodeURIComponent('星河 & 湖'));
  assert.throws(() => galleryPath('', '1&x=2', 1));
  for (const page of [0, -1, 1.5, Infinity]) assert.throws(() => galleryPath('', 'all', page));
});

test('360 responses map to the grid model and use HTTPS for the allowed media host', () => {
  const { data, meta } = normalizeGalleryPage(payload, 2);
  assert.deepEqual(meta, { current_page: 2, last_page: 4, total: 57 });
  assert.equal(data[0].id, '360-2063340');
  assert.equal(data[0].resolution, '1920x1080');
  assert.equal(data[0].path, image);
  assert.equal(data[0].thumbs.large, entry.media.thumbnail_url);
  const mixed = normalizeGalleryPage({ ...payload, data: [null, { ...entry, id: '../123' },
    { ...entry, media: { ...entry.media, thumbnail_url: 'https://untrusted.example/image.jpg' } }] }, 2);
  assert.equal(mixed.data.length, 1);
  assert.equal(mixed.data[0].thumbs.large, image);
});

test('invalid gallery URLs or pagination are rejected and empty searches remain valid', () => {
  for (const url of [image.replace('.cn/', '.cn.example/'), image.replace('.cn/', '.cn@evil.example/'),
    image + '?secret=x', image.replace('staticwp', '..'), image.replace('.jpg', '.html')]) {
    assert.throws(() => normalizeGalleryPage({ ...payload, data: [{ ...entry, media: { ...entry.media, image_url: url } }] }, 2));
  }
  assert.throws(() => normalizeGalleryPage(payload, 1));
  assert.throws(() => normalizeGalleryPage({ ...payload, success: false }, 2));
  assert.deepEqual(normalizeGalleryPage({ ...payload, data: [] }, 2).data, []);
});

test('pet, minimal, car and game categories accept the upstream backup CDN and its /a/ image paths', () => {
  for (const path of ['bizhi/staticwp/201802/dc489bd4088dfb4d268d706fa2d2b687.jpg', 'a/201911/21/5dd635d6be968.jpg']) {
    const url = 'http://cdn-hsyq-static-bak.shanhutech.cn/' + path;
    const response = { ...payload, data: [{ ...entry, media: { ...entry.media, image_url: url, thumbnail_url: url } }] };
    const [item] = normalizeGalleryPage(response, 2).data;
    assert.equal(item.path, url.replace('http:', 'https:'));
    assert.equal(item.thumbs.large, item.path);
  }
});

let nextResponse;
const calls = [];
globalThis.__galleryHttp = {
  RequestMethod: { GET: 1 }, HttpDataType: { STRING: 0 },
  createHttp() {
    const call = { destroyed: 0 };
    calls.push(call);
    return {
      async request(url, options) { Object.assign(call, { url, options }); return nextResponse; },
      destroy() { call.destroyed++; }
    };
  }
};
const { Gallery360Service } = await import(moduleUrl('entry/src/main/ets/services/Gallery360Service.ets', [
  ['@kit.NetworkKit', 'data:text/javascript,export const http = globalThis.__galleryHttp'],
  ['../core/Wallpaper', coreUrl], ['../core/Gallery360', galleryUrl]
]));

test('360 service requests only its own host without credentials and releases completed requests', async () => {
  nextResponse = { responseCode: 200, result: JSON.stringify(payload) };
  const result = await new Gallery360Service().search('', '9', 2);
  const call = calls.at(-1);
  assert.equal(call.url, 'https://bz.wktyl.com/api_360_bing.php?source=360&limit=16&page=2&category=9');
  assert.deepEqual(call.options.header, { Accept: 'application/json' });
  assert.equal(call.destroyed, 1);
  assert.equal(result.data[0].path, image);
});

test('360 service reports HTTP and invalid JSON errors and avoids double destruction after cancellation', async () => {
  const service = new Gallery360Service();
  nextResponse = { responseCode: 503 };
  await assert.rejects(() => service.search('', 'all', 2), /503/);
  assert.equal(calls.at(-1).destroyed, 1);
  nextResponse = { responseCode: 200, result: '<html>' };
  await assert.rejects(() => service.search('', 'all', 2), /数据异常/);
  assert.equal(calls.at(-1).destroyed, 1);
  let finish;
  nextResponse = new Promise(resolve => { finish = resolve; });
  const pending = service.search('', 'all', 2);
  service.cancel();
  finish({ responseCode: 200, result: JSON.stringify(payload) });
  await pending;
  assert.equal(calls.at(-1).destroyed, 1);
});