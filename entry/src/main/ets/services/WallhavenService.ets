import { http } from '@kit.NetworkKit';
import {
  API_ORIGIN, MAX_IMAGE_BYTES, WallpaperPage, CollectionList, Collection,
  SearchQuery, searchPath, collectionPath, validatePage, validateCollections,
  isOfficialImage, httpError, validatePurity
} from '../core/Wallpaper';

interface ApiHeaders {
  Accept: string;
  'X-API-Key'?: string;
}

export class WallhavenService {
  private active: Set<http.HttpRequest> = new Set();
  private token: string = '';

  setToken(token: string): void {
    this.token = token;
  }

  hasToken(): boolean {
    return this.token.length > 0;
  }

  private requirePurityAccess(purity: string): void {
    validatePurity(purity);
    if (purity.charAt(2) === '1' && !this.hasToken()) {
      throw new Error('NSFW 需要有效的 API Key');
    }
  }

  async search(query: SearchQuery): Promise<WallpaperPage> {
    this.requirePurityAccess(query.purity ?? '100');
    const body = await this.requestJson(searchPath(query));
    return validatePage(JSON.parse(body) as WallpaperPage, query.page);
  }

  async collections(): Promise<Collection[]> {
    const body = await this.requestJson(collectionPath());
    return validateCollections(JSON.parse(body) as CollectionList);
  }

  async collection(id: number, page: number, purity?: string): Promise<WallpaperPage> {
    this.requirePurityAccess(purity ?? '100');
    const body = await this.requestJson(collectionPath(id, page, purity));
    return validatePage(JSON.parse(body) as WallpaperPage, page);
  }

  private async requestJson(path: string): Promise<string> {
    const request = http.createHttp();
    this.active.add(request);
    let headers: ApiHeaders = { Accept: 'application/json' };
    if (this.token.length > 0) {
      headers = { Accept: 'application/json', 'X-API-Key': this.token };
    }
    try {
      const response = await request.request(API_ORIGIN + path, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 25000,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      if (response.responseCode !== 200) throw new Error(httpError(response.responseCode));
      if (typeof response.result !== 'string') throw new Error('服务返回的数据格式异常');
      return response.result;
    } finally {
      if (this.active.delete(request)) request.destroy();
    }
  }

  async image(url: string): Promise<ArrayBuffer> {
    if (!isOfficialImage(url)) throw new Error('图片地址无效');
    const request = http.createHttp();
    this.active.add(request);
    try {
      // Credentials are only sent to the API, never to the image CDN.
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 60000,
        maxLimit: MAX_IMAGE_BYTES,
        usingCache: true
      });
      if (response.responseCode !== 200) throw new Error(httpError(response.responseCode));
      const data = response.result as ArrayBuffer;
      if (!(data instanceof ArrayBuffer) || data.byteLength === 0 || data.byteLength > MAX_IMAGE_BYTES) {
        throw new Error('图片文件无效或超过 32 MB');
      }
      return data;
    } finally {
      if (this.active.delete(request)) request.destroy();
    }
  }

  cancel(): void {
    for (const request of this.active) request.destroy();
    this.active.clear();
  }
}

