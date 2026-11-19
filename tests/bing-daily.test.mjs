import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const coreUrl = moduleUrl('entry/src/main/ets/core/Wallpaper.ets');
const bingUrl = moduleUrl('entry/src/main/ets/core/BingDaily.ets', [['./Wallpaper', coreUrl]]);
const { normalizeBingDaily } = await import(bingUrl);
const { isBingDailyImage } = await import(coreUrl);
const daily = {
  startdate: '20261118', urlbase: '/th?id=OHR.KnowledgeSculpture_ZH-CN3168800853',
  title: '思想在此成形', copyright: '© 示例摄影师'
};

test('daily recommendation keeps the Bing date, title, attribution and paired image variants', () => {
  const item = normalizeBingDaily({ images: [daily, { ...daily, startdate: '20261117' }] });
  assert.equal(item.id, 'bing-20261118');
  assert.equal(item.title, daily.title);
  assert.equal(item.attribution, daily.copyright);
  assert.match(item.path, /_1080x1920\.jpg&pid=hp$/);
  assert.match(item.fallbackPath, /_1920x1080\.jpg&pid=hp$/);
  assert.ok(isBingDailyImage(item.path));
  assert.ok(isBingDailyImage(item.fallbackPath));
  assert.equal(normalizeBingDaily({ images: [{ ...daily, title: '' }] }).title, '必应每日壁纸');
});

test('malformed Bing metadata cannot inject another image host or URL parameters', () => {
  for (const urlbase of ['//example.com/th?id=OHR.A', '/th?id=OHR.A&key=1', '/th?id=OHR.A%2F..', null]) {
    assert.throws(() => normalizeBingDaily({ images: [{ ...daily, urlbase }] }), /必应/);
  }
  assert.throws(() => normalizeBingDaily({ images: [] }), /必应/);
  assert.throws(() => normalizeBingDaily({ images: [{ ...daily, startdate: 'bad' }] }), /必应/);
  assert.equal(isBingDailyImage('https://cn.bing.com.example/th?id=OHR.A_1080x1920.jpg&pid=hp'), false);
});

let response;
const calls = [];
globalThis.__bingHttp = {
  RequestMethod: { GET: 1 }, HttpDataType: { STRING: 0 },
  createHttp() {
    const call = { destroyed: 0 };
    calls.push(call);
    return { async request(url, options) { Object.assign(call, { url, options }); return response; },
      destroy() { call.destroyed++; } };
  }
};
const { BingDailyService } = await import(moduleUrl('entry/src/main/ets/services/BingDailyService.ets', [
  ['@kit.NetworkKit', 'data:text/javascript,export const http = globalThis.__bingHttp'],
  ['../core/Wallpaper', coreUrl], ['../core/BingDaily', bingUrl]
]));

test('only the Bing China daily endpoint is requested, without credentials, and requests are released', async () => {
  response = { responseCode: 200, result: JSON.stringify({ images: [daily] }) };
  const service = new BingDailyService();
  assert.equal((await service.load()).title, daily.title);
  assert.equal(calls[0].url, 'https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=zh-CN');
  assert.deepEqual(calls[0].options.header, { Accept: 'application/json' });
  assert.equal(calls[0].destroyed, 1);
  response = { responseCode: 503 };
  await assert.rejects(service.load(), /暂不可用/);
  assert.equal(calls[1].destroyed, 1);
  let finish;
  response = new Promise(resolve => { finish = resolve; });
  const pending = service.load();
  service.cancel();
  finish({ responseCode: 200, result: JSON.stringify({ images: [daily] }) });
  await pending;
  assert.equal(calls[2].destroyed, 1);
});