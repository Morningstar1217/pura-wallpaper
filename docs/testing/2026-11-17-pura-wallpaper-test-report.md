# 映壁验证记录

日期为 2026-11-17，时区为 Asia/Shanghai。

## 交付与依据

用户确认首版采用 ArkTS / ArkUI，覆盖 Wallhaven 浏览、搜索、pangdunqing 收藏集、全屏预览、Pura X 裁剪及图库保存，最后由系统图库设置壁纸。规格见 [首版规格](../spec.md)。

源码工程位于 /Users/pangdun/Documents/Codex/2026-11-17/pura-wallpaper/outputs/PuraWallpaper。
设备依据是用户截图的 Pura X VDE-AL00、HarmonyOS 7.0.0.111、API 26、arm64-v8a、1320 × 2120。

## 原生构建

使用本机 DevEco Studio 工具链与 HarmonyOS SDK 26.0.0.105，release 构建成功。
HAP 包名为 com.pangdun.purawallpaper，版本为 1.0.0，声明权限为 ohos.permission.INTERNET。
HAP 中包含编译后的 ets/modules.abc、资源索引和页面配置，ZIP CRC 检查通过。

```sh
cd /Users/pangdun/Documents/Codex/2026-11-17/pura-wallpaper/outputs/PuraWallpaper
'/Applications/DevEco-Studio.app/Contents/tools/node/bin/node' scripts/build.mjs
```

原始日志位于任务目录 work/build-final.log。编译保留了 SDK 对可能抛出异常的 API 调用和 applyChanges 权限的提示，以及缺少 signingConfig 的提示。图库调用采用官方文档支持的 SaveButton 临时授权，相关调用和资源清理设有异常处理。

## 自动化检查

```sh
'/Applications/DevEco-Studio.app/Contents/tools/node/bin/node' --test tests/core.test.mjs tests/image.test.mjs
```

共收集 23 项，23 项通过，0 项失败，0 项跳过。日志位于任务目录 work/tests-final.log。

| 场景 | 预期和实际 |
| --- | --- |
| 查询与集合地址 | 关键字转义正确，热门/最新参数正确，固定账号及收藏集编号校验通过 |
| 官方图片地址 | 接受官方 HTTPS 图片域名，拒绝 HTTP、域名伪装、凭据和非官方地址 |
| 分页 | 校验响应页码，跨页和批内去重，保留原数组 |
| 裁剪边界 | 1,080 组尺寸、缩放及中心位置组合均落在原图内，保持精确 33∶53 比例 |
| 图片选区 | 3840 × 2160 横图选区为 x=1260、y=20、1320 × 2120 |
| 凭据边界 | API Key 仅在 API 请求头发送，CDN 请求无凭据 |
| 网络资源 | 成功、HTTP 失败、传输失败、取消后完成均释放请求，取消场景只释放一次 |
| 图片体积 | 空图片及超过 32 MB 的图片拒绝 |
| 解码与导出 | 预览最长边 2048，导出调用携带同一选区及 1320 × 2120，采用 CROP_FIRST |
| 原生资源 | 编码成功和失败均释放 PixelMap 与 ImagePacker，清理异常仍继续释放 packer |
| 图库提交 | 创建资源和图片字节同一变更请求提交，失败向上抛出并释放 helper，空数据拒绝 |

core 测试与服务测试导入实际源码经 SDK TypeScript 转译的 JavaScript。NetworkKit、ImageKit、MediaLibraryKit 使用测试替身。该结果覆盖参数契约、逻辑、清理和错误传播，原生编解码器及系统授权的真实行为需要真机验收。

## 只读 API 验证

- 热门接口 HTTP 200，24 张壁纸，通过实际 core.validatePage。
- nature 关键词最新搜索 HTTP 200，24 张壁纸，通过实际 core.validatePage。
- pangdunqing 公开收藏集 HTTP 200，0 个，通过实际 core.validateCollections。
- 官方图片 CDN 的范围请求 HTTP 206，Content-Type 为 image/jpeg，成功读取 65,536 字节。

原始响应位于任务目录 work/discover.json、work/search.json、work/collections.json，摘要位于 work/api-smoke.json。
复核实际契约可执行以下命令，临时验证材料保留在任务目录，后续远端数据可能变化。

```sh
'/Applications/DevEco-Studio.app/Contents/tools/node/bin/node' /Users/pangdun/Documents/Codex/2026-11-17/pura-wallpaper/work/validate-live.mjs
```

## 静态核对

- 真实入口为 EntryAbility → Index → HomeView、SettingsView、PreviewView，业务网络与原生服务均被入口引用并参与原生编译。
- 异步列表使用请求代次保护，避免过期响应覆盖当前搜索、Tab 或收藏集。
- 页面退出取消图片请求。解码结束后核对页面有效性，导出期间退出延后释放图像资源。
- 设置和图库保存期间拦截系统返回，确保凭据提交和保存状态完整。
- 导出完成后显示系统 SaveButton，选区修改立即使旧导出失效。图片字节通过 MediaAssetChangeRequest.addResource 交由系统提交。
- 权限清单、源码和最终包已核对。凭据通过手机内输入与系统安全存储管理。
- 深浅色使用系统资源目录，窗口宽度控制网格与预览布局。以上界面结论来自代码核查。

## 待真机验收

| 项目 | 当前状态 |
| --- | --- |
| 设备签名与安装 | 已安装分级筛选版 1.0.3 / 4，系统包管理器确认，启动成功 |
| 私有收藏鉴权 | 已复用设备保存的 Token，NSFW 搜索正常；可访问收藏集当前包含 0 张壁纸 |
| 深浅色、字体和完整布局 | 待真机交互及截图 |
| 折叠与旋转 | 待 Pura X 实际窗口变化验收 |
| 实际裁剪导出的像素 | mock 参数验证通过，待 ImageKit 真机导出核对 |
| 系统 SaveButton、取消与失败 | 逻辑已实现，待系统授权交互 |
| 图库文件与壁纸效果 | 待用户授权真机保存及系统设置 |

## 交付统计

ArkTS 生产源码新增 1,214 行，去除空行和整行注释后为 1,122 行。
源码通过显式的页面、契约、网络、安全存储和图片服务组织实现，未以行数增加额外功能。


初版 1.0.0 源码内容 SHA-256 为 cc6d4e8d51833d86488fb37f1bff6a7788ac06b7b8ef2945f2108fef3f3fca67。
未签名 HAP SHA-256 为 509f3c98cd59292a8e00b79ddc0950908add0646fc7fdfdd3017d9be9d0ec5d2。

## 真机安装与启动追加验证

用户于同日明确要求直接安装到真机。通过现有 HDC 连接核对 VDE-AL00 与 API 26。
使用已登录 HoKit 的“一键签装”流程完成新包名的设备授权、签名及安装，11:52:11 界面日志显示安装成功。
系统 bm dump 确认 com.pangdun.purawallpaper、versionName 1.0.0、versionCode 1、enabled 为 true。
aa start 返回 start ability successfully，随后应用进程存在，实际截图确认映壁主页和真实壁纸缩略图已显示。
实际截图尺寸为 1320 × 2120。

证据位于任务目录 work/installed-package.txt、work/hokit-install-state.png、work/pura-wallpaper-start.jpeg 和 work/pura-wallpaper-start-final.jpeg。
已签名包位于任务 outputs/pura-wallpaper-1.0.0-signed.hap，SHA-256 为 318c924f94568b0a2571b60f2b57724e776379186b6f7b8fcf4197283265c156。

本次追加验证覆盖签名、安装与启动。私有收藏、裁剪导出、图库写入和折叠/旋转等场景继续保留原待验收状态。

## 1.0.1 首页布局修正与真机验收

用户截图明确指出顶部控件占用过大、上下白色区域割裂、中央列表高度不足。
本轮仅调整 HomeView、Index 的布局与安全区背景、EntryAbility 的系统栏颜色，以及版本配置。

- 标题和栏目切换合并为一行，搜索框高度 40vp，组间距 8vp，去掉 Search 的默认外边距。
- 壁纸使用原生 WaterFlow，按图片比例显示，卡片宽度由实际可用宽度和列数计算，真机核对 8 张可见图片均处于各自卡片水平边界内。
- 顶部系统栏跟随页面颜色，根背景通过 expandSafeArea 衔接上下系统区域，真机截图确认底部白色区域已衔接。
- 1320 × 2120 实际屏幕的列表边界为 [36,549][1284,2036]，高度 1487px。与初版截图中约 1067px 的可视区相比，增加约 420px，约 39%。
- 设置按钮文字完整显示，发现、收藏集、设置、热门、最新、刷新均可见。
- 真实滑动后壁纸条目及位置变化，列表边界保持一致，已完成反向滑动。
- 原生 SDK 26 release 构建成功，已有 23 项自动检查通过。检查器对原生 .ets 文件返回空发现，样式验收以真机截图及 UI 树为依据。
- 系统包管理器确认 com.pangdun.purawallpaper，1.0.1 / versionCode 2，覆盖安装和启动成功。

本轮 ArkTS 源码增加 35 行、删除 31 行，净增 4 行，当前生产源码 1218 行。

证据位于任务 work/ 目录中的 layout-build-final.log、layout-tests.log、layout-installed-package.txt、pura-layout-final.jpeg、pura-layout-final.json、layout-geometry.json 与 layout-scroll-result.json。
本轮未执行私有收藏、图库写入、裁剪导出或折叠/旋转的完整验收。

当前 1.0.1 源码 SHA-256 为 592b6822f75fd636bd7689da71056a0b7a0af7c1838d8b3c2a1f1766e92f3318。
当前已签名 HAP SHA-256 为 e7833751d7e94f67135419ae92613129e2680c6f2d72bf6770ffc89ad510c17f。

## 1.0.2 中性灰与原生底部沉浸

用户要求底部导航指示条区域沉浸、采用简单灰底，并使用 ui-ux-pro-max 优化和鸿蒙原生能力。
按该技能检索画廊中性色彩及移动端手势/触控建议，实现采用 ArkUI 和系统窗口 API。

### 实现与依据

- 浅色背景 #F2F2F2，白色控件表面，正文 #1A1A1A，辅助文字 #686868，强调色 #333333。深色使用对应中性灰资源。
- 使用 Window.setImmersiveModeEnabledState(true) 启用原生沉浸布局。
- 使用 Window.setSpecificSystemBarEnabled('navigationIndicator', false, false) 隐藏底部导航指示条。
- Root Stack 使用 expandSafeArea 扩展到底边。通过 getWindowAvoidArea(TYPE_SYSTEM) 和显示密度获取顶部避让尺寸，监听 avoidAreaChange，并在窗口销毁时解除该监听。
- 颜色与正文/辅助文字/强调文字的对比度均达到 4.5∶1，浅色辅助文字与背景实际比值 4.98∶1，深色对应资源静态检查通过。

官方 API 依据见 [系统栏类型](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-window-t) 与 [安全区扩展](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-expand-safe-area)。

### 实际验证

- SDK 26 release 构建成功，既有查询、分页、网络、图片选区及资源清理等 23 项自动检查通过。
- 系统包管理器确认 com.pangdun.purawallpaper、versionName 1.0.2、versionCode 3，覆盖安装和启动成功。
- 1320 × 2120 当前真机截图确认背景为中性灰，底部导航指示条已隐藏，壁纸内容延伸到底边。
- UI 树中 WaterFlow 边界为 [36,549][1284,2120]，高度 1571px，比 1.0.1 的 1487px 增加 84px。发现、收藏集、设置、热门、最新、刷新及应用标题均完整位于顶部系统安全区以下。
- 8 张可见图片的水平边界均位于各自 FlowItem 内。
- 从屏幕底部上滑后，UI 树确认当前窗口为 com.ohos.sceneboard，返回桌面手势生效。随后重新启动应用，截图确认指示条隐藏状态保持。
- 本轮未切换系统深色模式、未执行图库写入或完整裁剪验收，继续保留相关验收项。

原始证据位于任务 work/ 中的 gray-immersive-build-final.log、gray-immersive-tests.log、gray-installed-package.txt、pura-gray-final.jpeg、pura-gray-final.json、gray-immersive-geometry.json、gray-home-gesture-result.json、pura-gray-resumed.jpeg 与 gray-contrast.json。

本轮 ArkTS 增加 33 行、删除 7 行，净增 26 行。当前生产 ArkTS 源码 1244 行。
当前生产源码及资源 SHA-256 为 aae7863bfc3bba411ce881aa7b445c637ebac1926a34b97504db50fee72c505f。
当前已签名 HAP SHA-256 为 511f0083807a1c1102a8c74ff696dd180a024405631e311e5519b5b144ffd0bd。

## 1.0.3 Wallhaven 分级显示与筛选

用户要求带入 cc 数据源分级及分级筛选，并已在应用内保存 Token。
官方文档定义 purity 为 SFW / Sketchy / NSFW 的三位开关，NSFW 需要有效 API Key，收藏集壁纸也接受 purity 参数。[Wallhaven API](https://wallhaven.cc/help/api)

### 实现

- 壁纸模型保留接口 purity 字段，卡片和预览页显示 SFW、Sketchy、NSFW。缺少旧字段的数据继续兼容，未知分级会报告数据格式异常。
- 原有筛选行新增三档多选，默认 100，至少保留一档，支持七种非空组合。
- 搜索、关键词、排序和继续分页均携带相同 purity，收藏集壁纸请求也携带当前选择。
- NSFW 使用已保存 Token，无 Token 时禁用该档。清除 Token 后移除 NSFW 选择，避免旧鉴权结果留在列表中。
- Token 继续通过系统安全存储及 X-API-Key 请求头使用，界面仅读取是否存在凭据的状态。
- 使用 ArkUI accessibilitySelected 提供筛选选中状态，分级文字进入卡片可访问描述。
- 空组合 000 在当前公共 API 实测回退 SFW。本应用选择保留最后一档，避免界面出现无选中分级但仍收到 SFW 数据的状态。

### 验证结果

- SDK 26 release 编译通过，27 项自动检查通过，其中新增 4 项覆盖七种组合、参数边界、最少一档、分级元数据、无 Key 拒绝 NSFW、带 Key 的搜索/收藏集分页和 Key 清除后的拒绝。
- 公共 API purity=100 和 purity=010 均 HTTP 200，分别返回 24 张 sfw、24 张 sketchy。
- 真机检测已保存 Token，NSFW 控件启用。实际切换后，Sketchy 的 4 个可见分级标签均匹配，NSFW 的 3 个可见标签均匹配，恢复 SFW 后的 6 个可见标签均匹配。
- 收藏集入口返回 1 个可访问集合，其壁纸总数为 0。NSFW 筛选请求成功返回空结果，界面显示暂无壁纸。
- 从真实卡片进入预览页，SFW 标记显示在顶部安全区域内，边界为 [753,178][836,224]。检查后已返回列表。
- 当前设备确认应用 1.0.3 / versionCode 4，默认 SFW，截图核对新增分级控件位于既有筛选行，卡片分级显示完整。

证据位于任务 work/ 中的 purity-build-final.log、purity-tests.log、purity-installed-package.txt、purity-ui-results.json、purity-collection-results.json、purity-preview-results.json、purity-public-smoke.json 与 pura-purity-sfw.jpeg。原始界面树和临时核对脚本保留在同一目录。

本轮 ArkTS 增加 88 行、删除 16 行，净增 72 行；当前生产源码 1316 行。
当前生产源码与资源 SHA-256 为 3c710384a76557a3acbddde4cb5fb685e2508039c085937ecd192b14313b3d40。
当前已签名 HAP SHA-256 为 565af943d3a23514695289feb18b41a0ac6900f97d20a7133eb6c88e3c18e9eb。

## 1.0.4 简约图标与统一缩略图

用户要求图标简约、风格类似 Cuto，并询问后续图片变成瀑布流的原因。核对旧实现，Image.aspectRatio 使用原图宽高比并限制在 0.65 到 1.7，横图、方图和竖图会形成不同卡片高度。

### 实现

- 图标采用黑底白色画框和单个折角，更新 AppScope 和 entry 中的 app_icon.png。
- 首页 Image.aspectRatio 固定为 1.7，ImageFit.Cover 填充，所有搜索结果及后续分页复用同一构建器。原图尺寸仍由接口模型传递给原生预览与导出。
- 继续使用原生 WaterFlow，卡片等高后形成整齐双列。
- ArkTS 改动为增加 2 行、删除 2 行，净增 0 行。生产 ArkTS 共 1316 行。本轮通过资源及布局属性实现，不增加额外抽象。

### 构建与安装

- SDK 26 release 构建成功，27 项既有自动检查通过。
- 已签名 HAP 的 ZIP 完整性检查通过，module.json 确认包名 com.pangdun.purawallpaper、1.0.4、versionCode 5。编译产物包含新的黑白图标资源，已提取检查。
- HDC 覆盖安装返回 install bundle successfully，系统 bm dump 确认实际安装版本 1.0.4 / versionCode 5。

证据位于任务 work/ 的 icon-uniform-build.log、icon-uniform-tests.log、icon-uniform-installed-package.txt 和 compiled-app-icon-1.0.4.png。

### 真机缩略图检查

- 已在原始 1320 × 2120 真机视口检查首页和 4 次向后滚动，共核对 30 张不同壁纸，覆盖后续分页。
- 5 次 UI 树中完整可见缩略图均为 609 × 358px，比例约 1.701，同一列宽下图像高度一致。各次分别有 4、6、4、6、4 张完整图像进入尺寸断言。
- 实际原图尺寸包含 2304 × 3072、2972 × 3559 的竖图、3840 × 3840 的方图，以及多种横图，缩略图均使用统一比例。
- 初始与后续分页截图已目视核对，卡片排布整齐，灰底及底部沉浸区域正常。

原始证据位于任务 work/ 的 icon-uniform-device-results.json、icon-uniform-device-check.log、pura-uniform-initial.jpeg 和 pura-uniform-later.jpeg。

本轮生产源码及资源 SHA-256 为 81bd63b55765cb7554f27299e6692430eee7c20e8f09e1503e2902d9805b730c。
已签名 HAP SHA-256 为 f187de33c38dde15d7dce6daca6373d4d945cb27f2ed584daa24d03821c273ba。

已返回发现首页并确认 SFW 选中及真实结果加载。桌面当前可检查页面中未定位到映壁图标，桌面缓存刷新尚未目视确认。图标已完成源资源、HAP 编译资源和实际安装版本核对。

## 1.0.5 启动状态栏闪动修正

用户反馈打开应用时顶部状态栏闪动。旧启动流程调用 setImmersiveModeEnabledState，再通过 AppStorage 和窗口避让监听向根组件增加顶部内边距。该流程在启动期间同时改变窗口布局和页面补偿。

### 实现与依据

- EntryAbility 在加载页面前并行配置系统栏颜色、状态栏显示和底部导航指示条隐藏，显式关闭属性变化动画。
- Index 顶部使用 ArkUI 系统安全区自动避让，移除启动时沉浸布局切换、手动顶部补偿及其监听。背景及底部内容继续使用 expandSafeArea。
- 本次明确保留顶部状态栏显示，沿用已有页面效果。
- 新增 tests/window.test.mjs，直接从实际 EntryAbility 源码转译，覆盖窗口配置全部完成后才加载内容、深浅色更新与窗口销毁、窗口服务失败时继续加载页面。

系统栏接口及安全区依据见 [Window API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/arkts-apis-window-window/) 和 [安全区扩展](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-expand-safe-area)。

### 验证

- SDK 26 release 编译成功，既有 27 项和新增 3 项窗口回归全部通过，共 30 项。
- 已签名 HAP 完整性检查通过，HDC 覆盖安装成功，系统包管理器与安装包均确认 1.0.5 / versionCode 6。
- 真机进行三次冷启动和一次后台恢复采样，共 108 张画面，99 张显示应用状态栏，采样中时间文字持续可见，顶部布局稳定。后台恢复前后应用 PID 均为 26363。
- 采样间隔实际为 243 到 488ms。2026-11-17 用户从桌面重新打开实机应用，反馈“已经不闪了”，补充确认启动瞬间的目视效果。
- UI 树确认标题位于 [36,157][168,234]，列表仍为 [36,549][1284,2120]，高度 1571px，原始设备视口保持 1320 × 2120。
- 原图裁剪、图库写入及折叠/旋转完整验收继续沿用既有记录中的待验收状态。

证据位于任务 work/ 的 startup-build.log、startup-tests.log、startup-installed-package.txt、startup-layout-result.json、startup-sampling-results.json 及 startup-after-1、startup-after-2、startup-after-3、startup-warm-1 目录。画面、计时和临时脚本均位于源码目录外。

ArkTS 生产源码增加 10 行、删除 29 行，净减 19 行，当前共 1297 行。本轮通过原生安全区消除手动补偿，代码规模随重复状态及监听的移除而缩小。

本轮生产源码与资源 SHA-256 为 f2c279e9aaace14ac13f4c1c8b3572a260237b64ba984fd9c6426045ec8e1053。
已签名 HAP SHA-256 为 b852adc2ce35bf534358be0d17ce5be81b92eaee5068a1a493f0b50441378c50。

## 1.0.6 机型识别、原生返回图标、开屏与系统主题

用户要求机型和壁纸尺寸自动对应当前设备、返回箭头更精细、冷启动图标遮挡消除，以及自动跟随系统深浅色。用户随后指出上滑进入后台时顶部状态栏问题最明显，提供多任务截图。

### 实现

- DeviceProfile 使用 BasicServicesKit 的 deviceInfo.marketName，空名称回退 productModel。Display API 提供当前活动默认屏幕的物理像素，入口监听 change 并在配置变化和恢复前台时核对尺寸。
- 预览卡片、设置说明、预览画框和导出共同读取机型及尺寸。显示尺寸变化会使旧待保存数据失效，导出使用目标尺寸快照，异步结果与当前尺寸匹配后才进入待保存状态。
- cropRectangle 增加显式目标参数，按设备比例计算并将选区四舍五入到整数像素，覆盖横屏、竖屏、方形及互质宽高。省略目标参数的既有调用保持原有数学契约。
- 原生 ImageKit 导出后读取 PixelMap 尺寸，确认与当前屏幕像素完全一致才编码。图库文件名采用 Wallhaven-编号-时间，不再包含固定机型。
- BackButton 通过 SymbolGlyph 的 sys.symbol.chevron_backward 显示原生箭头，44vp 触控高度，覆盖预览、原图、设置与收藏详情的返回入口。
- 启动图标使用全透明 32 × 32 PNG，启动背景继续采用 base / dark 的灰色资源。HAP 中已核对透明通道全部为 0，桌面 app_icon 与 1.0.5 编译资源一致。
- COLOR_MODE_NOT_SET 跟随系统，系统栏文字按有效颜色模式选择。冷启动完成前跳过前台重复初始化，同色属性合并写入。未指定的颜色模式会读取实际资源模式。
- 系统栏背景改为透明，由页面自身绘制灰底。保留原生安全区避让、底部指示条隐藏和底部内容延伸。

原生能力依据见 [Display API](https://developer.huawei.com/consumer/en/doc/doccenter-references/api/js-apis-display)、[SymbolGlyph](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph)、[启动页配置](https://developer.huawei.com/consumer/en/doc/HarmonyOS-Guides/launch-page-config/) 和 [深浅色适配](https://developer.huawei.com/consumer/en/doc/best-practices/bpta-dark-mode-adaptation)。

### 自动检查与原生构建

- SDK 26 release 构建成功，40 项自动检查通过。新增覆盖机型名称及回退、屏幕变化、显示监听释放、不同设备的裁剪比例、非法目标、原生输出尺寸核对、无效原生尺寸时的资源清理、部分配置和重复系统栏初始化。
- 原有图库文件名断言 /^Wallhaven-abc123-PuraX-/ 更新为 /^Wallhaven-abc123-\d+$/，依据为本轮适配其他机型的要求。图库提交顺序、完整数据和资源释放断言保留。
- HAP 完整性检查通过，覆盖安装成功，实际系统包管理器确认 com.pangdun.purawallpaper、1.0.6 / versionCode 7。

### 真机结果

- 自动显示 HUAWEI Pura X、1320 × 2120。原生裁剪、解码尺寸验证与 JPEG 编码成功，界面进入系统保存按钮状态。本轮未点击保存按钮写入图库。
- 真机系统浅色背景像素为 [242,242,242]，深色为 [23,23,23]。深浅色切换后，当前机型及已生成待保存壁纸保留。已恢复原始设置，全天深色关闭、定时深色开启。
- 返回箭头已在真机预览页核对，使用原生 SymbolGlyph，机型名称和像素尺寸完整显示。
- 初次冷启动验收后用户仍反馈状态栏问题。用户补充上滑后台场景后，定位到系统栏不透明灰底在后台卡片之外残留，增加实际底部上滑和悬停检查。
- 修正后的上滑悬停画面中，顶部采样由应用内 [242,242,242] 变为桌面背景 [25,56,87]，灰条已消失。使用 uinput 进行底部移动及 1800ms 悬停，保留中途和释放后的图像。瞬时闪动的用户复核仍待回复。
- 其他机型与折叠/旋转尚无实际设备验收，当前通过模拟不同物理尺寸验证算法和原生接口参数。

证据位于任务 work/ 的 device-theme-build-final.log、device-theme-tests-final.log、device-theme-installed-package.txt、device-light-final-result.json、device-theme-final-results.json、device-theme-verification-summary.json、recents-hold-result.json 及 pura-hold-during-top.png。早期采样存在用户页面切换，最终上滑检查使用显式悬停手势。原始截图和临时脚本保留在源码目录外。

ArkTS 增加 177 行、删除 45 行，净增 132 行，当前生产源码 1429 行。实现复用现有裁剪、图片会话与页面状态，通过两个有明确职责的原生组件/服务支持本轮功能。

本轮生产源码与资源 SHA-256 为 9a617e4478afa18d85221b4eefd3f8dc8fd04dd9dcc3d693bd2be85b0339e828。
已签名 HAP SHA-256 为 db9d4e1396b9236e0074b77a7d3e7b12819c54dcded1c07496b80c127c075ef7。

## 1.0.7 编辑图片点击全屏裁剪预览

用户要求编辑壁纸页面点击图片时全屏预览裁切图片。

- PreviewView 的单击加入现有互斥手势组，与拖动、双指缩放共同识别。
- 通过原生 bindContentCover 和 ALPHA 转场显示黑色背景的全屏裁剪视口，Image 复用既有预览 PixelMap，四个显示几何函数接受不同视口尺寸，底层裁剪参数保持一致。
- 全屏画布使用 ignoreLayoutSafeArea 扩展系统区域。返回按钮的顶部避让在 1.0.8 真机复测中进一步修正，详见下节。
- 点击全屏图片、裁剪预览按钮或系统返回关闭全屏。全屏状态通过 Link 同步到入口，入口返回优先关闭全屏并保留当前编辑页及所选图片。
- 显示目标变化或编辑页销毁时关闭全屏，沿用现有图片会话生命周期。

API 依据见 [全屏模态转场](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-modal-transition) 和 [组合手势](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-combined-gestures)。

### 检查结果

- SDK 26 release 编译成功，40 项既有自动检查全部通过。
- 仓库外临时脚本从实际 PreviewView 提取 selection 与四个显示几何函数，通过 SDK TypeScript 转译。对 3 种原图、3 种目标、4 档缩放及 9 组中心位置共 324 组参数，编辑与全屏的归一化图像尺寸和偏移一致，误差小于 1e-9。默认视口参数与原调用结果一致。
- 从实际 Index 提取 onBackPress，验证全屏关闭后仍处于编辑页、保留所选图片，以及原有编辑页返回首页和首页返回行为。此项为逻辑检查。
- 已签名并通过 HDC 覆盖安装 1.0.7 / versionCode 8。
- 当时真机交互检查未完成。后续确认 HDC 断连后旧检查脚本读到了历史界面文件，相关失败记录不能用于判断当前窗口前台状态。已修正临时采样脚本并重连同一设备，1.0.8 的完整复测结果见下节。

证据位于任务 work/ 的 full-crop-build.log、full-crop-tests.log、full-crop-geometry-result.json、full-crop-device-check.log 与 full-crop-window-after-start.txt。临时脚本及 UI 树保留在源码目录外。

本轮 ArkTS 增加 69 行、删除 21 行，净增 48 行，当前生产源码 1477 行。
生产源码及资源 SHA-256 为 56243bc653f9b387dd2872cc486edf05160900db4b8f59a0989b18aa9ef20a26。
已签名 HAP SHA-256 为 946cba3d96037f1010d04f3c2b6db4e2a58e4d065a87676a1978f235508e9002。

## 1.0.8 全屏裁剪预览真机复测与顶部避让

本轮延续用户要求的编辑图片点击全屏裁剪预览，用户已暂停手机操作以完成检查。

### 修正

- 全屏返回按钮原先与顶部状态栏重叠。通过当前 UIAbilityContext 的 WindowStage 获取主窗口，读取 TYPE_SYSTEM 避让区域，将顶部物理像素转换为 vp 后用于按钮间距。
- 全屏图片保留原生 ignoreLayoutSafeArea，当前窗口系统栏样式沿用既有实现。按钮采用已有 BackButton 和 SymbolGlyph。
- 临时真机采样脚本逐次使用唯一远端文件名、接收前移除旧本地文件，并校验 HDC 连接错误及文件接收结果。重连后使用新采样完成检查。

### 检查结果

- SDK 26 release 编译成功，40 项既有自动检查通过，0 项失败及跳过。编译后使用既有匹配设备的签名覆盖安装，系统 bm dump 确认 1.0.8 / versionCode 9。
- 324 组实际裁剪显示几何检查通过。入口系统返回逻辑保留当前编辑页和所选图片，原有页面返回行为检查通过。
- 真机编辑区为 [350,315][971,1312]，全屏图片覆盖物理屏幕 [0,0][1320,2120]。系统 UI 树将该节点裁剪为 [0,117][1320,2120]，画面比较使用完整物理视口。
- 在 2.2× 缩放并拖动裁剪后进入全屏，两处选区按相同尺寸比较，避开返回按钮及边缘区域的平均 RGB 绝对差为 1.18 / 255。
- 分别通过点击图片、系统返回及全屏返回按钮退出，均回到原编辑页，保留 2.2× 缩放与生成后的系统保存按钮。全屏返回按钮位于顶部 117px 避让区域之后，实际触控高度保持 44vp。
- 拖动图片保持编辑态。原生双指操作使缩放从 2.2× 变为 3.0×，保持编辑态。检查后通过原有重置按钮恢复默认裁剪参数。
- 本轮生成了原生 JPEG，并检查生成状态保留。图库写入、其他机型及折叠/旋转的完整验收继续待相应动态检查。上滑后台瞬时闪动仍待用户复核。

证据位于任务 work/ 的 full-crop-build-final.log、full-crop-tests-final.log、full-crop-geometry-result.json、full-crop-device-result.json、full-crop-pinch-result.json、full-crop-installed-package-final.txt、pura-full-crop-editor.jpeg 及 pura-full-crop-fullscreen.jpeg。原始 UI 树和临时脚本保留在源码工程之外。

相对本次功能开始前的 1.0.6，生产 ArkTS 有效代码增加 67 行、删除 13 行，净增 54 行，当前有效代码 1375 行。此处按非空且非纯注释行统计，与前节文件总行数的口径不同。
生产源码及资源 SHA-256 为 b9177147f46557340d6e75c250b40ced30077c4d79be888a4d42c33b0f8bd184。
已签名 HAP SHA-256 为 c612b005555e6b199a4cff5a226ab536540fdd36d33bfcf4f09d0ac18d93e048。

## 1.0.9 设置入口图标

用户要求设置使用图标以节省空间、改善页面视觉。HomeView 的原有设置按钮改为 22fp 线框齿轮 SymbolGlyph，使用 sys.symbol.gearshape。宽度由 56vp 缩至 44vp，触控区域为 44 × 44vp，沿用 accent 主题资源和 onSettings 回调。按钮无障碍名称为“设置”，子图标从独立读屏焦点中排除。

- SDK 26 release 编译成功，40 项既有自动检查通过，0 项失败及跳过。使用既有匹配签名覆盖安装成功，系统包管理器确认 1.0.9 / versionCode 10。
- Pura X 真机按钮边界为 [1152, 129, 1284, 261]，实际点击区域为 132 × 132px，按设备密度换算为 44 × 44vp。按钮内包含 SymbolGlyph，视觉文字标签已移除，截图确认线框齿轮清晰。
- 发现页和收藏集均可通过图标进入设置，系统返回恢复对应页面，最终恢复发现页。检查只读取设置页面，未提交保存。
- 颜色复用既有系统主题资源，本轮未切换系统深浅色。其他机型、图库写入及后台瞬时闪动沿用前节待验收状态。

官方依据见 [SymbolGlyph](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-symbolglyph/)、[gearshape 系统图标示例](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sample/) 和 [无障碍属性](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-accessibility)。

证据位于任务 work/ 的 settings-icon-build.log、settings-icon-tests.log、settings-icon-device.log、settings-icon-device-result.json、settings-icon-installed-package.txt 与 pura-settings-icon-home.jpeg。临时脚本位于源码工程之外，设置页的原始临时界面树读取后已清理。

相对 1.0.8，生产 ArkTS 有效代码增加 5 行、删除 2 行，净增 3 行。生产源码及资源 SHA-256 为 74fb82a93471ec910317c63d350cd40526f8a704b4698acb0d1c2bba7be44e04。
已签名 HAP SHA-256 为 09a4e8d14f90ddb967716f36eecdc8e6dae42b0d81cd43917293bc13bdf654ad。
