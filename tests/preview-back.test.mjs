import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const index = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
const backBody = index.match(/onBackPress\(\): boolean \{\r?\n([\s\S]*?)\r?\n {2}\}/)?.[1];
assert.ok(backBody, 'Index must handle native back navigation');
const onBackPress = new Function(backBody);

for (const overlay of ['originalView', 'cropFullscreen']) {
  for (const returnPage of ['home', 'remote']) {
    test(`native back closes ${overlay} before leaving the preview from ${returnPage}`, () => {
      const selected = { id: 'abc123' };
      const state = { page: 'preview', returnPage, originalView: false, cropFullscreen: false, selected, [overlay]: true };
      assert.equal(onBackPress.call(state), true);
      assert.equal(state[overlay], false);
      assert.equal(state.page, 'preview');
      assert.equal(state.selected, selected);
      assert.equal(onBackPress.call(state), true);
      assert.equal(state.page, returnPage);
      assert.equal(state.selected, undefined);
    });
  }
}
