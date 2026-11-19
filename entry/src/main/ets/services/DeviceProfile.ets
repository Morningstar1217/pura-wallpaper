import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { DeviceProfile } from '../core/Wallpaper';

export function getDeviceProfile(): DeviceProfile {
  const screen = display.getDefaultDisplaySync();
  if (!Number.isSafeInteger(screen.width) || !Number.isSafeInteger(screen.height) ||
    screen.width < 1 || screen.height < 1) {
    throw new Error('图片尺寸或裁剪参数无效');
  }
  return {
    name: deviceInfo.marketName.trim().replace(/^(?:HUAWEI(?:\s+|$)|华为\s*)/i, '').trim() ||
      deviceInfo.productModel.trim(),
    width: screen.width,
    height: screen.height
  };
}
