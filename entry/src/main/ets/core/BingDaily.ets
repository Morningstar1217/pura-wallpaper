import { Wallpaper, isBingDailyImage } from './Wallpaper';

export const BING_ORIGIN: string = 'https://cn.bing.com';
export const BING_ARCHIVE_PATH: string = '/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=zh-CN';

interface BingEntry {
  startdate: string;
  urlbase: string;
  title?: string;
  copyright?: string;
}

export interface BingArchive {
  images: BingEntry[];
}

export function normalizeBingDaily(archive: BingArchive): Wallpaper {
  const entry = archive && Array.isArray(archive.images) ? archive.images[0] : undefined;
  if (!entry || typeof entry.startdate !== 'string' || !/^\d{8}$/.test(entry.startdate) ||
    typeof entry.urlbase !== 'string' || !/^\/th\?id=OHR\.[A-Za-z0-9_.-]{1,180}$/.test(entry.urlbase)) {
    throw new Error('必应每日壁纸数据异常');
  }
  const portrait = BING_ORIGIN + entry.urlbase + '_1080x1920.jpg&pid=hp';
  const landscape = BING_ORIGIN + entry.urlbase + '_1920x1080.jpg&pid=hp';
  if (!isBingDailyImage(portrait) || !isBingDailyImage(landscape)) throw new Error('必应图片地址无效');
  return {
    id: 'bing-' + entry.startdate, path: portrait, fallbackPath: landscape,
    thumbs: { large: portrait, original: portrait, small: portrait },
    dimension_x: 1080, dimension_y: 1920, resolution: '1080x1920', file_type: 'image/jpeg', file_size: 0,
    title: typeof entry.title === 'string' ? entry.title.trim().slice(0, 120) || '必应每日壁纸' : '必应每日壁纸',
    attribution: typeof entry.copyright === 'string' ? entry.copyright.trim().slice(0, 500) : ''
  };
}