import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { CropSelection, WallpaperSize, cropRectangle, TARGET_WIDTH, TARGET_HEIGHT } from '../core/Wallpaper';

export class WallpaperImage {
  source?: image.ImageSource;
  preview?: image.PixelMap;
  width: number = 0;
  height: number = 0;

  async load(data: ArrayBuffer): Promise<void> {
    this.source = image.createImageSource(data);
    try {
      const info = await this.source.getImageInfo();
      this.width = info.size.width;
      this.height = info.size.height;
      if (this.width < 1 || this.height < 1) throw new Error('图片尺寸或裁剪参数无效');
      const scale = Math.min(1, 2048 / Math.max(this.width, this.height));
      this.preview = await this.source.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(this.width * scale)),
          height: Math.max(1, Math.round(this.height * scale))
        }
      });
    } catch (error) {
      await this.release();
      throw error as Error;
    }
  }

  async exportJpeg(selection: CropSelection, target?: WallpaperSize): Promise<ArrayBuffer> {
    if (!this.source) throw new Error('原图尚未加载');
    const rectangle = cropRectangle(this.width, this.height, selection, target);
    const outputSize: WallpaperSize = { width: target?.width ?? TARGET_WIDTH, height: target?.height ?? TARGET_HEIGHT };
    let pixels: image.PixelMap | undefined;
    const packer = image.createImagePacker();
    try {
      pixels = await this.source.createPixelMap({
        desiredRegion: { x: rectangle.x, y: rectangle.y, size: { width: rectangle.width, height: rectangle.height } },
        desiredSize: outputSize,
        cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST
      });
      const outputInfo = await pixels.getImageInfo();
      if (outputInfo.size.width !== outputSize.width || outputInfo.size.height !== outputSize.height) {
        throw new Error('图片尺寸或裁剪参数无效');
      }
      return await packer.packToData(pixels, { format: 'image/jpeg', quality: 95 });
    } finally {
      try {
        if (pixels) await pixels.release();
      } finally {
        await packer.release();
      }
    }
  }

  async release(): Promise<void> {
    const preview = this.preview;
    const source = this.source;
    this.preview = undefined;
    this.source = undefined;
    try {
      if (preview) await preview.release();
    } finally {
      if (source) await source.release();
    }
  }
}

export async function saveToGallery(context: common.UIAbilityContext, data: ArrayBuffer, id: string): Promise<void> {
  if (data.byteLength === 0) throw new Error('待保存的图片为空');
  const helper = photoAccessHelper.getPhotoAccessHelper(context);
  try {
    // Submit bytes together with asset creation under SaveButton temporary access.
    const request = photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(
      context, photoAccessHelper.PhotoType.IMAGE, 'jpg', {
        title: 'PuraWallpaper-' + id + '-' + Date.now()
      }
    );
    request.addResource(photoAccessHelper.ResourceType.IMAGE_RESOURCE, data);
    await helper.applyChanges(request);
  } finally {
    await helper.release();
  }
}
