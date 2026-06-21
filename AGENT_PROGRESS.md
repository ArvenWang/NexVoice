# NexVoice 当前进展

更新时间：2026-06-21

## 当前状态

- 当前工作目录：`/Users/nefish/Desktop/Coding/NexVoice`。
- 项目形态：SwiftPM macOS 菜单栏 App，核心模块为 `NexVoiceCore`，宿主为 `NexVoiceHost`。
- 默认入口：短按右 Alt 开始语音输入，再按一次结束；长按右 Alt 约 0.55 秒进入看屏自动回复；ESC 可取消录音、等待 final、AI 改写或看屏回复中的会话。
- 当前主链路：腾讯云实时 ASR `16k_zh_en` -> DeepSeek `deepseek-v4-flash` 最终整理 -> 写入当前聚焦输入框。
- 本地 SenseVoice Small 和 WhisperKit large-v3 保留为兜底和质量对照，不是当前默认主链路。
- 打包脚本：`./scripts/build_app.sh release --embed-local-keys` 可生成带本机 DeepSeek / 腾讯云 ASR 配置的私用 App 包。

## 已完成能力

- 实时语音输入：麦克风采集、腾讯云实时识别、partial 草稿展示、final 后 AI 整理并写入输入框。
- 底部语音浮层：紧凑波形、实时草稿、loading 状态、toast 状态提示，整体对齐当前波形条样式。
- 文本浮层滚动：实时识别草稿和选中文本指令结果共用浮层布局；滚动条使用 overlay 方式，不再挤占正文宽度，长结果优先增高展示。
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
- 看屏自动回复：
  - 长按默认右 Alt 触发，不进入录音。
  - 读取当前前台应用最大可见窗口，使用 Apple Vision 本地 OCR 提取可见文字。
  - 按文字位置粗略生成 `我 / 对方 / 未知` 结构，交给 DeepSeek 生成一条回复。
  - 回复遵循当前输出语言和四个输出模式，最终写入当前输入框，但不自动发送。
  - 该模式只基于屏幕可见内容，不滚动、不读取屏幕外历史；`screen_reply` 诊断日志不保存 OCR 全文。

## 本轮完成

- 修复用户截图中的严重浮层问题：选中文本后语音指令的翻译结果不再左右裁切，滚动条改为悬浮 overlay，不再挤压正文导致文字消失。
- 同步修复实时识别文字框：识别草稿和结果框共用同一套文本容器宽度、正文内边距和滚动条安全区。
- 提高最大展示高度：
  - 实时识别浮层最大高度从 `128` 提到 `180`。
  - 选中文本指令结果浮层最大高度提高到 `300`，尽量减少长翻译结果的滚动条。
- 新增布局测试，防止最大高度和滚动条安全区被回退。
- 本轮待重新构建带本机 API 配置的 DMG：
  - 路径：`dist/NexVoice-20260621-text-panel-fix.dmg`
  - SHA256：`0d6851c5d339b65230eaa372a8d5ea4be722ec958dc7563b0cb8d4ae30e6f203`

## 上轮完成

- 新增看屏自动回复第一版：长按快捷键进入 `看屏中` / `AI 回复中` 状态，当前窗口可见文字经 OCR 后交给 DeepSeek 生成回复，并写入当前聚焦输入框。
- 新增屏幕录制权限菜单入口；未授权时会引导授权，不会静默失败。
- 新增 `screen_reply` DeepSeek prompt，明确只基于可见内容、不要把多角色聊天当作同一人、输出风格跟随当前输出模式。
- 调整快捷键逻辑：短按仍控制语音输入开始/结束，长按触发看屏回复。
- 保护隐私日志：看屏回复会把真实 OCR 内容发给 DeepSeek 生成回复，但本地 DeepSeek 诊断日志只保留 prompt 字符数，不保存 OCR 全文。
- 同步更新：
  - `Sources/NexVoiceHost/GlobalVoiceShortcutMonitor.swift`
  - `Sources/NexVoiceHost/ScreenReplyContextCaptureService.swift`
  - `Sources/NexVoiceHost/SystemPermissionRequester.swift`
  - `Sources/NexVoiceHost/DeepSeekFinalRewriteService.swift`
  - `Sources/NexVoiceCore/DeepSeekFinalRewriteConfiguration.swift`
  - `Sources/NexVoiceHost/main.swift`
  - `README.md`
  - `docs/local_acceptance.md`
  - `Tests/NexVoiceCoreTests/DeepSeekFinalRewriteConfigurationTests.swift`
- 已重新构建带本机 API 配置的看屏回复版 DMG：
  - 路径：`dist/NexVoice-20260621-screen-reply.dmg`
  - SHA256：`b05ad56cc103c92dfd91c94257a1adabdb8bdeb3ca5363ec9c799678b7883cca`

## 验证情况

- `swift test --disable-sandbox --quiet`：通过 122 个测试。
- `git diff --check`：通过。
- `CLANG_MODULE_CACHE_PATH=.build/module-cache swift build --disable-sandbox --product NexVoiceApp`：通过。
- `./scripts/build_app.sh release --embed-local-keys`：通过，确认本机 DeepSeek / 腾讯云 ASR 配置已嵌入 App 资源目录。
- `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app`：通过。
- `plutil -lint dist/NexVoice.app/Contents/Info.plist`：通过。
- `hdiutil attach -readonly -nobrowse dist/NexVoice-20260621-text-panel-fix.dmg`：通过，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。

## 待办与风险

1. 看屏回复第一版依赖窗口截图 + OCR，只能读取屏幕可见内容；微信等聊天软件的复杂气泡、头像、时间线和多列布局可能会影响 `我 / 对方 / 未知` 判断，需要真实样本继续优化。
2. Apple 屏幕录制权限生效后通常需要重启 App；如果长按右 Alt 一直提示权限，需要退出 NexVoice 后重新打开新版 App。
3. 需要继续做真实右 Alt 语音验收，重点记录 ASR 首包、ASR final、DeepSeek 改写和最终写入耗时。
4. 当前 DMG 内置本机 API 配置，只适合私用或受控分发；商业化版本应改为用户私有配置或 Keychain，不应长期内置共享 Key。
5. App 内 `运行 DeepSeek 评测` 属于开发诊断入口，商业化发布前建议移除或隐藏。
6. 如果未来恢复 Fast 路径，必须先证明输出质量不低于完整 DeepSeek prompt；当前正式路径以完整 prompt 为准。

## 下一步建议

1. 用新 DMG 做一次真实安装和右 Alt 短按 / 长按验收。
2. 在微信、浏览器、邮件、Codex 四类 App 中测试看屏回复，分别记录 OCR 是否完整、回复是否符合上下文、是否遵循当前输出模式。
3. 连续测试四个输出模式各 5-10 条真实语音样本。
