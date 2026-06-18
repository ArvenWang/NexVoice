# NexVoice

NexVoice 是一个计划基于 NexHub/NextUp 能力扩展的 macOS 语音输入与同传工具。

第一版产品范围只聚焦两个能力：

1. 语音输入：说话时轻量提示识别状态，说完后把文字输入到当前聚焦的文本框。
2. 实时翻译 / 同传：说话时实时输出目标语言，说完后整体改写。

目标语言优先支持中文和英文。第一版最重要的指标是低延迟，质量先做到可用，再逐步优化。

## 当前状态

目前仓库已经进入 Swift 应用实现阶段，但仍处于技术验证 Spike，不是可日常使用的完整产品。

核心结论：

- NexVoice 是独立新产品，不整体复制 NexHub；只筛选复用其中可靠的工程思路。
- 默认 ASR 已切到腾讯云实时语音识别大模型；本地 SenseVoice Small（sherpa-onnx）和 WhisperKit `large-v3-v20240930_626MB` 保留为兜底和质量对照。
- 实时同传后续优先验证腾讯云大模型实时语音翻译。
- 最终润色默认候选模型为 DeepSeek `deepseek-chat`。
- 云端实时 ASR 已进入主链路；端侧模型保留为离线和质量对照方案。

已建立的工程底座：

- SwiftPM：`NexVoiceCore` + `NexVoiceHost`。
- 菜单栏 App 宿主。
- 麦克风权限入口。
- `AVAudioEngine` 采集服务，目标输出为 16k mono PCM16。
- 腾讯云实时 ASR Provider，用于默认语音输入链路；按 200ms PCM 音频块实时上传，结束录音后等待腾讯云 `final=1` 再一次性写入当前输入框。
- 腾讯云配置脚本：`./scripts/configure_tencent_asr.sh`，本机私有配置写入 `~/Library/Application Support/NexVoice/TencentCloudASR.json`。
- SenseVoice Small 本地转写 Provider 保留为兜底；依赖和模型通过 `./scripts/install_sensevoice_backend.sh` 安装到 `~/Library/Application Support/NexVoice/SenseVoice`，之后在本机运行。
- WhisperKit large-v3 本地 Provider 保留在代码中，用于后续对照和兜底。
- 屏幕底部小型波形提示条，按一次快捷键开始时显示 Typeless 风格的细密麦克风波形，再按一次结束；不再显示实时草稿文字，静音时会保持稳定基线。
- 最终识别文本会通过当前聚焦输入框输出；波形提示条只做状态反馈，不作为主要结果容器。
- 默认语音快捷键为右 Alt，菜单中可录制自定义快捷键。
- 全局快捷键实现按 NexHub 现有 `NSEvent` monitor 模式接入；菜单提供辅助功能权限申请入口，用于接收全局键盘事件并向当前前台应用发送粘贴输入。
- 本地 `.app` 构建脚本：`./scripts/build_app.sh debug`。

## 文档

- [背景与目标交接说明](docs/handoff_context.md)
- [第一阶段调研与落地计划](docs/nexvoice_phase1_plan.md)
- [Typeless 产品调研报告](docs/typeless_research_report.md)
- [工程决策记录](docs/engineering_decisions.md)
- [本地验收说明](docs/local_acceptance.md)

## 预留本地端口

| 服务 | 默认端口 | 说明 |
| --- | --- | --- |
| NexHub 原有 Gateway | `127.0.0.1:8787` | 保持不动 |
| Voice Gateway | `127.0.0.1:8791` | 新工具统一转发语音/模型请求 |
| Local ASR | `127.0.0.1:8792` | 预留给 whisper.cpp / Moonshine / SenseVoice |
| Local LLM | `127.0.0.1:8793` | 预留给 Ollama / llama.cpp / MLX server |

## 下一步

1. 按 [本地验收说明](docs/local_acceptance.md) 验证快捷键触发的腾讯云实时 ASR 语音输入。
2. 补齐腾讯云 `SecretKey` 后，运行 `./scripts/configure_tencent_asr.sh` 并验证实时 ASR 写入链路。
3. 记录腾讯云首包、结束到最终写入、大模型润色前后的耗时。
4. 接入 DeepSeek 做最终润色。
