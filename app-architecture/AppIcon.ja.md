# Revia アイコンと起動用リソース

[中文版](AppIcon.zh-CN.md) · [アプリ構成](Architecture.ja.md)

## 現在のリソース

内蔵の画像生成ツールで作成した1024×1024の不透明 PNG を iOS の共通 AppIcon として使います。元画像は正方形のままにし、外周の角丸は事前加工せず iOS のマスクに任せます。

暗い森林緑を背景に、ミント色の脳の経路と3つの光る記憶ノードを配置しています。起動画面は同じ画像のコピーを使います。アプリ内の光の移動は GIF ではなく SwiftUI Canvas の経路描画で、システム Launch Screen は静止画面です。

- アイコン：`Revia/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- 起動用画像：`Revia/Resources/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png`
- システム起動画面：`Revia/Resources/LaunchScreen.storyboard`
- アプリ内起動画面：`Revia/App/LaunchView.swift`
- 光の描画：`Revia/Shared/BrainCircuit.swift`

## 再利用可能な生成プロンプト

多言語の文章記憶アプリという位置付けの英語プロンプトを以下に残します。この説明の更新に伴い既存アイコンを再生成したわけではありません。

Use case: logo-brand. Asset type: final iOS app icon for a multilingual sentence and spaced-repetition memory app, Revia. Generate one square 1024x1024 opaque icon, full bleed edge-to-edge deep midnight charcoal / very dark forest-green background. Central iconic stylized brain made of a few bold elegant continuous mint-green neural paths, with three subtle luminous memory nodes connected into a gently recurring curved loop integrated into the brain folds, suggesting recall and memories strengthening over time. Sophisticated restrained minimal branding, crisp smooth silhouette, strong readability at 40px, large centered symbol occupying about 65 percent of canvas. Subtle dimensional depth, almost flat, refined soft light, clean negative space. No words, letters, numbers, borders, mockup, phone, drop shadow outside canvas, rounded outer corners, tiny details, realistic anatomy or pink flesh. Square image itself must have no corner masking; iOS will mask it. Keep the palette dark with clear mint accent, calm and thoughtful, not a busy AI circuitry illustration.
