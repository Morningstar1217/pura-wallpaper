import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { validWallhavenUsername } from '../core/Wallpaper';

export interface WallhavenCredentials {
  token: string;
  username: string;
}

export function decodeWallhavenCredentials(value: string): WallhavenCredentials {
  // Versions before account-scoped collections stored a raw API Key.
  if (/^[a-zA-Z0-9]{32}$/.test(value)) return { token: value, username: '' };
  const account = JSON.parse(value) as WallhavenCredentials;
  if (!account || typeof account.token !== 'string' || !/^[a-zA-Z0-9]{32}$/.test(account.token) ||
    typeof account.username !== 'string' || (account.username.length > 0 && !validWallhavenUsername(account.username))) {
    throw new Error('本机 Wallhaven 账户配置无效');
  }
  return account;
}

export class TokenStore {
  private alias: Uint8Array = new util.TextEncoder().encodeInto('purawallpaper.wallhaven.apikey');

  async read(): Promise<WallhavenCredentials> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, this.alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const records = await asset.query(query);
      if (records.length === 0) return { token: '', username: '' };
      const value = records[0].get(asset.Tag.SECRET) as Uint8Array;
      return decodeWallhavenCredentials(util.TextDecoder.create('utf-8').decodeToString(value));
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return { token: '', username: '' };
      throw new Error('无法读取本机安全存储，请解锁设备后重试');
    }
  }

  async save(account: WallhavenCredentials): Promise<void> {
    const token = account.token.trim();
    const username = account.username.trim();
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
    if (username.length > 0 && !validWallhavenUsername(username)) throw new Error('Wallhaven 用户名格式无效');
    const value: WallhavenCredentials = { token: token, username: username };
    const attributes: asset.AssetMap = new Map();
    attributes.set(asset.Tag.ALIAS, this.alias);
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(value)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try {
      await asset.add(attributes);
    } catch {
      throw new Error('保存 API Key 失败，请检查设备锁屏状态后重试');
    }
  }
}

