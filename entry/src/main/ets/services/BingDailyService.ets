import { http } from '@kit.NetworkKit';
import { Wallpaper } from '../core/Wallpaper';
import { BING_ORIGIN, BING_ARCHIVE_PATH, BingArchive, normalizeBingDaily } from '../core/BingDaily';

export class BingDailyService {
  private active?: http.HttpRequest;

  async load(): Promise<Wallpaper[]> {
    this.cancel();
    const request = http.createHttp();
    this.active = request;
    try {
      const response = await request.request(BING_ORIGIN + BING_ARCHIVE_PATH, {
        method: http.RequestMethod.GET,
        header: { Accept: 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 12000,
        maxLimit: 128 * 1024,
        usingCache: false
      });
      if (response.responseCode !== 200 || typeof response.result !== 'string') {
        throw new Error('必应每日壁纸暂不可用');
      }
      return normalizeBingDaily(JSON.parse(response.result) as BingArchive);
    } finally {
      if (this.active === request) {
        this.active = undefined;
        request.destroy();
      }
    }
  }

  cancel(): void {
    const request = this.active;
    this.active = undefined;
    request?.destroy();
  }
}