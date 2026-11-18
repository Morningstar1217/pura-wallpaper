# 映壁首版规格

## 目标与确认记录

2026-11-17 用户确认以 ArkTS / ArkUI 原生应用实现 Wallhaven 浏览、搜索、pangdunqing 收藏集、全屏预览、按 Pura X 比例裁剪和保存图库，最后由用户在系统图库设置壁纸。
设备截图为 Pura X VDE-AL00、HarmonyOS 7.0.0.111、API 26、arm64-v8a、1320 × 2120。
应用暂名“映壁”，独立目录与 bundleName com.pangdun.purawallpaper。

## 技术与入口

HarmonyOS SDK 26.0.0.105，Stage UIAbility，ArkUI 原生组件，ImageKit，NetworkKit，AssetStoreKit，MediaLibraryKit。
entry/src/main/ets/pages/Index.ets 为入口，components 为原生页面组件，core 为可单测契约与裁剪算法，services 为网络、凭据、图像和图库访问。
不依赖远程业务后台。接口直连 https://wallhaven.cc/api/v1/，图片仅接受 Wallhaven 官方 HTTPS 图片域名。

## 功能与验收

- 发现支持热门、最新、关键字搜索、分页、加载/空/失败/重试状态，重载时阻止旧响应覆盖新查询。
- 收藏读取固定用户 pangdunqing 的公开收藏集。填写 API Key 后读取该用户可访问的收藏集，显示空与鉴权失败状态。
- 详情载入原图并通过原生 PixelMap 显示，支持原图查看及 Pura X 裁剪预览。
- 裁剪目标固定为截图所示主屏 1320 × 2120。原生拖动、缩放及滑块控制选区，原生解码器按同一选区导出 JPEG。外屏只保证普通窗口自适应，未确认其壁纸尺寸。
- 保存使用系统 SaveButton 临时授权，预先生成待保存图片，获授权后立即以原生媒体变更请求提交创建及完整图片数据。仅系统提交成功后反馈成功。
- Token 在手机内填写，保存至 AssetStoreKit，使用 X-API-Key 请求头，清除时删除安全存储记录。源码、日志和构建包不嵌入个人 Token。
- 支持系统深浅色及按可用窗口宽度变化的网格和预览布局，内外屏切换与旋转通过实际窗口尺寸适配。

## 命令

```sh
node scripts/build.mjs
node --test tests/core.test.mjs tests/image.test.mjs tests/window.test.mjs
```

构建脚本从本机 DevEco Studio 取 Node、Java、OHPM、Hvigor、SDK。DEVECO_HOME 可指定 DevEco Contents 路径。

## 实现风格

职责放在直接使用它的模块。类型显式，异常使用能定位用户操作的反馈，异步操作使用有效期或请求序号保护。

```ts
export function clamp(value: number, minimum: number, maximum: number): number {
  return Math.max(minimum, Math.min(value, maximum));
}
```

## 验证与边界

构建使用真实 ArkTS 编译器。Node 测试导入从原始无平台依赖 core 模块转译的代码，覆盖查询编码、图片域名、裁剪边界和分页契约。
公共 API 进行只读请求。2026-11-17 用户追加授权直接安装真机，已完成 HoKit 签名、安装和启动截图确认。实际图库写入及完整交互验收需后续进行。
交付源项目、未签名 HAP、当前设备的已签名 HAP 与测试记录。设备签名需匹配新 bundleName 的开发证书与 provisioning profile。

## 资料

- https://github.com/you-apps/WallYou （2026-11-17 GitHub API 查询 1487 星，Kotlin，GPL-3.0）
- https://github.com/Hash-Studios/Prism （679 星，Dart/Flutter，BSD-3-Clause，Wallhaven 数据接入参考）
- https://wallhaven.cc/help/api （X-API-Key、收藏集、每分钟 45 次限制）
- https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-basic-services-kit/js-apis-wallpaper.md （壁纸系统接口边界）

从零编写 ArkTS 实现，参考公开 API 契约。未拷贝以上项目的代码或素材。

## 首页布局追加要求

2026-11-17 用户要求减少上下留白，扩大中间滚动区域。1.0.1 合并标题与栏目切换，压缩搜索和筛选区，使用按比例的原生瀑布流，统一系统栏与底部安全区底色。已在原 1320 × 2120 真机视口检查实际图像及滚动。

## 灰底及底部沉浸追加要求

2026-11-17 用户要求使用 ui-ux-pro-max 优化，背景改为简单灰色，并通过原生鸿蒙 API 处理底部导航指示条区域。
1.0.2 使用中性灰资源、原生沉浸窗口及导航指示条显隐 API，顶部按系统安全区避让。当前真机列表铺到 2120px 屏幕底边，上滑回桌面及应用重新启动已检查。

## 分级追加要求

2026-11-17 用户要求引入 Wallhaven 分级及分级筛选，已有 Token。
1.0.3 显示 SFW、Sketchy、NSFW，三档可组合选择并用于搜索及收藏集分页。默认 SFW，至少保留一档，NSFW 复用系统安全存储中的有效 API Key。已通过真机三档搜索和预览分级显示检查。

## 图标及统一缩略图追加要求

2026-11-17 用户要求图标更简约、风格类似 Cuto，并指出后续壁纸变成瀑布流。旧实现按原图宽高比计算卡片高度，前几张横图比例接近，后续方图或竖图会产生高度差。
1.0.4 采用黑底白色画框图标，替换应用级与模块级图标资源。缩略图比例统一为 17∶10，通过原生 Image.aspectRatio(1.7) 和 ImageFit.Cover 渲染，首页与后续分页使用同一构建器。

## 启动顶部状态栏闪动修正

2026-11-17 用户反馈打开应用时顶部状态栏闪动。1.0.5 将顶部避让交由 ArkUI 系统安全区自动处理，移除启动时切换窗口沉浸布局及 AppStorage 顶部补偿。页面加载前并行配置状态栏显示、底部导航指示条隐藏及系统栏颜色，关闭属性变化动画。已完成三次冷启动和一次后台恢复采样，实际列表区域保持 [36,549][1284,2120]。

## 机型自适应、返回图标、开屏与系统主题

2026-11-17 用户要求自动获取当前机型以适配对应壁纸操作、精细化返回图标、去除冷启动开屏图标遮挡，以及自动跟随系统深浅色。后续指出上滑进入后台时顶部状态栏问题最明显，并提供多任务页面截图。

1.0.6 读取系统机型销售名称及当前默认活动屏幕的物理像素，屏幕变化会更新预览裁剪比例和 JPEG 输出尺寸。导出使用目标尺寸快照，目标变化后清除旧待保存结果，原生输出像素尺寸通过 PixelMap 信息校验。
返回按钮在发现收藏详情、预览、原图及设置中统一使用 SymbolGlyph 系统箭头和 44vp 触控高度。冷启动采用透明图标与系统深浅色灰底，桌面图标继续使用已有资源。
系统栏背景设为透明，灰底由页面绘制，页面加载前配置系统栏样式。前台恢复与重复颜色通知合并同模式的属性写入。浅色、深色资源由系统颜色模式自动选择。

## 点击裁剪图片全屏预览

2026-11-17 用户要求编辑壁纸页点击图片时全屏预览裁切图片。1.0.7 以原生 bindContentCover 呈现当前裁剪区域，复用现有预览 PixelMap 与相同的 cropRectangle、中心位置及缩放。全屏视口保持当前设备的裁剪比例并完整容纳选区。
单击、拖动和双指缩放使用 GestureGroup Exclusive。全屏点击图片、点击裁剪预览按钮或系统返回均关闭预览并保留编辑参数。页面返回先处理全屏状态，屏幕目标变化时关闭全屏预览并更新编辑尺寸。

1.0.8 真机复测修正全屏返回按钮的顶部间距，通过 Window.getWindowAvoidArea 读取系统避让区域并换算为 vp。图片画布延伸至屏幕边缘，返回按钮保持完整触控区域。已验证点击、拖动和双指缩放，以及全屏退出后的编辑状态保留。

## 设置入口图标

2026-11-17 用户要求设置使用图标表示，节省空间并改善页面视觉。1.0.9 将首页设置文字按钮改为 SymbolGlyph 的 sys.symbol.gearshape，22fp 线框图标、44 × 44vp 圆形点击区域，复用现有主题颜色及 onSettings 回调。无障碍名称沿用“设置”。
