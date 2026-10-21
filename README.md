# Revia — 原生 iOS

使用 SwiftUI + 系统 SQLite 构建的 Revia，使用 RxSwift / RxRelay 管理语音功能的异步状态；不需要 Node.js、Expo、CocoaPods 或开发服务器。iOS 17+，推荐 Xcode 26.3+。

## 运行

打开 `Revia.xcodeproj`，选择 Revia target，在 Signing & Capabilities 中选择自己的 Team。默认 Bundle Identifier 是 `com.jeffkann.revia.native`，可按需要修改。连接 iPhone 并启用开发者模式，选择手机后点击 Run。Debug / Release 都可以离线运行；SwiftUI 和业务代码均可在 Xcode 中打断点。

## 功能

- 三个 Tab：日历、今天、设置；今天页面返回前台或日期切换时更新。
- 点击日期进入当天内容；新增绿色背景、复习灰色背景，不显示类型标签。日历保留绿色新增点和灰色复习点。
- 支持任意语言的句子原文、可选释义和学习日期，允许补录、同日多句。
- 15 次固定复习：第 1、3、7、14、30 天；以第 5 次日期为锚点，随后每个日历月一次，共 10 次。月份没有对应日号时取月末，不改变后续月份的锚点日号。
- 没有完成状态、打卡或动态延期。从任意卡片删除会删除原句及全部复习日程。
- 数据保存在应用沙盒 Application Support/revia.db，退出/重启保留。没有云同步和导入导出。Expo Go、React Native App 和原生 App 的沙盒独立，句子不会自动迁移。卸载 App 会删除本地数据。

## 目录结构

```text
Revia/
  App/                    应用入口、Tab 与根导航
  Pages/                  日历、今天、日期详情、添加、设置
  Features/
    Memory/               复习日期规则与共享数据状态
    Speech/               语音生成、播放、文件缓存
    Localization/         语言偏好与本地化格式化
  Networking/             ElevenLabs API、请求与响应
  Data/                   SQLite 结构及读写
  Security/               Keychain 凭证保存
  Shared/                 通用组件与配色
  Resources/
    Assets.xcassets/      App 图标
    Localization/         英文、中文、日文字符串资源
ReviaTests/
  Integration/            日期、数据库、缓存集成测试
  Networking/             API 模拟与激活状态测试
  Localization/           语言及日期格式测试
```

目录与 Xcode 分组一一对应。所有源文件仍属于同一个 Revia target，无需额外模块导入。

在 Xcode 中按 Command-U 执行单元测试（选择已安装的模拟器或已配置签名的手机）。工程已包含共享 Scheme。

## ElevenLabs 语音

第三个 Tab「设置」中输入 ElevenLabs API Key，点击「验证并激活」。Key 安全保存在本机 Keychain（WhenUnlockedThisDeviceOnly），不写入 SQLite 或日志。修改/移除 Key 会立即停用生成；重新验证后恢复。验证调用 `/v1/user` 和分页 `/v2/voices`，需要 User/Voices 读取权限；真正合成还需要 Text to Speech 权限及足够额度，验证不会通过付费合成试音。

可从账户可用音色中选择，默认选择第一个。模型为 `eleven_multilingual_v2`，输出 `mp3_44100_128`。请求使用 HTTPS 和 `xi-api-key`；仅在保存勾选生成或播放本地缺失的语音时，将句子原文发送给 ElevenLabs。释义不发送。

激活 Key 且有可用音色时，添加页的「生成语音」默认勾选，可取消；未激活时禁用且不选中。句子先保存，生成失败弹窗提示，退出后可点击播放重试，不会重复添加句子。

音频位于 Application Support/Speech。SQLite 的 `audio_records` 保存句子、文本、文件名、音色、模型、版本和创建时间；文本/音色/模型/版本参与缓存键。播放优先读取当前音色缓存，文件缺失才生成。没有可用 Key 时仍可播放此句已有录音。切换音色后旧版本保留，文件实际总大小显示在设置页。删除句子会关联删除元数据并清理文件（相同文本共享的音频仅在最后一个引用删除时移除）。启动时清理中断操作留下的无引用 MP3。

RxSwift / RxRelay 6.10.2 通过 Swift Package Manager 引入，用于激活条件组合、验证和合成请求的异步链及取消。首次打开工程需要联网解析 Swift Package，之后 App 运行不依赖开发服务器。

测试包括日期/持久化、音频元数据和关联删除、缓存路径/占用、模拟 HTTP 验证/音色分页/错误响应；未包含真实 API Key，真实合成与扬声器播放需要在手机上配置 Key 后验证。

## 界面语言

设置 Tab 顶部可选择 English、中文（简体）或日本語，立即生效并保存在 UserDefaults，无需重启，也不会重建导航/清空表单/停止播放。首次启动选择设备首个支持的语言，其他语言回退为英文。

`Features/Localization/Localization.swift` 管理语言偏好与格式化，`Resources/Localization/` 下的 `en.lproj`、`zh-Hans.lproj`、`ja.lproj` 中的 `Localizable.strings` 包含三语文案。日期、星期、数量、存储容量以及应用自己的错误提示均按所选语言显示。学习日期仍按本地公历存储，复习规则不随界面语言变化。

界面采用“句子”“释义”“生成语音”等中性文案。界面语言不会翻译学习内容，也不会改变/重新生成已有音频。Swift 模型和接口统一使用 `text`；SQLite 仅保留旧 `japanese` 列名以兼容已有数据，实际可保存任意语言的句子；ElevenLabs Multilingual v2 根据原文生成语音。

验证：iOS Debug 与测试目标编译通过，12 项核心回归测试通过；所有三语资源键及格式占位符一致性检查通过。仍需在手机上检查三种语言的实际布局与即时切换交互。

本地化 key 统一使用简短英文 snake_case（如 `save_sentence`、`audio_storage`），不使用中文或完整句子作 key。三种语言使用同一组 key，格式占位符保留在翻译值中。新增文案时需同时补齐三语资源。
