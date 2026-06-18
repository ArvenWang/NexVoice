# NexVoice 进展

## 当前状态

- 已创建独立项目目录：`/Users/nefish/Desktop/WorkSpace/Coding/NexVoice`。
- 已初始化为本地 Git 仓库。
- 已放入第一阶段调研文档和 Typeless 调研报告。
- 尚未导入 NexHub/NextUp 代码。
- 尚未开始 Swift 应用实现。

## 最近更新

### 2026-06-18

- 建立项目仓库骨架。
- 项目命名调整为 `NexVoice`。
- 写入 `README.md`。
- 写入第一阶段调研文档：
  - `docs/nexvoice_phase1_plan.md`
  - `docs/typeless_research_report.md`

## 下一步

1. 决定是复制 NexHub 当前代码作为新产品底座，还是只抽取模块。
2. 建立 Swift App 基础结构。
3. 新增麦克风权限管理。
4. 新增 `AudioCaptureService`，验证麦克风采集和 PCM 输出。
5. 接入第一个实时 ASR Provider，记录首字延迟和稳定性。

## 重要决策

- 第一版只做实时转写和实时同传。
- 实时链路优先使用云端服务，端侧模型只预留接口。
- 最终润色优先使用 DeepSeek `deepseek-chat`。
- 本地端口预留：
  - Voice Gateway：`8791`
  - Local ASR：`8792`
  - Local LLM：`8793`
