import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const arkUi = 'data:text/javascript,export const uiMaterial = globalThis.__navigationUiMaterial';
const api = {};
globalThis.__navigationUiMaterial = api;
const { createNavigationMaterial } = await import(moduleUrl('entry/src/main/ets/services/NavigationMaterial.ets', [
  ['@kit.ArkUI', arkUi]
]));

test('supported devices use native immersive material with interactive light feedback', () => {
  Object.assign(api, {
    isImmersiveMaterialSupported: () => true,
    ImmersiveStyle: { REGULAR: 2 },
    ImmersiveMaterial: class { constructor(options) { this.options = options; } }
  });
  const material = createNavigationMaterial();
  assert.ok(material instanceof api.ImmersiveMaterial);
  assert.deepEqual(material.options, { style: 2, applyShadow: true, interactive: true, lightEffect: {} });
});

test('unsupported devices do not construct a material and use the fallback', () => {
  let constructed = false;
  Object.assign(api, {
    isImmersiveMaterialSupported: () => false,
    ImmersiveMaterial: class { constructor() { constructed = true; } }
  });
  assert.equal(createNavigationMaterial(), undefined);
  assert.equal(constructed, false);
});

test('capability or constructor failures select the fallback without blocking the nav', () => {
  api.isImmersiveMaterialSupported = () => { throw new Error('Unavailable'); };
  assert.equal(createNavigationMaterial(), undefined);
  api.isImmersiveMaterialSupported = () => true;
  api.ImmersiveMaterial = class { constructor() { throw new Error('Unavailable'); } };
  assert.equal(createNavigationMaterial(), undefined);
});