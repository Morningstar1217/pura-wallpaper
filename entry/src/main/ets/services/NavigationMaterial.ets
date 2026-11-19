import { uiMaterial } from '@kit.ArkUI';

export function createNavigationMaterial(): uiMaterial.ImmersiveMaterial | undefined {
  try {
    if (!uiMaterial.isImmersiveMaterialSupported()) return undefined;
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: true,
      lightEffect: {}
    });
  } catch {
    // Keep the navigation usable if the native material is unavailable.
    return undefined;
  }
}