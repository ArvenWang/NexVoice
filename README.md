# NexVoice

NexVoice 是一个计划基于 NexHub/NextUp 能力扩展的 macOS 语音输入与同传工具。

第一版产品范围只聚焦两个能力：

1. 实时转写：说话时实时出字，说完后整体润色。
2. 实时翻译 / 同传：说话时实时输出目标语言，说完后整体改写。

目标语言优先支持中文和英文。第一版最重要的指标是低延迟，质量先做到可用，再逐步优化。

## 当前状态

目前仓库只保存第一阶段调研和落地计划，尚未放入 Swift 应用代码。

核心结论：

- 底座建议复用 NexHub/NextUp，而不是从零写 macOS App。
- 实时转写优先验证腾讯云实时 ASR 或阿里实时 ASR。
- 实时同传优先验证腾讯云大模型实时语音翻译。
- 最终润色默认候选模型为 DeepSeek `deepseek-chat`。
- 端侧模型先预留接口，不放入第一版主链路。

## 文档

- [背景与目标交接说明](docs/handoff_context.md)
- [第一阶段调研与落地计划](docs/nexvoice_phase1_plan.md)
- [Typeless 产品调研报告](docs/typeless_research_report.md)

## 预留本地端口

| 服务 | 默认端口 | 说明 |
| --- | --- | --- |
| NexHub 原有 Gateway | `127.0.0.1:8787` | 保持不动 |
| Voice Gateway | `127.0.0.1:8791` | 新工具统一转发语音/模型请求 |
| Local ASR | `127.0.0.1:8792` | 预留给 whisper.cpp / Moonshine / SenseVoice |
| Local LLM | `127.0.0.1:8793` | 预留给 Ollama / llama.cpp / MLX server |

## 下一步

1. 确认是否从 NexHub 复制/拆分 Swift 应用底座。
2. 新增麦克风权限和音频采集 Spike。
3. 接入一个实时 ASR Provider 做延迟验证。
4. 接入一个实时同传 Provider 做中英互译验证。
5. 接入 DeepSeek 做最终润色。
