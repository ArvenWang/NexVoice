# NexVoice 当前进展

更新时间：2026-06-21

## 当前状态

- 当前工作目录：`/Users/nefish/Desktop/Coding/NexVoice`。
- 项目形态：SwiftPM macOS 菜单栏 App，核心模块为 `NexVoiceCore`，宿主为 `NexVoiceHost`。
- 默认入口：右 Alt 开始语音输入，再按一次结束；ESC 可取消录音、等待 final 或 AI 改写中的会话。
- 当前主链路：腾讯云实时 ASR `16k_zh_en` -> DeepSeek `deepseek-v4-flash` 最终整理 -> 写入当前聚焦输入框。
- 本地 SenseVoice Small 和 WhisperKit large-v3 保留为兜底和质量对照，不是当前默认主链路。
- 打包脚本：`./scripts/build_app.sh release --embed-local-keys` 可生成带本机 DeepSeek / 腾讯云 ASR 配置的私用 App 包。

## 已完成能力

- 实时语音输入：麦克风采集、腾讯云实时识别、partial 草稿展示、final 后 AI 整理并写入输入框。
- 底部语音浮层：紧凑波形、实时草稿、loading 状态、toast 状态提示，整体对齐当前波形条样式。
- 输出语言：中文 / English 可独立选择。
- 输出模式已收敛为 4 个：
  - `标准模式（默认）`：修正吞字、断词、重复、口头禅、明显错词和断句，严格贴合原意、事实、立场和语气强弱。
  - `社交达人`：适合聊天、评论和社交媒体；英文输出允许常见缩写和 X / Reddit 等语境下更自然的表达。
  - `强化嘴替`：明显放大用户原本的情绪和攻击性；允许脏话、骂人和冒犯性表达，可直接攻击具体对象的行为、方案、表现或观点，但不编造事实、不威胁现实伤害、不转向身份群体攻击。
  - `冷静模式`：压低强情绪、脏话、攻击性和混乱表达，用更少的字冷静表达清楚原意。
- 旧输出模式兼容：
  - `automatic` / `general` / `faithful` / `clear` / `professional` -> `标准模式`
  - `casualFun` / `natural` -> `社交达人`
  - `expressive` / `creativeWild` -> `强化嘴替`
- 结构化整理：已支持识别 `第一点`、`第二点`、`还有一点`、`有两点`、`有三点`、`有四点` 等口语分点信号，避免用户分点说但输出未结构化。
- 个人词库：
  - 支持异步学习用户修正后的专有名词/特殊词。
  - 支持动态场景权重，腾讯云 ASR 热词会按当前 App / bundle / 场景排序。
  - 菜单提供 `个人词库...`，可查看、刷新和删除词条。
  - 学习成功使用底部 toast，不再弹阻塞确认框。

## 本轮完成

- 按用户反馈重写 `强化嘴替` 的 prompt：从温和的“更有张力”改成真正的情绪放大模式；用户愤怒时输出应更狠、更锋利、更不客气，并允许脏话和攻击性表达。
- `强化嘴替` temperature 从 `0.75` 提高到 `0.95`，并将评测样本改为愤怒表达场景。
- 真实 DeepSeek 评测确认强化模式已明显升温：样本输出出现 `他妈`、`受够`、`捅了篓子`、`不负责任到家` 等更强表达；报告路径为 `eval_reports/deepseek-rewrite-eval-amplified-real.md`。
- 已重新构建带本机 API 配置的强化模式版 DMG：
  - 路径：`dist/NexVoice-20260621-amplified.dmg`
  - SHA256：`396c914acde7af903a39e71cef1b9b0fd01d7516c9186a275a34cfe8f6534a49`
  - DMG 已挂载检查，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。
- 重写四个输出模式的 prompt，并接入菜单、DeepSeek prompt、temperature、评测样本和单测。
- 同步更新：
  - `Sources/NexVoiceCore/VoiceRewriteStyle.swift`
  - `Sources/NexVoiceCore/DeepSeekFinalRewriteConfiguration.swift`
  - `Sources/NexVoiceHost/VoiceRewriteEvaluationRunner.swift`
  - `Sources/NexVoiceRewriteEval/main.swift`
  - `README.md`
  - `docs/local_acceptance.md`
  - `docs/ai_rewrite_plan.md`
  - 相关测试文件
- 生成 dry-run prompt 报告：
  - `eval_reports/deepseek-rewrite-eval-four-modes-dry-run.md`
- 重新构建带本机 API 配置的 DMG：
  - 路径：`dist/NexVoice-20260621-four-modes.dmg`
  - SHA256：`3181aac5d3c87bd65c9f7d6b56f86f23c8c4a6872cdda6acb7602a3ec637994e`
  - DMG 已挂载检查，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。

## 验证情况

- `swift test --disable-sandbox --quiet`：通过 120 个测试。
- `git diff --check`：通过。
- `CLANG_MODULE_CACHE_PATH=.build/module-cache swift build --disable-sandbox --product NexVoiceApp`：通过。
- `CLANG_MODULE_CACHE_PATH=.build/module-cache swift build --disable-sandbox --product NexVoiceRewriteEval`：通过。
- `.build/debug/NexVoiceRewriteEval --dry-run --include-prompt --output eval_reports/deepseek-rewrite-eval-four-modes-dry-run.md`：通过，确认四个新模式 prompt 和 `有三点` 分点识别生效。
- `.build/debug/NexVoiceRewriteEval --output eval_reports/deepseek-rewrite-eval-amplified-real.md`：通过，真实请求 DeepSeek，未出现失败检查项。
- `./scripts/build_app.sh release --embed-local-keys`：通过，确认本机 DeepSeek / 腾讯云 ASR 配置已嵌入 App 资源目录。
- `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app`：通过。
- `plutil -lint dist/NexVoice.app/Contents/Info.plist`：通过。
- `hdiutil attach -readonly -nobrowse dist/NexVoice-20260621-amplified.dmg`：通过。

## 待办与风险

1. 需要继续做真实右 Alt 语音验收，重点记录 ASR 首包、ASR final、DeepSeek 改写和最终写入耗时。
2. 需要用真实语音样本复测四个输出模式的实际效果，尤其是 `社交达人`、`强化嘴替`、`冷静模式` 的边界。
3. 当前 DMG 内置本机 API 配置，只适合私用或受控分发；商业化版本应改为用户私有配置或 Keychain，不应长期内置共享 Key。
4. App 内 `运行 DeepSeek 评测` 属于开发诊断入口，商业化发布前建议移除或隐藏。
5. 如果未来恢复 Fast 路径，必须先证明输出质量不低于完整 DeepSeek prompt；当前正式路径以完整 prompt 为准。

## 下一步建议

1. 用新 DMG 做一次真实安装和右 Alt 输入验收。
2. 连续测试四个输出模式各 5-10 条真实语音样本。
3. 根据样本结果微调 prompt，而不是继续增加大量反向约束。
