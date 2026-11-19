import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Wallpaper, MAX_IMAGE_BYTES } from '../core/Wallpaper';

export const MAX_FAVORITES: number = 100;
const MAX_STORAGE: number = 256 * 1024 * 1024;

export class FavoritesStore {
  private folder: string = '';
  private entries: Wallpaper[] = [];

  async open(filesDir: string): Promise<Wallpaper[]> {
    this.folder = filesDir + '/favorite-wallpapers';
    if (!await fileIo.access(this.folder)) await fileIo.mkdir(this.folder, true);
    const manifest = this.folder + '/index.json';
    this.entries = [];
    const files: Set<string> = new Set(await fileIo.listFile(this.folder));
    if (files.has('index.json')) {
      const saved = JSON.parse(await fileIo.readText(manifest)) as Wallpaper[];
      if (!Array.isArray(saved)) throw new Error('无法读取本地收藏');
      this.entries = saved.filter((item: Wallpaper) => item && /^[a-z0-9-]{1,32}$/.test(item.id) &&
        Number.isSafeInteger(item.file_size) && item.file_size > 0 && item.file_size <= MAX_IMAGE_BYTES &&
        files.has(item.id + '.img'));
    }
    const kept: Set<string> = new Set(this.entries.map((item: Wallpaper) => item.id + '.img'));
    for (const name of files) {
      if (/^(?:[a-z0-9-]{1,32}\.img(?:\.tmp)?|index\.json\.tmp)$/.test(name) && !kept.has(name)) {
        await this.removeFile(this.folder + '/' + name);
      }
    }
    return this.entries.slice();
  }

  imagePath(id: string): string {
    if (!this.folder || !/^[a-z0-9-]{1,32}$/.test(id)) throw new Error('收藏图片编号无效');
    return this.folder + '/' + id + '.img';
  }

  async readImage(id: string): Promise<ArrayBuffer> {
    const path = this.imagePath(id);
    const size = (await fileIo.stat(path)).size;
    if (size <= 0 || size > MAX_IMAGE_BYTES) throw new Error('本地收藏图片无效');
    const data = new ArrayBuffer(size);
    const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
    try {
      if (await fileIo.read(file.fd, data) !== size) throw new Error('本地收藏图片不完整');
      return data;
    } finally {
      await fileIo.close(file);
    }
  }

  async add(item: Wallpaper, image: ArrayBuffer): Promise<Wallpaper[]> {
    const path = this.imagePath(item.id);
    if (this.entries.some((entry: Wallpaper) => entry.id === item.id)) return this.entries.slice();
    if (image.byteLength <= 0 || image.byteLength > MAX_IMAGE_BYTES) throw new Error('收藏图片无效或超过 32 MB');
    const used = this.entries.reduce((total: number, entry: Wallpaper) => total + entry.file_size, 0);
    if (this.entries.length >= MAX_FAVORITES || used + image.byteLength > MAX_STORAGE) {
      throw new Error('本地收藏已达 100 张或 256 MB 上限，请先移除部分图片');
    }
    const record: Wallpaper = {
      id: item.id, path: item.path, thumbs: item.thumbs, fallbackPath: item.fallbackPath,
      dimension_x: item.dimension_x, dimension_y: item.dimension_y, resolution: item.resolution,
      title: item.title, attribution: item.attribution, purity: item.purity,
      file_type: item.file_type, file_size: image.byteLength
    };
    await this.write(path, image);
    try {
      return await this.persist([record, ...this.entries]);
    } catch (error) {
      await this.removeFile(path);
      throw error as Error;
    }
  }

  async remove(id: string): Promise<Wallpaper[]> {
    const path = this.imagePath(id);
    const result = await this.persist(this.entries.filter((item: Wallpaper) => item.id !== id));
    await this.removeFile(path);
    return result;
  }

  private async persist(next: Wallpaper[]): Promise<Wallpaper[]> {
    const encoded = new util.TextEncoder().encodeInto(JSON.stringify(next));
    await this.write(this.folder + '/index.json', encoded.buffer as ArrayBuffer);
    this.entries = next;
    return next.slice();
  }

  private async write(path: string, data: ArrayBuffer): Promise<void> {
    const temp = path + '.tmp';
    try {
      const file = await fileIo.open(temp, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        if (await fileIo.write(file.fd, data) !== data.byteLength) throw new Error('本地写入不完整');
      } finally {
        await fileIo.close(file);
      }
      await fileIo.rename(temp, path);
    } finally {
      await this.removeFile(temp);
    }
  }

  private async removeFile(path: string): Promise<void> {
    try { if (await fileIo.access(path)) await fileIo.unlink(path); } catch { console.warn('Favorite cache cleanup failed'); }
  }
}