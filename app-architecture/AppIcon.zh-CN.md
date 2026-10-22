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
