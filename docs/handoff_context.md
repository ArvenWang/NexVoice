# NexVoice 背景与目标交接说明

更新时间：2026-06-18  
项目路径：`/Users/nefish/Desktop/WorkSpace/Coding/NexVoice`

## 1. 项目背景

用户原本有一个 Mac 应用，之前主要做划词相关功能，叫 NextUp / NexHub。现有 NexHub 是 Swift + AppKit 的 macOS 应用，已经具备菜单栏常驻、权限管理、全局快捷键、浮层 UI、设置页、AI Provider 配置、Keychain 存储、打包发布脚本等基础能力。

本项目是在调研 Typeless 之后提出的新产品方向。Typeless 是一个 AI 语音输入工具，核心体验是用户说话后实时出字，并由 AI 自动清理、润色、格式化，再把结果用于各种 App 输入场景。

用户不想完整复刻 Typeless 的所有功能，而是希望先做一个更聚焦、能个人落地的 Mac 工具，产品命名为 **NexVoice**。

> 2026-06-18 更新：本文件保留早期目标背景；ASR 主链路已经按用户最新决策改为速度优先，当前默认接入腾讯云实时语音识别大模型。SenseVoice Small via sherpa-onnx 和 WhisperKit large-v3 保留为本地兜底和质量对照。

## 2. 项目目标

NexVoice 第一版只做两个核心功能：

1. **实时转写**
   - 用户说话时实时输出文字。
   - 支持中文和英文。
   - 说完后对整段内容做最终润色，让它更像可直接发送或记录的文本。

2. **实时翻译 / 同声传译**
   - 用户说话时实时输出目标语言文字。
   - 支持中文到英文、英文到中文。
   - 说完后对完整翻译稿做整体改写，让表达更自然。

第一优先级是 **低延迟和速度**。转写质量第一版可以先做到可用，但不能慢。

## 3. 关键产品判断

- 不建议从零开始新建 macOS App。
- 建议复用 NexHub/NextUp 的 Swift 应用底座。
- 第一版不要做完整 Typeless，只做“转写 + 同传”。
- ASR 主链路已改为腾讯云实时大模型，优先保证低延迟；端侧模型后置为离线兜底和质量对照方案。
- 最终润色优先用低成本文本模型。
- 产品体验要明确分为两个阶段：
  - 实时状态：只显示轻量波形反馈，不把草稿文字当结果容器。
  - 最终稿：说完后输出到当前聚焦输入框，并在需要时整体润色/改写。

## 4. 推荐技术路线

### 4.1 App 底座

使用 NexHub/NextUp 的现有能力：

- macOS 菜单栏常驻。
- 全局快捷键。
- 权限管理。
- 设置窗口。
- Keychain 存 API Key。
- 浮动结果面板。
- 打包和本地分发脚本。

需要新增：

- 麦克风权限。
- 音频采集服务。
- 实时 ASR Provider 抽象。
- 实时同传 Provider 抽象。
- 结束后的最终润色服务。
- 实时字幕/同传窗口。
- 语音设置页。

### 4.2 模型与服务商

当前实现已改为腾讯云实时语音识别大模型作为默认 ASR；本地 SenseVoice Small via sherpa-onnx 保留为离线兜底和质量对照。

早期曾建议第一版优先验证：

- 实时转写：腾讯云实时 ASR 大模型版，或阿里 `qwen3-asr-flash-realtime`。
- 实时同传：腾讯云大模型实时语音翻译。
- 最终润色：DeepSeek `deepseek-v4-flash`。

备选：

- 百度实时语音识别 / 实时语音翻译。
- 讯飞实时语音听写 / 实时语音转写。
- 火山引擎 / 豆包语音和文本模型。
- OpenAI Realtime 作为开发速度优先或国外链路验证方案。

端侧模型当前作为本地兜底和质量对照保留；后续可继续探索 whisper.cpp、Moonshine、SenseVoice、MLX、Ollama、llama.cpp。

## 5. 预留端口

| 服务 | 默认端口 | 说明 |
| --- | --- | --- |
| NexHub 原有 Gateway | `127.0.0.1:8787` | 保持不动，避免影响旧功能 |
| Voice Gateway | `127.0.0.1:8791` | 新工具统一转发语音/模型请求 |
| Local ASR | `127.0.0.1:8792` | 预留给 whisper.cpp / Moonshine / SenseVoice |
| Local LLM | `127.0.0.1:8793` | 预留给 Ollama / llama.cpp / MLX server |

## 6. 当前仓库状态

当前仓库已经初始化 Git，并已放入 SwiftPM macOS 菜单栏应用代码。

已有重点文件：

- `README.md`
- `AGENT_PROGRESS.md`
- `docs/handoff_context.md`
- `docs/nexvoice_phase1_plan.md`
- `docs/typeless_research_report.md`
- `Sources/NexVoiceCore`
- `Sources/NexVoiceHost`
- `Tests/NexVoiceCoreTests`
- `scripts/build_app.sh`
- `scripts/configure_tencent_asr.sh`

早期已有 Git 提交：

- `540f6b1 Initial NextUpVoice research docs`
- `8c7106f Rename project to NexVoice`

## 7. 下一轮对话建议从这里开始

下一轮可以直接让 Agent 进入：

```text
/Users/nefish/Desktop/WorkSpace/Coding/NexVoice
```

建议下一步任务：

1. 决定如何导入 NexHub/NextUp 代码底座。
2. 建立 Swift App 初始结构。
3. 加麦克风权限管理。
4. 做 `AVAudioEngine` 音频采集 Spike。
5. 接一个实时 ASR Provider，先验证首字延迟。
6. 接一个实时同传 Provider，验证中文和英文双向效果。
7. 接 DeepSeek `deepseek-v4-flash` 做最终润色。

推荐给下一轮 Agent 的开场指令：

```text
请进入 /Users/nefish/Desktop/WorkSpace/Coding/NexVoice，先阅读 README.md、AGENT_PROGRESS.md、docs/handoff_context.md、docs/nexvoice_phase1_plan.md。这个项目要做一个基于 NexHub/NextUp 底座的 macOS 语音输入与同传工具，第一版只做实时转写和实时中英同传，目标是低延迟。请先研究现有 NexHub 代码如何复用，然后开始搭建 Swift App 底座。
```
