# Revia 图标与启动资源

[日本語版](AppIcon.ja.md) · [应用架构](Architecture.zh-CN.md)

## 现有资源

图标由内置图像生成工具生成，使用 1024×1024 的不透明 PNG，供 iOS 通用 AppIcon 使用。图片本身保持正方形，不预先裁切外部圆角，由 iOS 应用图标蒙版处理。

图案为深色森林绿背景上的薄荷绿脑形路径，包含三个发光记忆节点。启动页使用同一图标的资源副本；App 内的光流由 SwiftUI Canvas 路径绘制，不是 GIF，系统 Launch Screen 保持静态。

- App 图标：`Revia/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- 启动图标：`Revia/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png`
- 系统启动画面：`Revia/Resources/LaunchScreen.storyboard`
- App 内启动页：`Revia/App/LaunchView.swift`
- 光流绘制：`Revia/Shared/BrainCircuit.swift`

## 可复用生成提示词

以下保留英文生成提示词，定位为多语言句子记忆应用；更新说明不代表重新生成了现有图标。

Use case: logo-brand. Asset type: final iOS app icon for a multilingual sentence and spaced-repetition memory app, Revia. Generate one square 1024x1024 opaque icon, full bleed edge-to-edge deep midnight charcoal / very dark forest-green background. Central iconic stylized brain made of a few bold elegant continuous mint-green neural paths, with three subtle luminous memory nodes connected into a gently recurring curved loop integrated into the brain folds, suggesting recall and memories strengthening over time. Sophisticated restrained minimal branding, crisp smooth silhouette, strong readability at 40px, large centered symbol occupying about 65 percent of canvas. Subtle dimensional depth, almost flat, refined soft light, clean negative space. No words, letters, numbers, borders, mockup, phone, drop shadow outside canvas, rounded outer corners, tiny details, realistic anatomy or pink flesh. Square image itself must have no corner masking; iOS will mask it. Keep the palette dark with clear mint accent, calm and thoughtful, not a busy AI circuitry illustration.

## 主题色图标变体

通过内置 image_gen 编辑原图，仅调整配色，保留脑形、三个记忆节点与布局。输出规范为1024×1024不透明PNG。默认墨绿原图保持不变；以下资源供 iOS 备用图标与设置预览使用。

- `Revia/Resources/Assets.xcassets/AppIconOcean.appiconset/AppIconOcean.png`
- `Revia/Resources/Assets.xcassets/AppIconIris.appiconset/AppIconIris.png`
- `Revia/Resources/Assets.xcassets/AppIconClay.appiconset/AppIconClay.png`

### Generation prompts (built-in image_gen)

Base prompt: Use case: style-transfer. Edit target: the attached Revia app icon. Change ONLY the color palette to [PALETTE]. Preserve the exact brain silhouette, all path geometry, the three luminous nodes and their positions, scale, composition, shading, glow, and edge-to-edge square background of the original. No new details, no text, no border, no rounded outside corners. Final production iOS alternate app icon, 1024x1024 opaque PNG.

- Ocean palette: very dark midnight navy background; luminous icy blue/cyan neural paths and blue-white memory nodes.
- Iris palette: very dark midnight plum background; luminous lavender/lilac neural paths and violet-white memory nodes.
- Clay palette: very dark warm brown background; luminous soft apricot/terracotta neural paths and warm cream-white memory nodes.

## 中性启动资源

所有主题共用 `Revia/Resources/Assets.xcassets/LaunchNeutral.imageset/LaunchNeutral.png`（1024×1024、不透明PNG）。由内置 image_gen 基于原图编辑为中性深灰／银白配色，仅用于系统静态启动画面与App内光流动画，不替换桌面图标。原有LaunchLogo资源保留，但启动画面不再引用。

Generation prompt (built-in image_gen): Use case: style-transfer. Edit target: existing Revia brain logo. Produce ONE neutral launch-screen image, changing ONLY colors: flat edge-to-edge solid charcoal gray background exactly #15171A, luminous soft white and neutral silver brain paths, three white memory nodes. No green, blue, purple, orange or other hue. Preserve the original brain silhouette, path geometry, node positions, proportions, composition, delicate depth and soft glow. No text, no border, no external corner mask. Full opaque square PNG, 1024x1024, suitable for the same single launch screen regardless of app theme.
