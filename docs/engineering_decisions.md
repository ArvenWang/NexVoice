# NexVoice 工程决策记录

更新时间：2026-06-18

## 1. NexHub 复用边界

NexVoice 是独立新产品，不作为 NexHub 的功能模块开发。

NexHub 当前仓库完成度不适合整体复制：

- `SettingsWindowController.swift` 等 UI 文件过大，后续维护风险高。
- 旧业务包含划词、截图、Skill、知识库、网站、发布等大量 NexHub 专属能力，直接迁移会让 NexVoice 一开始就背上无关复杂度。
- NexHub 的正式工作仓库当前还有其他分支和未跟踪文件，不应作为直接改动来源。

本阶段只吸收以下思路，不复制整套业务代码：

- 菜单栏常驻 App 形态。
- 权限管理需要集中封装。
- API Key 必须进入 Keychain，不能进入 UserDefaults。
- AI Provider / Model / Base URL 需要配置化。
- 浮层和结果面板只借鉴可用视觉与交互，不复用 NexHub 业务逻辑；当前语音状态条参考 Typeless 截图的深色胶囊与细密竖条风格，并按 NexVoice 场景实现为 21 根细波形柱。
- 打包脚本可以参考，但 NexVoice 保持独立脚本和独立 Bundle。

## 2. 外部方案选择

已确认可用的成熟方案：

| 能力 | 方案 | 决策 |
| --- | --- | --- |
| 全局快捷键 | NexHub 同款 `NSEvent.addGlobalMonitorForEvents` / `addLocalMonitorForEvents` | 默认右 Alt；直接复用 NexHub 当前可运行的普通事件 monitor 模式，不使用 CGEvent tap 或轮询 |
| Keychain | `kishikawakatsumi/KeychainAccess` | 后续多 Provider 密钥管理优先评估引入，避免手写复杂 Keychain 封装 |
| WebSocket | Apple `URLSessionWebSocketTask` | 第一版 Provider 连接先用系统能力，等遇到稳定性瓶颈再评估 Network.framework 或第三方库 |
| 麦克风采集 | Apple `AVAudioEngine` + `AVAudioConverter` | 第一阶段只做 16k mono PCM 采集，不引入 AudioKit 这类重型音频框架 |
| 早期 ASR 验证 | Apple Speech / `SFSpeechRecognizer` | 已移除；当前不再申请 macOS 系统语音识别权限 |
| 默认本地 ASR | SenseVoice Small via sherpa-onnx | 中文、粤语和中英混合场景更值得优先验证；当前通过本地 Python venv + sherpa-onnx 调用 int8 模型，后续再收敛为内嵌 Swift framework |
| 本地 ASR 兜底 | WhisperKit `large-v3-v20240930_626MB` | SwiftPM 原生接入，Apple Silicon 友好；保留为兜底和质量对照 |
| 默认云端 ASR | 腾讯云实时语音识别大模型 | 速度优先；使用 `URLSessionWebSocketTask` 直连 WebSocket，固定 `16k_zh_en` 中英自动模型，按 200ms PCM 实时发送，结束后等待 `final=1` 再进入 AI 整理 |
| 当前输入框写入 | Apple `NSPasteboard` + `CGEvent` 模拟 `Command+V` | 当前目标是把最终文本写进用户已聚焦的输入框；粘贴方式对原生、网页、Electron 输入框覆盖更广，且避免第一版自研输入法 |
| 辅助功能权限 | Apple `AXIsProcessTrustedWithOptions` | 全局键盘事件接收和最终文本写回都依赖该权限；只打开设置页不会让 App 出现在辅助功能列表里，需要主动请求系统登记 |
| 语音状态浮层 | Typeless 截图 + NexHub `ToolbarVoiceInputControl` 波形方向 | 深色胶囊、21 根细竖条、中间高两侧低；NexVoice 不展示草稿文字，最终文本直接写入当前输入框 |
| 波形抖动控制 | 轻量 noise gate + hysteresis + attack/release | 不直接引入 WebRTC VAD / Silero VAD / RNNoise 依赖；先迁移其“语音/静音门限 + 平滑”的处理思路，用于纯 UI 波形 |
| 本地 ASR 候选 | SenseVoice / WhisperKit / whisper.cpp / Moonshine | 已接入 SenseVoice Small；WhisperKit large-v3 保留对照，Moonshine 作为低延迟对照 |

## 3. ASR 候选初选

更新时间：2026-06-18。以下只作为接入前候选，不等同于最终质量结论，必须用 NexVoice 自己的中文、中英混合和噪声样本实测。

| 类型 | 候选 | 初步判断 |
| --- | --- | --- |
| 云端性价比 | AssemblyAI Universal-Streaming | 官方价格约 $0.15/小时，价格最低；但语言覆盖偏欧美，中文质量必须实测 |
| 云端综合 | OpenAI `gpt-4o-mini-transcribe` | 官方估算 $0.003/分钟，短句听写性价比好；更适合先做“结束后转写”或半实时链路验证 |
| 云端实时 | Deepgram Nova-3 | 官方 Nova-3 流式价格约 $0.29/小时，工程成熟；中文/中英混合需实测 |
| 国内稳定 | 腾讯云实时语音识别 | 已接入默认主链路；国内网络和普通话场景更稳，速度优先时选择大模型实时引擎 |
| 国内候选 | 阿里 / 火山 | 文档和中文场景覆盖较强；需要账号开通后拿真实模型价格、延迟和 SDK 体验对比 |
| 本地首选 | SenseVoice Small | 中文/多语种方向优先，已通过 sherpa-onnx 本地后端接入，当前作为离线兜底和质量对照 |
| 本地兜底 | WhisperKit large-v3 | macOS/Apple Silicon 与 SwiftPM 集成最直接，保留为兜底和质量对照 |
| 本地低延迟候选 | Moonshine | 面向实时/低延迟语音，适合做 Spike；中文效果和 macOS 集成要单独验证 |

参考来源：

- https://github.com/sindresorhus/KeyboardShortcuts
- https://github.com/kishikawakatsumi/KeychainAccess
- https://developer.apple.com/documentation/avfaudio/avaudionode/installtap(onbus:buffersize:format:block:)
- https://developer.apple.com/documentation/avfaudio/avaudioconverter
- https://developer.apple.com/documentation/foundation/urlsessionwebsockettask
- https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media
- https://developer.apple.com/documentation/speech/sfspeechrecognizer
- https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest
- https://developer.apple.com/documentation/appkit/nspasteboard
- https://developer.apple.com/documentation/appkit/nspasteboard/setstring(_:fortype:)
- https://developer.apple.com/documentation/coregraphics/cgevent/init(keyboardeventsource:virtualkey:keydown:)
- https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(options:)
- https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions
- https://github.com/p0deje/Maccy
- https://github.com/wiseman/py-webrtcvad
- https://github.com/dpirch/libfvad
- https://github.com/snakers4/silero-vad
- https://github.com/xiph/rnnoise
- https://developers.openai.com/api/docs/pricing
- https://deepgram.com/pricing
- https://www.assemblyai.com/pricing
- https://staticintl.cloudcachetci.com/doc/pdf/product/pdf/1118_43341_en.pdf
- https://help.aliyun.com/zh/isi/product-overview/pricing
- https://www.volcengine.com/docs/6348/1392584
- https://github.com/ggml-org/whisper.cpp
- https://github.com/argmaxinc/argmax-oss-swift
- https://github.com/FunAudioLLM/SenseVoice
- https://github.com/moonshine-ai/moonshine

## 4. 当前代码结构

当前代码不从 NexHub 复制，而是新建最小独立 SwiftPM 结构：

- `Sources/NexVoiceCore`：产品核心能力，先包含语音事件、实时文本状态、PCM 帧、采集配置、麦克风权限、音频采集服务。
- `Sources/NexVoiceCore`：已新增本地 ASR 后端配置、SenseVoice 配置、WhisperKit 配置、WAV 写入、权限与音频采集基础。
- `Sources/NexVoiceCore`：已新增腾讯云实时 ASR 配置、HMAC-SHA1 签名 URL 生成、WebSocket 返回解析和稳定片段缓冲。
- `Sources/NexVoiceHost`：AppKit 菜单栏宿主，提供权限申请入口、语言切换、快捷键设置、快捷键触发腾讯云实时 ASR、屏幕底部波形提示条、最终文本输入到当前前台应用。
- `Sources/NexVoiceHost/TencentCloudRealtimeTranscriptionService.swift`：腾讯云实时 ASR WebSocket 客户端。
- `Resources/NexVoiceHost/SenseVoiceTranscriber.py`：由 NexVoice 调用的本地 SenseVoice/sherpa-onnx 转写脚本。
- `Tests/NexVoiceCoreTests`：核心模型测试。
- `Resources/NexVoiceHost/Info.plist`：App Bundle 元数据和麦克风权限说明。
- `scripts/build_app.sh`：构建本地 `.app`。
- `scripts/dev_run.sh`：构建并打开本地 App。
- `scripts/configure_tencent_asr.sh`：写入本机私有腾讯云 ASR 配置。

## 5. 下一步工程策略

1. 补齐腾讯云 SecretKey 后完成真实实时 ASR 联调。
2. 增加耗时指标：首个 partial、结束到 final、写入输入框、大模型润色耗时。
3. 用 20-30 条真实中文/中英混合短句对比腾讯云实时大模型、SenseVoice Small、WhisperKit large-v3。
4. 后续设置页如果继续扩展成完整偏好设置，再评估成熟开源库；当前右 Alt 主入口保持 NexHub 同款 `NSEvent` monitor 实现。
