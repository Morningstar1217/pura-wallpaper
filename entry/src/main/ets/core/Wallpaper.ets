export const API_ORIGIN: string = 'https://wallhaven.cc/api/v1';
export const TARGET_WIDTH: number = 1320;
export const TARGET_HEIGHT: number = 2120;
export const MAX_IMAGE_BYTES: number = 32 * 1024 * 1024;
export const ALL_WALLHAVEN_CATEGORIES: string = '111';

export interface WallpaperSize {
  width: number;
  height: number;
}

export interface DeviceProfile extends WallpaperSize {
  name: string;
}

export interface Wallpaper {
  id: string;
  path: string;
  thumbs: Thumbnails;
  dimension_x: number;
  dimension_y: number;
  resolution: string;
  file_size: number;
  file_type: string;
  purity?: string;
  title?: string;
  attribution?: string;
  fallbackPath?: string;
}

export interface Thumbnails {
  large: string;
  original: string;
  small: string;
}

export interface Collection {
  id: number;
  label: string;
  count: number;
}

export interface PageMeta {
  current_page: number;
  last_page: number;
  total: number;
}

export interface WallpaperPage {
  data: Wallpaper[];
  meta: PageMeta;
}

export interface CollectionList {
  data: Collection[];
}

export interface SearchQuery {
  text: string;
  sorting: string;
  page: number;
  purity?: string;
  categories?: string;
}

export interface CropSelection {
  zoom: number;
  centerX: number;
  centerY: number;
}

export interface CropRectangle {
  x: number;
  y: number;
  width: number;
  height: number;
}

export function clamp(value: number, minimum: number, maximum: number): number {
  return Math.max(minimum, Math.min(value, maximum));
}

export function validatePurity(purity: string): string {
  if (!/^[01]{3}$/.test(purity) || purity === '000') throw new Error('分级参数无效');
  return purity;
}

export function validateCategories(categories: string): string {
  if (!/^[01]{3}$/.test(categories) || categories === '000') throw new Error('分类参数无效');
  return categories;
}

function toggleFilterBit(current: string, index: number, error: string): string {
  if (!Number.isInteger(index) || index < 0 || index > 2) throw new Error(error);
  const bits = current.split('');
  bits[index] = bits[index] === '1' ? '0' : '1';
  const next = bits.join('');
  return next === '000' ? current : next;
}

export function togglePurity(current: string, index: number): string {
  return toggleFilterBit(validatePurity(current), index, '分级参数无效');
}

export function toggleCategory(current: string, index: number): string {
  return toggleFilterBit(validateCategories(current), index, '分类参数无效');
}

export function purityLabel(purity?: string): string {
  if (purity === 'sfw') return 'SFW';
  if (purity === 'sketchy') return 'Sketchy';
  if (purity === 'nsfw') return 'NSFW';
  return '';
}

export function searchPath(query: SearchQuery): string {
  const sorting = query.sorting === 'date_added' ? 'date_added' : 'toplist';
  const page = Math.max(1, Math.floor(query.page));
  const purity = validatePurity(query.purity ?? '100');
  const categories = validateCategories(query.categories ?? ALL_WALLHAVEN_CATEGORIES);
  let path = '/search?purity=' + purity + '&categories=' + categories + '&order=desc&sorting=' + sorting + '&page=' + page;
  if (sorting === 'toplist') path += '&topRange=1M';
  const text = query.text.trim();
  if (text.length > 0) path += '&q=' + encodeURIComponent(text);
  return path;
}

export function validWallhavenUsername(username: string): boolean {
  return /^[a-zA-Z0-9_-]{1,32}$/.test(username);
}

export function collectionPath(username: string, id: number, page: number = 1, purity?: string): string {
  if (!validWallhavenUsername(username)) throw new Error('请在设置中填写自己的 Wallhaven 用户名');
  if (!Number.isSafeInteger(id) || id < 1) throw new Error('收藏集编号无效');
  const filter = purity === undefined ? '' : '&purity=' + validatePurity(purity);
  return '/collections/' + username + '/' + id + '?page=' + Math.max(1, Math.floor(page)) + filter;
}

export function isOfficialImage(url: string): boolean {
  return /^https:\/\/(w|th)\.wallhaven\.cc\/[a-zA-Z0-9_./%-]+$/.test(url);
}

export function isGallery360Image(url: string): boolean {
  return /^https:\/\/cdn-hsyq-static(?:-bak)?\.shanhutech\.cn\/(?:bizhi|a)\/(?:[a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.(?:jpe?g|png|webp)$/i.test(url);
}

export function isBingDailyImage(url: string): boolean {
  return /^https:\/\/cn\.bing\.com\/th\?id=OHR\.[A-Za-z0-9_.-]{1,180}_(1080x1920|1920x1080)\.jpg&pid=hp$/.test(url);
}

export function validatePage(page: WallpaperPage, expectedPage: number): WallpaperPage {
  if (!page || !Array.isArray(page.data) || !page.meta ||
    page.meta.current_page !== expectedPage ||
    !Number.isInteger(page.meta.last_page) || page.meta.last_page < 0 ||
    !Number.isInteger(page.meta.total) || page.meta.total < 0) {
    throw new Error('壁纸数据格式异常，请稍后重试');
  }
  for (const item of page.data) {
    if (!item || !/^[a-z0-9]{6}$/.test(item.id) || !isOfficialImage(item.path) ||
      !item.thumbs || !isOfficialImage(item.thumbs.large) ||
      !Number.isInteger(item.dimension_x) || !Number.isInteger(item.dimension_y) ||
      item.dimension_x < 1 || item.dimension_y < 1 ||
      (item.purity !== undefined && purityLabel(item.purity).length === 0)) {
      throw new Error('壁纸数据格式异常，请稍后重试');
    }
  }
  return page;
}

export function validateCollections(list: CollectionList): Collection[] {
  if (!list || !Array.isArray(list.data)) throw new Error('收藏集数据格式异常');
  for (const item of list.data) {
    if (!item || !Number.isSafeInteger(item.id) || item.id < 1 ||
      typeof item.label !== 'string' || !Number.isInteger(item.count) || item.count < 0) {
      throw new Error('收藏集数据格式异常');
    }
  }
  return list.data;
}

export function cropRectangle(
  width: number, height: number, selection: CropSelection, target?: WallpaperSize
): CropRectangle {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width < 1 || height < 1 ||
    !Number.isFinite(selection.zoom) || !Number.isFinite(selection.centerX) ||
    !Number.isFinite(selection.centerY)) {
    throw new Error('图片尺寸或裁剪参数无效');
  }
  let cropWidth: number;
  let cropHeight: number;
  if (target) {
    if (!Number.isSafeInteger(target.width) || !Number.isSafeInteger(target.height) ||
      target.width < 1 || target.height < 1) throw new Error('图片尺寸或裁剪参数无效');
    const scale = Math.min(width / target.width, height / target.height) / clamp(selection.zoom, 1, 3);
    cropWidth = Math.max(1, Math.min(Math.floor(width), Math.round(target.width * scale)));
    cropHeight = Math.max(1, Math.min(Math.floor(height), Math.round(target.height * scale)));
  } else {
    if (width < 33 || height < 53) throw new Error('图片尺寸或裁剪参数无效');
    // Preserve the original helper contract for callers without an explicit target.
    const units = Math.max(1, Math.floor(Math.min(width / 33, height / 53) / clamp(selection.zoom, 1, 3)));
    cropWidth = units * 33;
    cropHeight = units * 53;
  }
  const x = Math.round(clamp(selection.centerX, 0, 1) * width - cropWidth / 2);
  const y = Math.round(clamp(selection.centerY, 0, 1) * height - cropHeight / 2);
  return {
    x: clamp(x, 0, Math.floor(width) - cropWidth),
    y: clamp(y, 0, Math.floor(height) - cropHeight),
    width: cropWidth,
    height: cropHeight
  };
}

export function appendWallpapers(existing: Wallpaper[], incoming: Wallpaper[]): Wallpaper[] {
  const ids: Set<string> = new Set(existing.map((item: Wallpaper) => item.id));
  const result: Wallpaper[] = existing.slice();
  for (const item of incoming) {
    if (!ids.has(item.id)) {
      result.push(item);
      ids.add(item.id);
    }
  }
  return result;
}

export function httpError(status: number): string {
  if (status === 401 || status === 403) return '访问被拒绝，请检查 API Key 或稍后重试';
  if (status === 429) return '请求过于频繁，请稍后重试';
  if (status === 404) return '壁纸或收藏集不存在';
  return '服务暂时不可用（' + status + '），请稍后重试';
}

