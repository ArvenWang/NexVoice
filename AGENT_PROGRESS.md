# NexVoice 进展

## 当前状态

- 已创建独立项目目录：`/Users/nefish/Desktop/WorkSpace/Coding/NexVoice`。
- 已初始化为本地 Git 仓库。
- 已放入第一阶段调研文档和 Typeless 调研报告。
- 已补充下一轮对话可直接使用的背景与目标交接说明。
- 已开始独立 Swift 应用实现，没有整体复制 NexHub。
- 已建立 SwiftPM 结构：`NexVoiceCore` library + `NexVoiceHost` menu bar executable。
- 已实现第一批核心能力：实时事件模型、实时稿状态、PCM 帧、采集配置、麦克风权限服务、`AVAudioEngine` 音频采集服务。
- 已接入腾讯云实时语音识别大模型作为当前默认 ASR 链路；SenseVoice Small via sherpa-onnx 与 WhisperKit large-v3 保留为本地兜底和质量对照，Apple Speech 早期验证代码已移除，避免继续依赖系统语音识别权限。
- 已将旧浮动字幕窗口改为屏幕底部纯波形小条，参考 Typeless 截图的深色胶囊与细密竖条风格，不再展示实时草稿文字。
- 波形小条会跟随麦克风音量变化；已放大为 176x52，21 根细波形柱，并加入噪声门、滞回和 attack/release 平滑，静音时不再高频抖动；成功输入或会话结束时立即收起。
- 当前默认 ASR 来源是腾讯云实时语音识别大模型；配置文件路径为 `~/Library/Application Support/NexVoice/TencentCloudASR.json`，需要 AppID、SecretId、SecretKey 三项都齐全才能真实联通。
- 当前已收到 AppID 和 SecretId，但缺少 SecretKey；代码和配置脚本已就绪，尚未做真实腾讯云 WebSocket 联调。
- 用户尚未验收当前版本；目前只能确认代码、测试、构建、打包和本地 App 启动通过，不能把语音输入体验视为已验收完成。
- 已修复按右 Alt 开始录音即崩溃的问题：`AVAudioConverter` 改用支持采样率转换的 input block API，并补足 48k 双声道输入转 16k 单声道 PCM16 的回归测试。
- 已修复结束录音后卡住像假死的问题：
  - 根因是首次模型下载/加载发生在结束录音之后，且之前启用了 WhisperKit background URLSession，UI 仍保持波形 finishing 状态。
  - 现在第二次按快捷键后会立即收起波形条，后台只保留菜单栏状态。
  - WhisperKit 改为前台 URLSession 下载，避免后台会话重复创建/取消。
  - 默认模型名改为 WhisperKit 精确远端模型，避免 `small` 模糊匹配。
  - 为提升中文和中英混合识别准确率，默认模型从 `openai_whisper-small` 升级为 `openai_whisper-large-v3-v20240930_626MB`。
  - 本地转写增加 90 秒超时，超时会回到 idle 并弹出失败提示。
- 已接入最终文本输出：再次按下快捷键结束并生成最终识别结果后，会把文字输入到当前聚焦的文本框中。
- 已移除菜单里的“开始实时转写”和“显示字幕窗口”入口，转写改为快捷键触发。
- 默认快捷键已改为右 Alt，已新增快捷键设置窗口，可录制自定义快捷键。
- 已按 NexHub 现有实现方式改造全局快捷键：使用 `NSEvent.addGlobalMonitorForEvents` / `addLocalMonitorForEvents` 监听按键和修饰键，不再使用 CGEvent tap 或轮询。
- 已保留辅助功能权限入口，用于系统允许 NexVoice 接收全局键盘事件并向前台应用发送粘贴输入。
- 已生成本地 `.app` 打包脚本，输出路径为 `dist/NexVoice.app`。

## 最近更新

### 2026-06-18

- 按用户“速度第一优先级”的新决策，把默认 ASR 主链路从本地 SenseVoice 切到腾讯云实时语音识别大模型：
  - 新增 `Sources/NexVoiceCore/TencentCloudRealtimeASRConfiguration.swift`，负责腾讯云实时 ASR 参数、`16k_zh_en` / `16k_en_large` 默认大模型、HMAC-SHA1 签名和 WebSocket URL 生成。
  - 新增 `Sources/NexVoiceCore/TencentCloudRealtimeASRMessage.swift`，解析腾讯云 `slice_type`、`stable_flag`、`final=1` 等返回，并维护稳定片段缓冲。
  - 新增 `Sources/NexVoiceHost/TencentCloudRealtimeTranscriptionService.swift`，使用 `URLSessionWebSocketTask` 连接 `wss://asr.cloud.tencent.com/asr/v2/<appid>`，录音时按约 200ms PCM16 音频块实时发送，结束时发送 `{"type":"end"}`，收到腾讯云最终消息后一次性写入当前输入框。
  - `LocalASRBackend.default` 改为 `.tencentCloudRealtime`；菜单展示 `ASR：腾讯云实时 ASR 大模型`，配置不完整时会显示缺少字段。
  - 新增 `scripts/configure_tencent_asr.sh`，用于写入本机私有配置 `~/Library/Application Support/NexVoice/TencentCloudASR.json`，文件权限设为 `600`。
  - 已确认腾讯云文档要求 SecretKey 参与签名；用户当前只提供了 AppID 和 SecretId，缺 SecretKey，因此本次无法完成真实云端联调。
  - 本次新增/更新腾讯云相关测试后，`swift test --quiet` 通过 65 个测试。
  - 本次新增/更新腾讯云相关代码后，`swift build --product NexVoiceApp` 通过。
  - 本次新增/更新腾讯云相关代码后，`bash -n scripts/configure_tencent_asr.sh` 通过。
  - 本次新增/更新腾讯云相关代码后，`git diff --check` 通过。
  - 本次新增/更新腾讯云相关代码后，`./scripts/build_app.sh debug` 成功重新生成并签名 `dist/NexVoice.app`。
  - 本次新增/更新腾讯云相关代码后，`codesign --verify --deep --strict dist/NexVoice.app` 通过。
  - 本次新增/更新腾讯云相关代码后，`plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - 已重启新版 `dist/NexVoice.app`，当前 `NexVoiceApp` 进程 PID 为 `98114`。
  - 因缺少腾讯云 SecretKey，本次没有做真实云端 WebSocket 鉴权和转写联调。
  - 用户明确表示当前还没有验收；后续必须在用户补齐 SecretKey 后做真实快捷键录音、云端识别、文本写回验收。

- 接手后重新确认产品边界：NexVoice 是独立新产品，NexHub 只作为可筛选素材，不整体照搬。
- 补充工程决策文档：`docs/engineering_decisions.md`。
- 建立 SwiftPM 项目：
  - `Package.swift`
  - `Sources/NexVoiceCore`
  - `Sources/NexVoiceHost`
  - `Tests/NexVoiceCoreTests`
- 新增菜单栏 App 宿主，提供权限、语言、快捷键和退出入口；语音输入由全局快捷键触发。
- 新增语言配置模型：
  - `SpeechRecognitionLanguage`
- 新增本地 WhisperKit 转写服务：
  - `Package.swift` 接入 `argmaxinc/argmax-oss-swift` 的 `WhisperKit` 产品。
  - `Sources/NexVoiceHost/WhisperKitLocalTranscriptionService.swift`
  - `Sources/NexVoiceCore/LocalWhisperTranscriptionConfiguration.swift`
  - `Sources/NexVoiceCore/AudioWaveFileWriter.swift`
  - `Package.resolved` 锁定 `argmax-oss-swift 1.0.0` 与 `swift-argument-parser 1.8.2`。
  - 默认模型为 `large-v3-v20240930_626MB`，中文映射 Whisper 语言码 `zh`，英文映射 `en`。
  - 实际传给 WhisperKit 的模型名为 `openai_whisper-large-v3-v20240930_626MB`。
  - 当前采用“录音结束后本地转写”的方式：开始时采集 PCM16 并驱动波形，结束后写临时 WAV，再交给 WhisperKit 生成最终文本。
  - 主流程不再要求 macOS 系统语音识别权限，只需要麦克风权限和辅助功能权限。
  - 修复音频转换崩溃：之前按目标 16k 采样率缩小输出 buffer，触发 `outputBuffer.frameCapacity >= inputBuffer.frameLength` 断言；现已确保容量满足 AVAudioConverter 前置条件。
  - 修复音频转换无数据：`convert(to:from:)` 在当前 48k -> 16k 场景会报 `sample rate conversion not allowed`，现改为 `convert(to:error:withInputFrom:)`。
- 新增 SenseVoice Small 本地后端：
  - 默认 ASR 后端从 WhisperKit large-v3 切到 SenseVoice Small via sherpa-onnx。
  - 新增 `LocalASRBackend`、`LocalSenseVoiceTranscriptionConfiguration`、`SenseVoiceTranscriptionOutput`。
  - 新增 `Sources/NexVoiceHost/SenseVoiceCommandTranscriber.swift`，由 Swift 调用本地 Python venv 中的 sherpa-onnx。
  - 新增 `Resources/NexVoiceHost/SenseVoiceTranscriber.py`，输出稳定 JSON 供 Swift 解析。
  - 新增 `scripts/install_sensevoice_backend.sh` 和 `scripts/test_sensevoice_backend.sh`，本机已安装 `sherpa-onnx 1.13.3`、`soundfile`、`numpy` 并下载 155MB int8 模型。
  - `scripts/test_sensevoice_backend.sh` 使用模型自带中文音频验证成功，输出“开放时间早上9点至下午5点。”，一次耗时约 0.56 秒。
- 菜单栏调整：
  - 快捷键显示
  - 设置快捷键
  - 中文/英文语言切换
  - 麦克风权限入口
  - 申请辅助功能权限
  - 本地 WhisperKit ASR 状态展示
- 新增全局快捷键监听：
  - `Sources/NexVoiceHost/GlobalVoiceShortcutMonitor.swift`
  - 默认右 Alt，按一下开始，再按一下结束并生成最终文本
- 新增快捷键设置窗口：
  - `Sources/NexVoiceHost/VoiceShortcutSettingsWindowController.swift`
- 重做语音状态展示：`Sources/NexVoiceHost/VoiceCaptionPanelController.swift` 改为无边框屏幕底部纯波形小条。
- 参考 NexHub 的 `ToolbarVoiceInputControl`，只取波形视觉方向，不复用其中的业务状态和转写文字展示。
- 移除旧草稿/字幕框逻辑：
  - 删除 `VoiceCaptionDisplayPolicy` 和对应文字自适应测试。
  - 新增 `VoiceWaveformDisplayPolicy`，当前为 176x52 波形框，21 根 3px 细波形柱。
  - 波形高度改为中间高、两侧低的 Typeless 式包络，避免几根粗柱随机跳动的观感。
  - 新增 `VoiceAudioLevelMeter` 和 `VoiceRealtimeEvent.audioLevelUpdated`，让波形响应真实麦克风音量。
  - `VoiceAudioLevelMeter` 增加低音量增益和轻微噪声门，普通说话时波形更明显。
  - 新增 `VoiceAudioLevelSmoother`，参考 WebRTC VAD / Silero VAD / RNNoise 的门限和平滑思路，使用开门阈值、关门阈值、连续静音帧和 attack/release 曲线过滤底噪抖动。
  - 移除静音时强制最低动画幅度，`amplitude == 0` 时波形保持静态基线。
  - 成功输入后收起延迟保持 0 秒，写回成功时立刻隐藏小条。
- 新增最终文本输出链路：
  - `Sources/NexVoiceCore/VoiceFinalTextPolicy.swift`
  - `Sources/NexVoiceHost/FocusedTextInserter.swift`
  - `Tests/NexVoiceCoreTests/VoiceFinalTextPolicyTests.swift`
- 输出逻辑调整为：转写框不再承载最终目的，最终识别文本通过当前聚焦输入框输出；底部小条只显示波形状态，不显示草稿文字。
- `FocusedTextInserter` 使用系统剪贴板 + `Command+V` 方式写回前台应用，并在剪贴板未被用户改动时恢复原剪贴板内容。
- 快捷键交互从“按住说话”改为“按一下开始、再按一下结束”，删除 Fn release 兜底轮询，减少复杂判断。
- 默认快捷键从 Fn 改为右 Alt：
  - `VoiceShortcut.default` 改为 `.rightOptionKey`。
  - 右 Alt 使用 macOS SDK 中的 `kVK_RightOption = 0x3D`。
  - 对旧版已保存的 Fn 默认配置做一次自动迁移，避免本机偏好继续覆盖新默认值。
- 早期 Apple Speech 方案曾增加 finish 超时清理，但后续已被本地 WhisperKit 主链路替换。
- 重新按 NexHub 当前仓库实现替换快捷键链路：
  - 参考 `/Users/nefish/Desktop/WorkSpace/Coding/NexHub/Sources/NexHub/App/AppInputEventCoordinator.swift`。
  - `GlobalVoiceShortcutMonitor` 改为普通 `NSEvent` global/local monitor，监听 `.keyDown`、`.keyUp`、`.flagsChanged`。
  - 删除上一次尝试加入的 HID event tap、右 Alt 轮询、监听状态菜单、手动测试触发和重新连接入口。
  - `refreshMenuState()` 保留菜单项引用更新，避免菜单下标错位。
- 早期修复过 Apple Speech 没有 final 时无文本输出的问题：
  - 如果已有 partial 文本，结束时会用最后一次 partial 作为最终文本输入。
  - 如果完全没有识别到文字，会显示“没有识别到语音，请确认麦克风输入后再试。”并自动收起提示条。
- 修复权限入口只打开系统设置、不会把 NexVoice 加入权限列表的问题：
  - `Sources/NexVoiceHost/SystemPermissionRequester.swift`
  - `Sources/NexVoiceCore/VoicePermissionGuidance.swift`
  - `Tests/NexVoiceCoreTests/VoicePermissionGuidanceTests.swift`
- 菜单里的辅助功能权限项会主动调用系统申请 API；该权限同时服务于全局键盘事件接收和最终文本写回。
- `scripts/build_app.sh` 优先使用本机可用的 Developer ID / Apple Development 证书签名，减少 ad-hoc 签名导致 macOS 隐私权限授权不稳定的问题；没有证书时才回退到 ad-hoc。
- 新增 `Resources/NexVoiceHost/Info.plist`，包含 `NSMicrophoneUsageDescription`。
- 移除 Apple Speech 权限文案和菜单入口；当前主链路不再申请系统语音识别权限。
- 新增本地验收说明：`docs/local_acceptance.md`。
- 新增本地脚本：
  - `scripts/build_app.sh`
  - `scripts/dev_run.sh`
- 最新验证完成：
  - 本次 SenseVoice 默认后端接入后，`swift test --quiet` 通过 56 个测试。
  - 本次 SenseVoice 默认后端接入后，`swift build --product NexVoiceApp` 通过。
  - 本次 SenseVoice 默认后端接入后，`./scripts/build_app.sh debug` 成功重新生成并签名 `dist/NexVoice.app`。
  - 本次 SenseVoice 默认后端接入后，`codesign --verify --deep --strict dist/NexVoice.app` 通过。
  - 本次 SenseVoice 默认后端接入后，`plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - 已验证 `dist/NexVoice.app/Contents/Resources/SenseVoiceTranscriber.py` 被打入 app 且可由 SenseVoice venv Python 调用。
  - 已重启新版 `dist/NexVoice.app`，当前 `NexVoiceApp` 进程 PID 为 `67336`。
  - 本次 ASR 默认模型升级后，`swift test --quiet` 通过 48 个测试。
  - 本次 ASR 默认模型升级后，`swift build --product NexVoiceApp` 通过。
  - 本次 ASR 默认模型升级后，`./scripts/build_app.sh debug` 成功重新生成并签名 `dist/NexVoice.app`。
  - 本次 ASR 默认模型升级后，`codesign --verify --deep --strict dist/NexVoice.app` 通过。
  - 本次 ASR 默认模型升级后，`plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - 已重启新版 `dist/NexVoice.app`，当前 `NexVoiceApp` 进程 PID 为 `95085`。
  - `swift test --quiet` 通过 48 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh debug` 成功生成并签名 `dist/NexVoice.app`。
  - `codesign --verify --deep --strict dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - 之前已重启新版 `dist/NexVoice.app`，当时 `NexVoiceApp` 进程 PID 为 `67587`。
  - 已用 CGEvent 模拟右 Alt 开始/结束一次录音，进程未崩溃；新进程日志显示 AVAudioEngine 正常 start/stop，未再出现 AudioConverter 崩溃。
  - 已确认模拟结束录音后不再出现 `background URLSession` 日志；当前仍会在首次模型不存在时发起前台模型下载。

### 2026-06-18 早期

- 建立项目仓库骨架。
- 项目命名调整为 `NexVoice`。
- 写入 `README.md`。
- 写入第一阶段调研文档：
  - `docs/handoff_context.md`
  - `docs/nexvoice_phase1_plan.md`
  - `docs/typeless_research_report.md`

## 下一步

1. 用户补齐腾讯云 SecretKey 后，运行 `./scripts/configure_tencent_asr.sh` 写入本机私有配置。
2. 用真实右 Alt 快捷键链路做腾讯云实时 ASR 联调：开始录音、实时发送、结束发送 `{"type":"end"}`、收到 `final=1`、写入当前输入框。
3. 增加 ASR 调试指标：首个 partial 延迟、结束到 final 延迟、写入完成时间、最近错误。
4. 对比腾讯云实时大模型、SenseVoice Small、WhisperKit large-v3 的中文和中英混合质量。

## 重要决策

- 第一版只做实时转写和实时同传。
- 用户最新决策是速度第一；默认 ASR 已切到腾讯云实时语音识别大模型。
- 最终润色优先使用 DeepSeek `deepseek-chat`。
- 默认入口改为右 Alt；全局快捷键实现按 NexHub 现有 `NSEvent` monitor 模式，不再使用 CGEvent tap 或轮询。
- Keychain 多密钥管理后续优先评估 `kishikawakatsumi/KeychainAccess`。
- 本地端口预留：
  - Voice Gateway：`8791`
  - Local ASR：`8792`
  - Local LLM：`8793`
