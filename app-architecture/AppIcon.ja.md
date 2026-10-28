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

## テーマカラー別アイコン

内蔵 image_gen で元画像の色のみを編集し、脳の形・3つの記憶ノード・配置を維持しました。出力を1024×1024の不透明PNGへ正規化しています。標準の緑の原画像は変更しません。以下をiOS代替アイコンと設定プレビューに使います。

- `Revia/Resources/Assets.xcassets/AppIconOcean.appiconset/AppIconOcean.png`
- `Revia/Resources/Assets.xcassets/AppIconIris.appiconset/AppIconIris.png`
- `Revia/Resources/Assets.xcassets/AppIconClay.appiconset/AppIconClay.png`

### Generation prompts (built-in image_gen)

Base prompt: Use case: style-transfer. Edit target: the attached Revia app icon. Change ONLY the color palette to [PALETTE]. Preserve the exact brain silhouette, all path geometry, the three luminous nodes and their positions, scale, composition, shading, glow, and edge-to-edge square background of the original. No new details, no text, no border, no rounded outside corners. Final production iOS alternate app icon, 1024x1024 opaque PNG.

- Ocean palette: very dark midnight navy background; luminous icy blue/cyan neural paths and blue-white memory nodes.
- Iris palette: very dark midnight plum background; luminous lavender/lilac neural paths and violet-white memory nodes.
- Clay palette: very dark warm brown background; luminous soft apricot/terracotta neural paths and warm cream-white memory nodes.

## ニュートラルな起動リソース

全テーマ共通で `Revia/Resources/Assets.xcassets/LaunchNeutral.imageset/LaunchNeutral.png`（1024×1024・不透明PNG）を使います。内蔵 image_gen で元画像をニュートラルなダークグレー／シルバーホワイトへ編集しました。システム静的起動画面とアプリ内アニメーションにのみ使用し、ホーム画面のアプリアイコンは置き換えません。元のLaunchLogoリソースは保持しますが、起動画面からの参照は外しました。

Generation prompt (built-in image_gen): Use case: style-transfer. Edit target: existing Revia brain logo. Produce ONE neutral launch-screen image, changing ONLY colors: flat edge-to-edge solid charcoal gray background exactly #15171A, luminous soft white and neutral silver brain paths, three white memory nodes. No green, blue, purple, orange or other hue. Preserve the original brain silhouette, path geometry, node positions, proportions, composition, delicate depth and soft glow. No text, no border, no external corner mask. Full opaque square PNG, 1024x1024, suitable for the same single launch screen regardless of app theme.
