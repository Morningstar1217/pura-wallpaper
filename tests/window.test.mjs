import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const light = 1;
const dark = 0;
const appearance = {
  statusBarColor: '#00000000', navigationBarColor: '#00000000',
  statusBarContentColor: '#1A1A1A', navigationBarContentColor: '#1A1A1A',
  enableStatusBarAnimation: false, enableNavigationBarAnimation: false
};
let state;
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function setup() {
  state = { calls: [], pending: [], waitForBars: false, rejectVisibility: false };
  globalThis.__wallpaperDeviceProfile = { name: 'Pura X', width: 1320, height: 2120 };
  const storage = new Map();
  globalThis.AppStorage = { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) };
  globalThis.__wallpaperDisplay = {
    on(event, callback) { state.displayListener = callback; },
    off(event, callback) { assert.equal(callback, state.displayListener); state.displayListener = undefined; }
  };
  globalThis.__wallpaperWindowContext = {
    config: { colorMode: light },
    resourceManager: { getConfigurationSync() { return { colorMode: state.resourceColorMode ?? light }; } }
  };
  const mainWindow = {
    on(event, callback) { assert.equal(event, 'keyboardHeightChange'); state.keyboardListener = callback; },
    off(event, callback) {
      assert.equal(event, 'keyboardHeightChange');
      assert.equal(callback, state.keyboardListener);
      state.keyboardListener = undefined;
    },
    setImmersiveModeEnabledState(enabled) { state.calls.push(['immersive', enabled]); },
    setWindowSystemBarProperties(properties) {
      state.calls.push(['appearance', properties]);
      return completion();
    },
    setSpecificSystemBarEnabled(name, enabled, animation) {
      state.calls.push(['visibility', name, enabled, animation]);
      if (state.rejectVisibility) return Promise.reject(new Error('window service unavailable'));
      return completion();
    }
  };
  const stage = {
    getMainWindowSync() { return mainWindow; },
    async loadContent(path) { state.calls.push(['content', path]); }
  };
  return { ability: new EntryAbility(), stage };
}
function completion() {
  if (!state.waitForBars) return Promise.resolve();
  const pending = deferred();
  state.pending.push(pending);
  return pending.promise;
}
const abilityKit = 'data:text/javascript,' + encodeURIComponent(`
  export class UIAbility {
    get context() { return globalThis.__wallpaperWindowContext; }
  }
  export const ConfigurationConstant = {
    ColorMode: { COLOR_MODE_DARK: ${dark}, COLOR_MODE_LIGHT: ${light}, COLOR_MODE_NOT_SET: -1 }
  };
`);
globalThis.__wallpaperDisplayProxy = {
  on(...args) { return globalThis.__wallpaperDisplay.on(...args); },
  off(...args) { return globalThis.__wallpaperDisplay.off(...args); }
};
const { default: EntryAbility } = await import(moduleUrl(
  'entry/src/main/ets/entryability/EntryAbility.ets', [
    ['@kit.AbilityKit', abilityKit],
    ['@kit.ArkUI', 'data:text/javascript,export const window = {}; export const display = globalThis.__wallpaperDisplayProxy'],
    ['../services/DeviceProfile', 'data:text/javascript,export function getDeviceProfile() { return globalThis.__wallpaperDeviceProfile; }']
  ]
));

test('startup configures both system bars before content without changing immersive layout', async () => {
  const { ability, stage } = setup();
  state.waitForBars = true;
  const startup = ability.onWindowStageCreate(stage);
  assert.deepEqual(state.calls, [
    ['appearance', appearance],
    ['visibility', 'status', true, false],
    ['visibility', 'navigationIndicator', false, false]
  ]);
  assert.equal(state.pending.length, 3);
  state.pending[0].resolve();
  state.pending[1].resolve();
  await Promise.resolve();
  assert.equal(state.calls.some(call => call[0] === 'content'), false);
  state.pending[2].resolve();
  await startup;
  assert.deepEqual(state.calls.at(-1), ['content', 'pages/Index']);
});

test('theme changes update colors without enabling bar animations or changing visibility', async () => {
  const { ability, stage } = setup();
  await ability.onWindowStageCreate(stage);
  state.calls = [];
  ability.onConfigurationUpdate({ colorMode: dark });
  assert.deepEqual(state.calls, [['appearance', {
    statusBarColor: '#00000000', navigationBarColor: '#00000000',
    statusBarContentColor: '#F2F2F2', navigationBarContentColor: '#F2F2F2',
    enableStatusBarAnimation: false, enableNavigationBarAnimation: false
  }]]);
  ability.onWindowStageDestroy();
  ability.onConfigurationUpdate({ colorMode: light });
  assert.equal(state.calls.length, 1);
});

test('keyboard visibility follows the native window and clears on stage destruction', async () => {
  const { ability, stage } = setup();
  await ability.onWindowStageCreate(stage);
  assert.equal(AppStorage.get('keyboardVisible'), false);
  state.keyboardListener(360);
  assert.equal(AppStorage.get('keyboardVisible'), true);
  state.keyboardListener(0);
  assert.equal(AppStorage.get('keyboardVisible'), false);
  state.keyboardListener(360);
  ability.onWindowStageDestroy();
  assert.equal(state.keyboardListener, undefined);
  assert.equal(AppStorage.get('keyboardVisible'), false);
});

test('window service failure still loads application content', async context => {
  context.mock.method(console, 'warn', () => {});
  const { ability, stage } = setup();
  state.rejectVisibility = true;
  await ability.onWindowStageCreate(stage);
  assert.deepEqual(state.calls.at(-1), ['content', 'pages/Index']);
});

test('display changes update physical crop dimensions and release their listener', async () => {
  const { ability, stage } = setup();
  await ability.onWindowStageCreate(stage);
  const initial = AppStorage.get('deviceProfile');
  ability.onConfigurationUpdate({ colorMode: dark });
  assert.equal(AppStorage.get('deviceProfile'), initial);
  globalThis.__wallpaperDeviceProfile = { name: 'Other phone', width: 1080, height: 2340 };
  state.displayListener(0);
  assert.deepEqual(AppStorage.get('deviceProfile'), globalThis.__wallpaperDeviceProfile);
  ability.onWindowStageDestroy();
  assert.equal(state.displayListener, undefined);
});

test('partial configuration and foreground refresh retain the effective system theme', async () => {
  const { ability, stage } = setup();
  await ability.onWindowStageCreate(stage);
  state.resourceColorMode = dark;
  ability.onConfigurationUpdate({ direction: 0 });
  assert.equal(state.calls.at(-1)[1].statusBarContentColor, '#F2F2F2');
  globalThis.__wallpaperWindowContext.config.colorMode = dark;
  ability.onForeground();
  assert.equal(state.calls.at(-1)[1].statusBarContentColor, '#F2F2F2');
});

test('cold foreground callbacks and repeated theme notifications avoid duplicate system bar writes', async () => {
  const { ability, stage } = setup();
  state.waitForBars = true;
  const startup = ability.onWindowStageCreate(stage);
  ability.onForeground();
  assert.equal(state.calls.filter(call => call[0] === 'appearance').length, 1);
  for (const operation of state.pending) operation.resolve();
  await startup;
  state.waitForBars = false;
  ability.onForeground();
  ability.onConfigurationUpdate({ colorMode: light });
  assert.equal(state.calls.filter(call => call[0] === 'appearance').length, 1);
  state.resourceColorMode = dark;
  ability.onConfigurationUpdate({ colorMode: -1 });
  assert.equal(state.calls.at(-1)[1].statusBarContentColor, '#F2F2F2');
  ability.onConfigurationUpdate({ colorMode: -1 });
  assert.equal(state.calls.filter(call => call[0] === 'appearance').length, 2);
});
