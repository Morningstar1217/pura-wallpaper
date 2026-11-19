import { http } from '@kit.NetworkKit';
import { WallpaperPage } from '../core/Wallpaper';
import { GalleryResponse, galleryPath, normalizeGalleryPage } from '../core/Gallery360';

export class Gallery360Service {
  private active: Set<http.HttpRequest> = new Set();

  async search(text: string, category: string, page: number): Promise<WallpaperPage> {
    const url = 'https://bz.wktyl.com' + galleryPath(text, category, page);
    const request = http.createHttp();
    this.active.add(request);
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { Accept: 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      if (response.responseCode !== 200) throw new Error('360 壁纸服务暂不可用（' + response.responseCode + '）');
      if (typeof response.result !== 'string') throw new Error('360 壁纸数据异常，请稍后重试');
      let payload: GalleryResponse;
      try {
        payload = JSON.parse(response.result) as GalleryResponse;
      } catch {
        throw new Error('360 壁纸数据异常，请稍后重试');
      }
      return normalizeGalleryPage(payload, page);
    } finally {
      if (this.active.delete(request)) request.destroy();
    }
  }

  cancel(): void {
    for (const request of this.active) request.destroy();
    this.active.clear();
  }
}