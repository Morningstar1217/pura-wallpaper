import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const preview = readFileSync(new URL('../entry/src/main/ets/components/PreviewView.ets', import.meta.url), 'utf8');
const toastBody = preview.match(/private showSaveToast\(message: string\): void \{\r?\n([\s\S]*?)\r?\n {2}\}/)?.[1];
const saveBody = preview.match(/private async save\(result: SaveButtonOnClickResult\): Promise<void> \{\r?\n([\s\S]*?)\r?\n {2}\}/)?.[1];
assert.ok(toastBody && saveBody);
const result = { SUCCESS: 0, TEMPORARY_AUTHORIZATION_FAILED: 1, CANCELED_BY_USER: 2 };
const showSaveToast = new Function('message', toastBody);
const runSave = new Function('SaveButtonOnClickResult', 'exportAndSaveWallpaper',
  `return async function(result) {${saveBody.replace(/const target: WallpaperSize/g, 'const target')
    .replace(/ as common\.UIAbilityContext/g, '')}}`);

function setup() {
  const shown = [];
  const busy = [];
  return {
    active: true, session: {}, saving: false, generation: 1,
    deviceProfile: { width: 1320, height: 2120 }, wallpaper: { id: 'abc123' },
    selection: () => ({ zoom: 1, centerX: 0.5, centerY: 0.5 }),
    onBusy: value => busy.push(value), releaseSession: () => {},
    getUIContext: () => ({ getHostContext: () => ({}), getPromptAction: () => ({ showToast: toast => shown.push(toast) }) }),
    showSaveToast, shown, busy
  };
}

test('saving twice while busy exports once and gives a two-second success toast', async () => {
  const view = setup();
  let finish;
  let calls = 0;
  const save = runSave(result, () => {
    calls++;
    return new Promise(resolve => { finish = resolve; });
  });
  const first = save.call(view, result.SUCCESS);
  await save.call(view, result.SUCCESS);
  assert.equal(view.saving, true);
  assert.equal(calls, 1);
  assert.deepEqual(view.shown, []);
  finish(true);
  await first;
  assert.equal(view.saving, false);
  assert.deepEqual(view.busy, [true, false]);
  assert.deepEqual(view.shown, [{ message: '已保存到图库', duration: 2000 }]);
});

test('cancel is silent, and authorization and export failures are temporary messages', async () => {
  const view = setup();
  let calls = 0;
  const save = runSave(result, async () => { calls++; throw Error('write failed'); });
  await save.call(view, result.CANCELED_BY_USER);
  assert.deepEqual(view.shown, []);
  await save.call(view, result.TEMPORARY_AUTHORIZATION_FAILED);
  assert.equal(calls, 0);
  await save.call(view, result.SUCCESS);
  assert.equal(calls, 1);
  assert.deepEqual(view.shown, [
    { message: '未获得保存授权，请重试', duration: 2000 },
    { message: '保存到图库失败，请重试', duration: 2000 }
  ]);
});

test('saving does not show feedback after the editor is no longer active', async () => {
  const view = setup();
  const save = runSave(result, async () => { view.active = false; return false; });
  await save.call(view, result.SUCCESS);
  assert.deepEqual(view.shown, []);
  assert.deepEqual(view.busy, [true, false]);
});
