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
- 默认 ASR 已切到腾讯云实时语音识别 `16k_zh_en` 大模型，识别阶段自动处理中英和中英混合输入；本地 SenseVoice Small（sherpa-onnx）和 WhisperKit `large-v3-v20240930_626MB` 保留为兜底和质量对照。
- 实时同传后续优先验证腾讯云大模型实时语音翻译。
- 最终 AI 整理已接入 DeepSeek，默认使用 `deepseek-v4-flash`；它会结合当前 App、焦点输入框、选中文本模式和本地个人词库，把口语内容整理成更通顺、更有结构的最终文本。英文模式会倾向自然美式表达，失败或超时时回退写入腾讯云 ASR 原文。
- 云端实时 ASR 已进入主链路；端侧模型保留为离线和质量对照方案。

已建立的工程底座：

- SwiftPM：`NexVoiceCore` + `NexVoiceHost`。
- 菜单栏 App 宿主。
- 麦克风权限入口。
- `AVAudioEngine` 采集服务，目标输出为 16k mono PCM16。
- 腾讯云实时 ASR Provider，用于默认语音输入链路；固定使用 `16k_zh_en` 中英自动模型，按 200ms PCM 音频块实时上传，录音时在统一浮层内实时显示腾讯云草稿，结束录音后等待腾讯云 `final=1`。如果配置了本地个人词库，会自动带入腾讯云热词。
- DeepSeek 最终整理 Provider，用于把腾讯云 final 文本整理成自然、清晰、有逻辑的最终稿；菜单可选择输出中文或英文，并通过二级菜单选择单一 `输出模式`。当前模式收敛为 `标准模式（默认）`、`社交达人`、`强化嘴替`、`冷静模式`；超时会按普通输入、长文本、选中文本指令和高强度改写动态调整，失败或超时时写入原始 ASR 文本。
- 腾讯云配置脚本：`./scripts/configure_tencent_asr.sh`，本机私有配置写入 `~/Library/Application Support/NexVoice/TencentCloudASR.json`。
- SenseVoice Small 本地转写 Provider 保留为兜底；依赖和模型通过 `./scripts/install_sensevoice_backend.sh` 安装到 `~/Library/Application Support/NexVoice/SenseVoice`，之后在本机运行。
- WhisperKit large-v3 本地 Provider 保留在代码中，用于后续对照和兜底。
- 屏幕底部统一浮层已对齐 NexHub 的语音输入样式：紧凑态为小型胶囊波形，实时草稿出现后扩展为同一个深色 blur/tint 面板；文字为 13 号，面板按内容增高，超过最大高度后在内部滚动。
- 再次按快捷键结束输入后，浮层会缩小为 loading 条，等待腾讯云 final 和 DeepSeek 整理完成后再写入并收起。
- 在录音、等待腾讯云 final 或 DeepSeek 整理期间按 ESC 会取消本轮语音输入；取消后不会启动 DeepSeek，也不会写入任何文本。
- 最终整理文本会通过当前聚焦输入框输出；统一浮层只做过程反馈，不直接写入输入框。
- 如果启动语音前用户已经选中一段文字，NexVoice 会把选中文本作为上下文，把语音识别结果当作指令交给 DeepSeek，例如“翻译”“总结”“解释一下”；结果会显示在选区附近的小文本框中，不写回输入框。位置优先跟随触发语音时的鼠标位置，避免依赖不稳定的系统选区坐标。
- 如果选中的文字位于可编辑输入框内，NexVoice 会优先按普通语音输入处理，最终写回时覆盖当前选区；不会把输入框里被全选的旧文本误当成上下文指令。
- 每次 DeepSeek 整理都会携带“上下文包”：当前前台 App、焦点控件、输入框已有内容片段、是否为选中文本指令模式，以及个人词库。自动风格会基于这些信息更稳定地判断是 Agent 协作、邮件、即时沟通还是通用输入。
- 可选个人词库路径为 `~/Library/Application Support/NexVoice/PersonalDictionary.json`。文件不存在时不影响使用；存在时会同时用于腾讯云热词和 DeepSeek 专有名词保护。
- 开发评测工具 `NexVoiceRewriteEval` 可跳过 ASR，直接用“模拟 ASR 文本 + 模拟上下文”测试 DeepSeek 整理质量；dry-run 可检查 prompt 是否带上上下文，真实模式可批量收集模型输出样本。NexVoice 菜单内也提供 `运行 DeepSeek 评测`，用于让 App 自己的进程直接跑真实 DeepSeek 样本。
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
3. 记录腾讯云首包、结束到 final、DeepSeek 整理、最终写入的耗时。
4. 对比“原始 ASR 文本”和“DeepSeek 结构化整理文本”的质量与延迟。
5. 腾讯云 ASR 诊断日志位于 `~/Library/Application Support/NexVoice/Logs/TencentCloudASR.jsonl`，用于回溯启动、首个识别片段、用户结束、最终结果和失败原因。
6. DeepSeek 诊断日志位于 `~/Library/Application Support/NexVoice/Logs/DeepSeekRewrite.jsonl`，用于回溯模型、耗时、HTTP 状态、错误、finish reason、输入/输出长度、上下文摘要和短预览；不会记录 API Key。
7. 可运行 `swift build --disable-sandbox --product NexVoiceRewriteEval` 后执行 `.build/debug/NexVoiceRewriteEval --dry-run --include-prompt`，检查上下文 prompt；网络可用时执行 `.build/debug/NexVoiceRewriteEval` 收集真实 DeepSeek 输出样本。
8. 如果命令行环境无网络，可重启新版 NexVoice 后点击菜单里的 `运行 DeepSeek 评测`，报告会写入 `~/Library/Application Support/NexVoice/EvalReports`。
