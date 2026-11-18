import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

export class TokenStore {
  private alias: Uint8Array = new util.TextEncoder().encodeInto('purawallpaper.wallhaven.apikey');

  async read(): Promise<string> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const records = await asset.query(query);
      if (records.length === 0) return '';
      const value = records[0].get(asset.Tag.SECRET) as Uint8Array;
      return util.TextDecoder.create('utf-8').decodeToString(value);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return '';
      throw new Error('无法读取本机安全存储，请解锁设备后重试');
    }
  }

  async save(value: string): Promise<void> {
    const token = value.trim();
    if (token.length === 0) {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, this.alias);
      try {
        await asset.remove(query);
      } catch (error) {
        if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) {
          throw new Error('清除 API Key 失败，请重试');
        }
      }
      return;
    }
    if (!/^[a-zA-Z0-9]{32}$/.test(token)) throw new Error('请输入 32 位 Wallhaven API Key');
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(token));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try {
      await asset.add(attributes);
    } catch {
      throw new Error('保存 API Key 失败，请检查设备锁屏状态后重试');
    }
  }
}

