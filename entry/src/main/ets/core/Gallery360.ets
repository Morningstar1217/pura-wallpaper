import { Wallpaper, WallpaperPage, isGallery360Image } from './Wallpaper';

export interface GalleryTopic {
  id: string;
  label: string;
}

export const GALLERY_TOPICS: GalleryTopic[] = [
  { id: 'all', label: '全部' }, { id: '9', label: '风景' }, { id: '26', label: '动漫' },
  { id: '14', label: '萌宠' }, { id: '15', label: '小清新' }, { id: '5', label: '游戏' },
  { id: '12', label: '汽车' }
];

interface GalleryMedia {
  image_url: string;
  thumbnail_url: string;
  width: number;
  height: number;
}

interface GalleryImage {
  id: string;
  media: GalleryMedia;
}

interface GalleryPagination {
  current_page: number;
  total_pages: number;
  total_items: number;
}

export interface GalleryResponse {
  success: boolean;
  data: GalleryImage[];
  pagination: GalleryPagination;
}

export function galleryPath(text: string, category: string, page: number): string {
  if (!Number.isSafeInteger(page) || page < 1 || !GALLERY_TOPICS.some((topic: GalleryTopic) => topic.id === category)) {
    throw new Error('壁纸分类或页码无效');
  }
  let path = '/api_360_bing.php?source=360&limit=16&page=' + page;
  const keyword = text.trim();
  // The upstream keyword mode ignores the category parameter.
  if (keyword.length > 0) path += '&search=' + encodeURIComponent(keyword);
  else if (category !== 'all') path += '&category=' + category;
  return path;
}

function secureImage(url: string): string {
  if (typeof url !== 'string') return '';
  const https = url.startsWith('http://') ? 'https://' + url.slice(7) : url;
  return isGallery360Image(https) ? https : '';
}

export function normalizeGalleryPage(response: GalleryResponse, page: number): WallpaperPage {
  if (!response || response.success !== true || !Array.isArray(response.data) || !response.pagination ||
    response.pagination.current_page !== page ||
    !Number.isSafeInteger(response.pagination.total_pages) || response.pagination.total_pages < 0 ||
    !Number.isSafeInteger(response.pagination.total_items) || response.pagination.total_items < 0) {
    throw new Error('360 壁纸数据异常，请稍后重试');
  }
  const images: Wallpaper[] = [];
  for (const item of response.data) {
    if (!item || typeof item.id !== 'string' || !/^\d{1,16}$/.test(item.id) || !item.media ||
      !Number.isSafeInteger(item.media.width) || item.media.width < 1 ||
      !Number.isSafeInteger(item.media.height) || item.media.height < 1) continue;
    const path = secureImage(item.media.image_url);
    if (path.length === 0) continue;
    const thumb = secureImage(item.media.thumbnail_url) || path;
    images.push({
      id: '360-' + item.id, path: path, thumbs: { large: thumb, original: path, small: thumb },
      dimension_x: item.media.width, dimension_y: item.media.height,
      resolution: item.media.width + 'x' + item.media.height, file_size: 0, file_type: ''
    });
  }
  if (images.length === 0 && response.data.length > 0) throw new Error('360 壁纸图片地址异常，请稍后重试');
  return {
    data: images,
    meta: {
      current_page: page,
      last_page: response.pagination.total_pages,
      total: response.pagination.total_items
    }
  };
}