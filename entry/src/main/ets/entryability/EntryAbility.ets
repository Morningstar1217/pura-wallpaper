import { UIAbility, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';

import { DeviceProfile } from '../core/Wallpaper';
import { getDeviceProfile } from '../services/DeviceProfile';

export default class EntryAbility extends UIAbility {
  private mainWindow?: window.Window;
  private contentReady: boolean = false;
  private requestedColorMode?: number;
  private onDisplayChanged = (): void => this.updateDeviceProfile();

  onCreate(): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch {
      console.warn('System color mode is unavailable');
    }
  }

  async onWindowStageCreate(stage: window.WindowStage): Promise<void> {
    try {
      this.mainWindow = stage.getMainWindowSync();
      await Promise.all([
        this.updateSystemBars(this.context.config),
        this.mainWindow.setSpecificSystemBarEnabled('status', true, false),
        this.mainWindow.setSpecificSystemBarEnabled('navigationIndicator', false, false)
      ]);
    } catch {
      console.warn('Default window layout will be used');
    }
    this.updateDeviceProfile();
    try {
      display.on('change', this.onDisplayChanged);
    } catch {
      console.warn('Display listener is unavailable');
    }
    try {
      await stage.loadContent('pages/Index');
      this.contentReady = true;
    } catch {
      console.error('Application content could not be loaded');
    }
  }

  onConfigurationUpdate(configuration: Configuration): void {
    this.updateDeviceProfile();
    this.updateSystemBars(configuration);
  }

  onForeground(): void {
    if (!this.contentReady) return;
    this.updateDeviceProfile();
    this.updateSystemBars(this.context.config);
  }

  private updateDeviceProfile(): void {
    if (!this.mainWindow) return;
    try {
      const profile = getDeviceProfile();
      const previous = AppStorage.get<DeviceProfile>('deviceProfile');
      if (previous?.name !== profile.name || previous?.width !== profile.width || previous?.height !== profile.height) {
        AppStorage.setOrCreate('deviceProfile', profile);
      }
    } catch {
      console.warn('Device display information is unavailable');
    }
  }

  private async updateSystemBars(configuration: Configuration): Promise<void> {
    if (!this.mainWindow) return;
    try {
      const configuredMode = configuration.colorMode;
      const mode = configuredMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ||
        configuredMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        ? configuredMode : this.context.resourceManager.getConfigurationSync().colorMode;
      if (this.requestedColorMode === mode) return;
      this.requestedColorMode = mode;
      const dark = mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      await this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: dark ? '#F2F2F2' : '#1A1A1A',
        navigationBarContentColor: dark ? '#F2F2F2' : '#1A1A1A',
        enableStatusBarAnimation: false,
        enableNavigationBarAnimation: false
      });
    } catch {
      this.requestedColorMode = undefined;
      console.warn('System bar appearance is unavailable');
    }
  }

  onWindowStageDestroy(): void {
    try {
      display.off('change', this.onDisplayChanged);
    } catch {
      console.warn('Display listener release failed');
    }
    this.mainWindow = undefined;
    this.contentReady = false;
    this.requestedColorMode = undefined;
  }
}
