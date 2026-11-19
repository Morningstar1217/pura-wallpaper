import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GallerySource } from '../core/GallerySource';

const STORE: string = 'wallpaper_settings';
const KEY: string = 'gallery_source';

export class GallerySourceStore {
  async read(context: common.UIAbilityContext): Promise<GallerySource> {
    const store = await preferences.getPreferences(context, { name: STORE });
    const saved = await store.get(KEY, GallerySource.Gallery360);
    return saved === GallerySource.Wallhaven ? GallerySource.Wallhaven : GallerySource.Gallery360;
  }

  async save(context: common.UIAbilityContext, source: GallerySource): Promise<void> {
    const store = await preferences.getPreferences(context, { name: STORE });
    const previous = await store.get(KEY, GallerySource.Gallery360);
    await store.put(KEY, source);
    try {
      await store.flush();
    } catch {
      await store.put(KEY, previous);
      throw new Error('未能保存图库来源，请重试');
    }
  }
}