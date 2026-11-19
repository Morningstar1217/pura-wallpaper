import test from 'node:test';
import assert from 'node:assert/strict';
import { moduleUrl } from './source-loader.mjs';

const coreUrl = moduleUrl('entry/src/main/ets/core/Wallpaper.ets');
let state;
function reset() {
  state = {
    sourceReleased: false, previewReleased: false, outputReleased: false, packerReleased: false,
    options: [], steps: [], packFailure: false, pixelReleaseFailure: false, applyFailure: false
  };
}
const source = {
  async getImageInfo() { return { size: { width: 3840, height: 2160 } }; },
  async createPixelMap(options) {
    state.options.push(options);
    if (options.desiredRegion) return {
      async getImageInfo() {
        return { size: state.wrongOutputSize ? { width: 1, height: 1 } : options.desiredSize };
      },
      async release() {
        state.outputReleased = true;
        if (state.pixelReleaseFailure) throw new Error('native release failure');
      }
    };
    return { async release() { state.previewReleased = true; } };
  },
  async release() { state.sourceReleased = true; }
};
globalThis.__wallpaperImageKit = {
  CropAndScaleStrategy: { CROP_FIRST: 2 },
  createImageSource() { return source; },
  createImagePacker() {
    return {
      async packToData(pixels, options) {
        state.packingOptions = options;
        if (state.packFailure) throw new Error('native encoder failure');
        return new Uint8Array([0xff, 0xd8, 0xff, 0xd9]).buffer;
      },
      async release() { state.packerReleased = true; }
    };
  }
};
globalThis.__wallpaperMediaKit = {
  PhotoType: { IMAGE: 1 }, ResourceType: { IMAGE_RESOURCE: 1 },
  getPhotoAccessHelper(context) {
    state.context = context;
    return {
      async applyChanges(request) {
        state.steps.push('apply');
        if (state.applyFailure) throw new Error('gallery failure');
      },
      async release() { state.steps.push('release'); }
    };
  },
  MediaAssetChangeRequest: {
    createAssetRequest(context, type, extension, options) {
      state.steps.push('create');
      state.extension = extension;
      state.title = options.title;
      return {
        addResource(type, data) {
          state.steps.push('bytes');
          state.data = data;
        }
      };
    }
  }
};
const imageModule = moduleUrl('entry/src/main/ets/services/WallpaperImage.ets', [
  ['@kit.ImageKit', 'data:text/javascript,export const image = globalThis.__wallpaperImageKit'],
  ['@kit.MediaLibraryKit', 'data:text/javascript,export const photoAccessHelper = globalThis.__wallpaperMediaKit'],
  ['../core/Wallpaper', coreUrl]
]);
const { WallpaperImage, saveToGallery, exportAndSaveWallpaper } = await import(imageModule);

test('preview decoding bounds the longest edge at 2048 pixels', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  assert.deepEqual(state.options[0].desiredSize, { width: 2048, height: 1152 });
  await image.release();
  assert.equal(state.previewReleased, true);
  assert.equal(state.sourceReleased, true);
  await image.release();
});
test('export applies the same exact crop as the preview before scaling', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  const output = await image.exportJpeg({ zoom: 1, centerX: 0.5, centerY: 0.5 });
  assert.ok(output.byteLength > 0);
  assert.deepEqual(state.options[1], {
    desiredRegion: { x: 1260, y: 20, size: { width: 1320, height: 2120 } },
    desiredSize: { width: 1320, height: 2120 }, cropAndScaleStrategy: 2
  });
  assert.deepEqual(state.packingOptions, { format: 'image/jpeg', quality: 95 });
  assert.equal(state.outputReleased, true);
  assert.equal(state.packerReleased, true);
  await image.release();
});
test('encoder failure still releases output pixels and packer', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  state.packFailure = true;
  await assert.rejects(() => image.exportJpeg({ zoom: 1, centerX: 0.5, centerY: 0.5 }));
  assert.equal(state.outputReleased, true);
  assert.equal(state.packerReleased, true);
  await image.release();
});
test('packer is released even when native pixel release throws', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  state.pixelReleaseFailure = true;
  await assert.rejects(() => image.exportJpeg({ zoom: 1, centerX: 0.5, centerY: 0.5 }));
  assert.equal(state.packerReleased, true);
  await image.release();
});
test('gallery asset and prepared bytes are submitted in one native change request', async () => {
  reset();
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]).buffer;
  await saveToGallery({}, bytes, 'abc123');
  assert.deepEqual(state.steps, ['create', 'bytes', 'apply', 'release']);
  assert.equal(state.data, bytes);
  assert.equal(state.extension, 'jpg');
  assert.match(state.title, /^PuraWallpaper-abc123-\d+$/);
});
test('gallery failures propagate and release the helper', async () => {
  reset();
  state.applyFailure = true;
  await assert.rejects(() => saveToGallery({}, new ArrayBuffer(2), 'abc123'), /gallery failure/);
  assert.deepEqual(state.steps, ['create', 'bytes', 'apply', 'release']);
});
test('empty exports cannot create gallery entries', async () => {
  reset();
  await assert.rejects(() => saveToGallery({}, new ArrayBuffer(0), 'abc123'));
  assert.deepEqual(state.steps, []);
});

test('one save operation exports the current crop and sends the JPEG to the gallery', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  const target = { width: 1276, height: 2848 };
  const selection = { zoom: 1.5, centerX: 0.6, centerY: 0.45 };
  const { cropRectangle } = await import(coreUrl);
  const expected = cropRectangle(3840, 2160, selection, target);
  assert.equal(await exportAndSaveWallpaper({}, image, selection, target, 'abc123', () => true), true);
  assert.deepEqual(state.options[1].desiredSize, target);
  assert.deepEqual(state.options[1].desiredRegion, {
    x: expected.x, y: expected.y, size: { width: expected.width, height: expected.height }
  });
  assert.deepEqual(state.steps, ['create', 'bytes', 'apply', 'release']);
  assert.deepEqual(new Uint8Array(state.data), new Uint8Array([0xff, 0xd8, 0xff, 0xd9]));
  await image.release();
});

test('screen or view changes during export and encoder errors do not create a gallery asset', async () => {
  reset();
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  const selection = { zoom: 1, centerX: 0.5, centerY: 0.5 };
  const target = { width: 1276, height: 2848 };
  assert.equal(await exportAndSaveWallpaper({}, image, selection, target, 'abc123', () => false), false);
  assert.equal(state.options.length, 1);
  let checks = 0;
  assert.equal(await exportAndSaveWallpaper({}, image, selection, target, 'abc123', () => ++checks === 1), false);
  assert.deepEqual(state.steps, []);
  state.packFailure = true;
  await assert.rejects(() => exportAndSaveWallpaper({}, image, selection, target, 'abc123', () => true),
    /native encoder failure/);
  assert.deepEqual(state.steps, []);
  await image.release();
});


test('native export uses the current physical target for decoder output dimensions', async () => {
  for (const target of [{ width: 1320, height: 2120 }, { width: 1080, height: 2340 }, { width: 1179, height: 2556 }]) {
    reset();
    const image = new WallpaperImage();
    await image.load(new ArrayBuffer(1));
    await image.exportJpeg({ zoom: 1, centerX: 0.5, centerY: 0.5 }, target);
    const request = state.options.at(-1);
    assert.deepEqual(request.desiredSize, target);
    assert.ok(request.desiredRegion.size.width <= 3840);
    assert.ok(request.desiredRegion.size.height <= 2160);
    assert.equal(state.outputReleased, true);
    await image.release();
  }
});

test('unexpected native output dimensions reject export and release its pixel map and packer', async () => {
  reset();
  state.wrongOutputSize = true;
  const image = new WallpaperImage();
  await image.load(new ArrayBuffer(1));
  await assert.rejects(() => image.exportJpeg({ zoom: 1, centerX: 0.5, centerY: 0.5 }, { width: 1080, height: 2340 }), /图片尺寸/);
  assert.equal(state.outputReleased, true);
  assert.equal(state.packerReleased, true);
  await image.release();
});
