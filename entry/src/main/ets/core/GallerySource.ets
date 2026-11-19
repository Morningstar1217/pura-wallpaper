export enum GallerySource {
  Gallery360 = '360',
  Wallhaven = 'wallhaven'
}

export function gallerySourceLabel(source: GallerySource): string {
  return source === GallerySource.Wallhaven ? 'Wallhaven (CC)' : '360 壁纸';
}