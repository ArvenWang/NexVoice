# NexVoice 当前进展

更新时间：2026-07-02

## 当前状态

- 当前工作目录：`/Users/nefish/Desktop/Coding/NexVoice`。
- 项目形态：SwiftPM macOS 菜单栏 App，核心模块为 `NexVoiceCore`，宿主为 `NexVoiceHost`。
- 默认入口：单击右 Alt 开始普通语音输入，再单击一次结束；双击右 Alt 进入上下文问答（优先选中文字，未选中文字则读取鼠标附近 OCR，且会高亮 OCR 覆盖区域）；三击右 Alt 进入快捷指令快速翻译（优先处理选中文字，未选中文字则读取鼠标附近 OCR 并翻译）；长按右 Alt 约 0.55 秒进入看屏自动回复；ESC 可取消录音、等待 final、AI 改写或看屏回复中的会话。
- 当前主链路：腾讯云实时 ASR `16k_zh_en` -> DeepSeek `deepseek-v4-flash` 最终整理 -> 写入当前聚焦输入框。
- 普通语音输入已增加第一版“基于输入框短草稿连续改写”：录音开始时读取当前输入框草稿，语音结束后把“已有草稿 + 本轮语音”交给 DeepSeek 输出完整新草稿，并在安全条件满足时用非全选的 AX 写入替换当前输入框全文；空输入框、输入框内已有选区、超长草稿仍按光标位置普通插入。
- 本地 SenseVoice Small 和 WhisperKit large-v3 保留为兜底和质量对照，不是当前默认主链路。
- 打包脚本：`./scripts/build_app.sh release --embed-local-keys` 可生成带本机 DeepSeek / 腾讯云 ASR 配置的私用 App 包。
- 版本号规则：当前版本从 `0.1.0 / build 1` 开始纳入自动化管理；每次 Git 提交包含真实迭代内容时，pre-commit hook 会自动把 patch 版本递增 `0.0.1`，并把 build 号递增 `1`。

## 本轮追加（2026-07-02：矩阵波形暗底与非方向性噪波修正）

- 本轮结论：
  - 已按用户新反馈调整：整条矩阵现在始终保留暗紫色像素底，不再靠“渐隐宽度”表达声音。
  - 说话时主要提升中央区域亮度和碎点强度，外侧暗底仍存在但不会明显被音量拉宽。
  - 噪波改为每个像素独立伪随机相位，避免看起来像固定方向的上下/左右流动；音量会提高噪波变化速度和中央亮度。
- 已执行：
  - `VoiceWaveformDisplayPolicy`：移除音量控制扩散宽度的模型，改成固定中央亮区 + 全宽暗底 + 独立相位噪波。
  - `VoiceCaptionPanelController`：调整颜色映射，让所有格子都有暗底透明度，音量主要增加亮度；动画 phase 增量随当前音量上升。
  - `VoiceWaveformDisplayPolicyTests`：更新测试为全宽暗底、中心亮度提升、外侧不明显变宽、非方向性噪波碎度。
  - 运行 `./scripts/bump_version.sh`，版本从 `0.1.68 (69)` 升到 `0.1.69 (70)`。
  - 已构建并安装带 API 配置的 `/Applications/NexVoice.app`，旧版备份为 `dist/install-backups/NexVoice-20260702-015711-pre-waveform-noise-base.app`。
  - 已重启安装版 App，当前进程 PID `50232`。
- 已验证：
  - `swift test --disable-sandbox --filter VoiceWaveformDisplayPolicyTests` 通过（13 tests）。
  - `swift test --disable-sandbox --quiet` 通过（158 tests）。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `dist/NexVoice.app` 和 `/Applications/NexVoice.app` 内的 `DeepSeek.json`、`TencentCloudASR.json` 嵌入配置存在且非空。

## 本轮追加（2026-07-02：矩阵波形边缘渐隐与中心聚焦修正）

- 本轮结论：
  - 已按用户截图反馈修正：去掉矩阵波形内部黑色底条；两侧方块现在按距离自然渐隐；发光更集中在中央，音量扩散从中心向两边的感觉更明显。
  - 静音时仍保留低强度流动噪波，但底噪也会受边缘衰减控制，不会在两端形成硬边。
- 已执行：
  - `VoiceWaveformDisplayPolicy`：收窄音量扩散宽度，增强中心峰值衰减曲线，边缘噪波和环境噪波都乘以横向 fade。
  - `VoiceCaptionPanelController`：删除额外暗色 track 绘制；方块 alpha 进一步按中心距离衰减。
  - `VoiceWaveformDisplayPolicyTests`：新增中心聚焦和边缘渐隐断言，防止后续回到整条均匀发光。
  - 运行 `./scripts/bump_version.sh`，版本从 `0.1.67 (68)` 升到 `0.1.68 (69)`。
  - 已构建并安装带 API 配置的 `/Applications/NexVoice.app`，旧版备份为 `dist/install-backups/NexVoice-20260702-015012-pre-waveform-fade-focus.app`。
  - 已重启安装版 App，当前进程 PID `38297`。
- 已验证：
  - `swift test --disable-sandbox --filter VoiceWaveformDisplayPolicyTests` 通过（12 tests）。
  - `swift test --disable-sandbox --quiet` 通过（157 tests）。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `dist/NexVoice.app` 和 `/Applications/NexVoice.app` 内的 `DeepSeek.json`、`TencentCloudASR.json` 嵌入配置存在且非空。

## 本轮追加（2026-07-02：长矩阵噪波语音波形）

- 本轮结论：
  - 已把原来的 5 根短波形替换为更长的方块矩阵波形，视觉方向接近“中心向两侧扩散的噪波信号条”。
  - 新波形不是完全跟随音量：静音时仍有低强度流动噪波；说话时在基础噪波上叠加音量扩散，亮区从中心向两边延展。
  - 方块亮度带有稳定伪随机变化，不是每帧真随机，避免视觉闪烁和性能浪费。
  - 如果系统开启“减少动态效果”，波形会保留音量反馈，但不再持续自动流动。
- 已执行：
  - `VoiceWaveformDisplayPolicy`：波形尺寸从 `64x28` 调整为 `236x28`，compact 面板从 `92x56` 调整为 `264x56`；新增 44 列 x 5 行网格单元计算。
  - `VoiceCaptionPanelController`：`VoiceWaveformView` 改为绘制暗色轨道 + 方块矩阵；每个方块按中心距离、音量和噪波相位计算紫色/白色亮度层次。
  - `VoiceWaveformDisplayPolicyTests`：更新为验证长网格、亮度噪波、静音流动、音量向外扩散和隐藏策略。
  - 运行 `./scripts/bump_version.sh`，版本从 `0.1.66 (67)` 升到 `0.1.67 (68)`。
  - 已构建并安装带 API 配置的 `/Applications/NexVoice.app`，旧版备份为 `dist/install-backups/NexVoice-20260702-014510-pre-noise-grid-waveform.app`。
  - 已重启安装版 App，当前进程 PID `11088`。
- 已验证：
  - `swift test --disable-sandbox --filter VoiceWaveformDisplayPolicyTests` 通过（10 tests）。
  - `swift test --disable-sandbox --quiet` 通过（155 tests）。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `dist/NexVoice.app` 和 `/Applications/NexVoice.app` 内的 `DeepSeek.json`、`TencentCloudASR.json` 嵌入配置存在且非空。

## 本轮追加（2026-07-02：三击快捷指令支持鼠标 OCR 翻译）

- 本轮结论：
  - 问题原因已确认：三击快捷指令在上次修正后变成“无选中文字就快速失败”，没有复用双击的鼠标 OCR 捕获，所以鼠标指向文字后 三击会报“未检测到选中文本”。
  - 已改为：三击先按原逻辑处理选中文字；如果没有选中文字且不是选区读取失败，就在鼠标附近跑 OCR，命中后直接按“快速翻译”处理并在鼠标附近展示结果。
  - 如果系统暗示存在选区但剪贴板兜底仍读取失败，仍提示“未能读取选中文字”，避免误把失败选区切到 OCR。
- 已执行：
  - `Sources/NexVoiceHost/main.swift`：新增 `beginQuickShortcutMouseOCRTranslation`、`generateQuickShortcutOCRTranslation` 和 `finishQuickShortcutOCRWithError`，三击无选区分支改为 OCR 翻译。
  - 新增日志事件：`begin_quick_shortcut_mouse_ocr`、`quick_shortcut_mouse_ocr_captured`、`quick_shortcut_mouse_ocr_generating`、`quick_shortcut_mouse_ocr_succeeded`、`quick_shortcut_mouse_ocr_failed`。
  - 运行 `./scripts/bump_version.sh`，版本从 `0.1.65 (66)` 升到 `0.1.66 (67)`。
  - 运行 `./scripts/build_app.sh release --embed-local-keys`，生成新的 `dist/NexVoice.app`。
  - 已安装到 `/Applications/NexVoice.app`，旧版备份为 `dist/install-backups/NexVoice-20260702-000858-pre-quick-shortcut-ocr.app`。
  - 已重启安装版 App，当前进程 PID `12171`。
- 已验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过（154 tests）。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `dist/NexVoice.app` 和 `/Applications/NexVoice.app` 内的 `DeepSeek.json`、`TencentCloudASR.json` 嵌入配置存在且非空。

## 本轮追加（2026-07-01：带 API 的分享 DMG 打包）

- 本轮结论：
  - 已重新构建带本机 API 配置的分享版 App，并生成可直接分发的 DMG。
  - 当前分享包版本为 `0.1.65 (66)`，与仓库 `Info.plist`、`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 一致。
  - DMG 内已包含 `DeepSeek.json` 和 `TencentCloudASR.json` 嵌入配置，适合可信对象直接安装试用。
- 已执行：
  - 运行 `./scripts/bump_version.sh`，版本从 `0.1.64 (65)` 升到 `0.1.65 (66)`。
  - 运行 `./scripts/build_app.sh release --embed-local-keys`，生成新的 `dist/NexVoice.app`。
  - 用新包完整替换安装到 `/Applications/NexVoice.app`，旧版备份为 `dist/install-backups/NexVoice-20260701-233832.app`。
  - 生成 DMG：`dist/NexVoice-0.1.65-build66-embedded-keys-20260701.dmg`。
  - DMG SHA256：`541a52593f10786ffb27cb54bb28d07800e12fed9dee32e76bbe3c3e3ee24afe`。
- 已验证：
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `dist/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在且非空。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在且非空。
  - `hdiutil verify dist/NexVoice-0.1.65-build66-embedded-keys-20260701.dmg` 通过。
  - 已挂载 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。

## 本轮追加（2026-06-30：三击快捷指令命中门槛修正）

- 本轮结论：
  - 三击默认按当前选中文本直接执行快捷指令，不再进入麦克风/补充指令分支。
  - 保留“快捷指令”下拉样式（与工作流输出模式一致），仅保留“快速翻译”一项；本地 `SettingsWeb/dist` 已同步。
  - 若未检测到选中文本，直接提示“未检测到选中文本”，避免误以为触发成功却无动作。
- 已执行：
  - `Sources/NexVoiceHost/main.swift`：三击链路改为 `selectedTextQuestionDetectionForQuickShortcut`，并在未命中时直接 `quick_shortcut_selected_text_not_found` 失败提示。
  - `swift test --disable-sandbox --quiet` 通过（154 tests）。
  - `SettingsWeb` 产物重新构建：`cd SettingsWeb && npm run build`。
  - 打包并安装到 `/Applications/NexVoice.app`，备份旧版为 `dist/install-backups/NexVoice-20260630-224311-post-quickcommand-install-fix.app`（如路径存在），新版本 `CFBundleShortVersionString=0.1.62`，`CFBundleVersion=63`。


## 本轮追加（2026-06-30：三击快捷指令直译行为修正）

- 本轮结论：
  - `SettingsWeb` 的“快捷指令”右侧改为与工作流输出模式同款下拉（仅保留“快速翻译”），并保持与配置联动。
  - 三击按键在主链路中不再需要额外口令，优先走 `selectedTextQuestionDetection` 读取选中文本，命中后直接调用 `handleQuickShortcutCommand`（默认执行“快速翻译”：中文→English，非中文→简体中文）。
  - 若未命中选中内容，仍按语音输入走 ASR 后执行默认快捷指令。
- 实施与验证：
  - `swift test --disable-sandbox --quiet` 通过（154 tests）。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - 已安装到 `/Applications/NexVoice.app`；`CFBundleShortVersionString=0.1.61`，`CFBundleVersion=62`。
  - 已确认打包后 `SettingsWeb` 产物内的设置页“快捷指令”已使用下拉样式。

## 本轮追加（2026-06-30：DeepSeek 官方新模型核对）

- 官方核对：
  - DeepSeek 官方 API 文档当前列出的主模型为 `deepseek-v4-flash` 和 `deepseek-v4-pro`。
  - `deepseek-chat` / `deepseek-reasoner` 仍兼容，但官方标注会在 `2026-07-24 15:59 UTC` 弃用；其中旧 `deepseek-chat` 对应 `deepseek-v4-flash` 的 non-thinking 模式。
- 本地核对：
  - 当前核心代码 `DeepSeekFinalRewriteConfiguration` 默认已经是 `deepseek-v4-flash`，测试也已覆盖该默认值。
  - 最近 `DeepSeekRewrite.jsonl` 日志记录的实际请求模型也是 `deepseek-v4-flash`。
  - 当前 `/Applications/NexVoice.app` 二进制中也能确认使用 `deepseek-v4-flash`，安装版版本为 `0.1.57 (58)`。
- 本轮处理：
  - 核心代码无需再改模型名；避免把已正确的低延迟链路误改成更贵、更慢的 Pro。
  - 已更新旧方案/交接文档中残留的 `deepseek-chat` 默认模型描述，统一指向 `deepseek-v4-flash`。

## 本轮追加（2026-06-30：快捷指令三击触发 + 翻译默认指令）

- 用户需求：按双击判断节奏只在时间窗内识别连点 3 次，新增“快捷指令”设置与默认翻译指令。
- 本地核对：
  - `main.swift` 已接入三连发路由：`VoiceShortcutTriggerPolicy` 支持 `.triple -> .beginQuickCommand`，`GlobalVoiceShortcutMonitor` 支持 `onTripleTrigger`，并按窗口时间(`doubleTriggerInterval`)判定 3 次连续点击。
  - 新增 `VoiceShortcutQuickCommand` 与持久化存储；设置页 Input Tab 增加“快捷指令”单独一行（默认仅提供“快速翻译”）。
  - 默认快捷指令执行逻辑为：在 `quick_shortcut_command` 会话里沿用普通 DeepSeek 链路（`deepseek-v4-flash` 模型）调用 `handleQuickShortcutCommand`，并附带上下文与固定翻译 prompt（中文 -> English；非中文 -> 中文）。
- 验证：
  - `swift test --disable-sandbox --quiet` 通过（154 tests）。
  - `cd SettingsWeb && npm run build` 通过。
- Git 状态：本地有上述新功能未推送改动；当前 `main` 与 `origin/main` 内容一致，无提交落后/超前，但工作区有未提交文件。下一步为提交并推送。

- 已验证：
  - `strings /Applications/NexVoice.app/Contents/MacOS/NexVoiceApp` 能找到 `deepseek-v4-flash`。
  - 最近 DeepSeek 诊断日志显示多次 `model":"deepseek-v4-flash"` 且请求成功。

## 本轮追加（2026-06-30：重建安装与验收）

- 执行了 `./scripts/build_app.sh release --embed-local-keys` 重新构建。
- 将新包安装到 `/Applications/NexVoice.app`，并保留备份：
  `dist/install-backups/NexVoice-20260630-221445-post-triple-shortcut.app`
- 运行校验：
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过
  - `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过
  - `CFBundleShortVersionString`：`0.1.58`
  - `CFBundleVersion`：`59`
  - 二进制模型标识：`deepseek-v4-flash`
- 已启动新安装的 App（进程名 `NexVoiceApp`，PID `7084`）。

## 本轮追加（2026-06-28：Codex 连续改写保护 HTML / 指令 / 代码类字面内容）

- 日志定位：
  - `ContinuousRewrite.jsonl` 显示一次明确写入失败：`2026-06-27T15:53:29Z`，Codex 输入框进入 `replaceFocusedDraft`，但写回时报 `当前输入框不支持安全替换已有草稿。`；这不是 ASR 或 DeepSeek 失败，而是 AX 替换写入失败。
  - 最近 Codex 样本中，输入框已有 `huangserva/3DCellForge` 后继续语音补充时，系统会把“已有草稿 + 新语音”交给 DeepSeek 做整体连续改写；仓库名本次保住了，但这种机制会让 HTML、任务 ID、指令块、代码块等字面内容暴露给模型重排或改写。
  - 当前 prompt 对“英文术语、代码、品牌名”有保护，但没有足够明确要求 URL、仓库名、任务 ID、HTML/XML 标签、`::directive` 原样保留。
- 本轮修复：
  - `VoiceContinuousRewritePolicy` 增加保护规则：如果当前输入框草稿包含 Markdown 代码块、HTML/XML 标签、URL、`app://` 链接、仓库名形式 `owner/repo`、长任务 ID、或 `::directive{...}`，不再走 `replaceFocusedDraft` 整体连续改写，改为只整理并插入本轮语音。
  - `VoiceRewritePromptPolicy` 加强提示词：代码、URL、仓库名、任务 ID、HTML/XML 标签、`::directive` 必须原样保留，不改大小写、符号或结构。
  - 补充测试覆盖 `huangserva/3DCellForge`、`tsk_...`、`<INSTRUCTIONS>`、HTML、`::git-create-pr{...}`、URL 和 fenced code block。
- 已验证：
  - `swift test --filter VoiceContinuousRewritePolicyTests` 通过，7 个测试。
  - `swift test --filter DeepSeekFinalRewriteConfigurationTests` 通过，27 个测试。
  - `swift test --disable-sandbox --quiet` 通过，153 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - 已安装新版到 `/Applications/NexVoice.app`，旧版备份：`dist/install-backups/NexVoice-20260628-125147-pre-protected-literals.app`。
  - `/Applications/NexVoice.app` 签名、Info.plist 和嵌入配置检查通过；当前版本 `0.1.56 (57)`，运行 PID `35225`。
- 待复测：
  - 在 Codex 输入框先放入 `owner/repo`、HTML 片段、`::git-create-pr{...}` 或任务 ID，再用语音追加一句；预期不再整体替换已有草稿，只在光标处插入本轮语音整理结果。

## 本轮追加（2026-06-27：上下文问答提示词收敛与鼠标 OCR 预热）

- 用户反馈：
  - 划词问答成功率已经较高。
  - 鼠标问答成功率可以，但速度体感偏慢。
  - 鼠标问答里说“翻译一下这段/这句”时，模型有时没有输出翻译，而是返回英文原文或整理后的英文。
- 日志定位：
  - 最近鼠标问答样本中，双击后先花约 `404ms / 408ms / 433ms` 做划词检测，然后才进入鼠标 OCR。
  - OCR 本身耗时约 `846ms / 609ms / 215ms`，DeepSeek 生成耗时约 `1068ms - 1744ms`。
  - `ScreenReply.jsonl` 显示 OCR 已拿到英文上下文；`DeepSeekRewrite.jsonl` 显示用户指令为“翻译一下这段/这句”，但输出仍是英文，说明主要问题不是 OCR 失败，而是鼠标问答提示词仍容易被普通“语音整理”语义带偏。
- 本轮修复：
  - `DeepSeekFinalRewriteConfiguration` 新增 `contextQuestionSystemPrompt`，划词问答和鼠标问答共用同一套上下文问答系统提示词，不再复用普通语音输入整理器的系统提示词。
  - 划词问答与鼠标问答收敛到同一个 `contextQuestionCommandPrompt` 模板，只区分上下文来源标签（`选中文本` / `鼠标附近 OCR 文字`）。
  - 新提示词保持简单规则：语音指令就是要执行的事情；翻译、解释、总结、判断、提取、改写或回答都直接执行；上下文只作为材料；信息不足时说明不足。
  - 翻译规则补齐：未指定目标语言时译成当前输出语言；如果上下文本身已经是当前输出语言，则译成另一种最自然的语言，避免英文 OCR 被“整理成英文”。
  - 双击上下文问答启动时新增鼠标 OCR 预热：在划词检测同时后台启动 OCR，但不展示 OCR 框；若最终命中划词，取消/丢弃预热；若确认无划词，采用预热结果并展示 OCR 框。
  - `MouseContextCaptureService.capture(...)` 支持自定义成功日志事件和 contextSource；预热成功记为 `mouse_visual_prewarmed`，真正被鼠标问答采用时补记 `mouse_visual_prewarm_adopted`，避免日志混淆。
  - OCR capture 增加取消检查，划词命中后尽量避免预热任务继续写入误导性日志。
- 已验证：
  - 用户复测后日志确认：鼠标问答多次出现 `mouse_visual_prewarmed` -> `mouse_visual_prewarm_adopted`，说明预热 OCR 已被实际采用。
  - 用户复测后日志确认：多次“翻译一下/翻译一下这句话”已输出中文翻译，不再复现英文原文直接返回的问题。
  - 用户复测后日志中看到一条语音指令为“没有劲儿了，现在没有劲儿了，没有力气了。”，模型按语音内容直接回答；判断为输入指令本身不清晰，不是 OCR、路由或提示词机制错误。
  - 自检已清理旧的 `selectedTextQuestionContext` 冗余入口，划词问答统一只走带诊断结果的 `selectedTextQuestionDetection`。
  - `swift test --filter DeepSeekFinalRewriteConfigurationTests` 通过，27 个测试。
  - `swift test` 通过，152 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `/Applications/NexVoice.app` 签名验证通过。
  - `/Applications/NexVoice.app/Contents/Info.plist` 校验通过。
  - 嵌入配置 `DeepSeek.json` 和 `TencentCloudASR.json` 存在且非空，未展示密钥内容。
- 已安装：
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`88007`
  - 版本：`0.1.55 (56)`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-132243-pre-context-prewarm.app`
- 本轮未做：
  - 未构建 DMG。
  - 未提交或推送 Git。
- 下一步复测重点：
  - 鼠标问答双击后，OCR 框是否比之前更快出现。
  - 英文段落上说“翻译一下这段/这句”时，是否稳定输出中文翻译。
  - 若仍慢，优先看 `Shortcut.jsonl` 的 `selected_text_detection_finished` 与 `ScreenReply.jsonl` 的 `mouse_visual_prewarmed` / `mouse_visual_prewarm_adopted` 时间差。

## 本轮追加（2026-06-27：划词检测耗时日志与鼠标问答通用指令遵循）

- 用户要求：
  - 先不要武断给划词检测加超时，必须先知道常规耗时范围，避免误伤其他软件或复杂页面。
  - 鼠标问答不只服务翻译，需要通用 prompt，让大模型把用户语音当作任务执行。
  - 后续复测发现：划词后双击仍进入鼠标 OCR，出现 OCR 框，最终回答使用 OCR 内容而不是选中文字。
  - 调研并确认：如果要接近 99% 划词成功率，纯 AX 不够；需要采用成熟开源方案常见的“AX 优先 + 受控剪贴板兜底”。
- 日志定位：
  - `Shortcut.jsonl` 显示用户复测时确实走了 `begin_context_question_mouse`。
  - `ScreenReply.jsonl` 后续事件为 `mouse_context_question`，上下文来源是 `mouse_ocr`，说明最终生成确实使用 OCR 内容。
  - 当时安装版还没有 `selected_text_detection_finished` 新日志，因此只能确认“走了 OCR”，无法从旧日志拆出划词检测失败路径。
  - 新日志里 5 次划词检测样本：Chrome 一次 `focused_chain` 真 AX 命中，耗时约 `3.5ms`；Codex / 企业微信 / 微信共 4 次命中的是临时 `clipboard_copy` 兜底，其中企业微信前置 AX 扫描 700 个节点后总耗时约 `6444ms`。
  - 结论：微信、企业微信、Codex 这类 App 的可见选区经常不通过 AX 暴露；如果不使用剪贴板读取，双击划词问答会漏到鼠标 OCR。
- 本轮修复：
  - `FocusedTextInserter` 新增划词问答检测结果，区分快路径 `focused_chain` 和递归窗口扫描 `non_editable_scan` / `not_found`。
  - `Shortcut.jsonl` 新增 `selected_text_detection_finished` 事件，记录划词检测耗时、是否命中、命中路径、选中文字数、焦点链节点数、搜索根数量、扫描节点数、是否使用递归扫描；超时时 `selectedTextDetectionSource` 为 `timed_out`。
  - 双击上下文问答仍保持原路由：先检测 AX 划词，未命中才进入鼠标 OCR 问答；本轮没有改变 OCR 区域策略。
  - 鼠标问答 prompt 改为通用“执行任务”规则：OCR 文字是上下文，用户语音是任务；要求模型执行翻译、解释、总结、判断、对比、提取、改写等动作，不得把语音指令复述成答案。
  - 对“翻译一下：原文”这种半执行结果增加明确禁止规则，但翻译只是通用任务规则中的一类，不做单一功能特判。
  - 选区读取器采用“AX 优先 + 受控剪贴板兜底”：AX 先尝试 `focused_chain` 和 `non_editable_scan`；AX 失败后临时写入唯一 marker、模拟 `Cmd+C`、读取文本、立即恢复完整剪贴板。
  - AX 递归窗口扫描保留 `250ms` 超时限制；正常 `focused_chain` 命中不受影响，复杂/临时窗口不会再拖到多秒。
  - 新路由保护：读到选区就进入划词问答；确认无选区才进入鼠标 OCR；若 AX 暗示有文字选区但剪贴板读取失败，会显示“未能读取选中文字”，不会漏到鼠标 OCR。
  - `Shortcut.jsonl` 增加受控剪贴板诊断字段：是否触发剪贴板变化、剪贴板读取耗时、读到文本长度、是否恢复成功、是否允许回落到鼠标 OCR。
- 已验证：
  - `swift test` 通过，151 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `/Applications/NexVoice.app` 签名验证通过。
  - `/Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 嵌入配置 `DeepSeek.json` 和 `TencentCloudASR.json` 存在且非空，未展示密钥内容。
- 已安装：
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`70540`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-114009-pre-selection-resolver.app`
- 本轮未做：
  - 未构建 DMG。
  - 未提交或推送 Git。

## 本轮追加（2026-06-27：快捷键延迟诊断日志）

- 用户反馈：
  - 企业微信图片临时窗口中不是完全收不到快捷键，而是可能延迟好几秒后才出现语音波形条。
  - 本轮先调查和加日志，可以先不改捕获策略。
- 判断：
  - 现有 `ScreenReply.jsonl` 显示企业微信开始 OCR 后并不慢，截图约几十毫秒，OCR 约几百毫秒；用户感知的多秒延迟更可能发生在“快捷键事件送达 NexVoice”之前或刚进入 App 路由时。
  - 当前右 Alt / Fn 快捷键使用 `NSEvent.addGlobalMonitorForEvents` + local monitor；自定义组合键才启用更底层的 `CGEventTap` 兜底。
  - 本轮未把右 Alt 改成 `CGEventTap`，避免未验证前引入重复触发、双击/长按误判等回归。
- 本轮修复：
  - 新增 `Sources/NexVoiceHost/ShortcutDiagnosticsLogger.swift`，写入 `~/Library/Application Support/NexVoice/Logs/Shortcut.jsonl`。
  - `GlobalVoiceShortcutMonitor` 记录快捷键监控启动策略、原始键盘事件来源、keyCode、事件类型、modifier flags、NSEvent 投递延迟、是否命中当前快捷键、按下/松开、单击延迟等待、双击触发、长按触发等。
  - `main.swift` 记录 App 内部分流：单击/双击/长按收到后走 `begin`、`beginContextQuestion`、`beginScreenReply`、选中文字问答、鼠标问答、普通语音输入 ASR 启动、ASR 会话开始和失败。
  - 这些日志只用于诊断，不改变单击、双击、长按现有行为。
- 新版信息：
  - 版本：`0.1.55 (56)`
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`62877`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-025105-pre-0.1.55.app`
  - 新 DMG：`dist/NexVoice-0.1.55-build56-shortcut-diagnostics-embedded-keys-20260627.dmg`
  - SHA256：`cdfe5b7df2c24163f4e0378d992de5dc6d13c45f7f57a721bf9d2825ad340bbd`
- 已验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，151 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - DMG 挂载校验通过，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。
- 下一步复测：
  - 在企业微信图片临时窗口按一次右 Alt 普通语音输入，观察是否仍然多秒后才出现波形条。
  - 复测后优先看 `Shortcut.jsonl`：如果 `keyboard_event_received.deliveryDelayMs` 已经很大，说明卡在系统事件投递；如果投递正常但 `transcription_service_start_requested` 或 `voice_session_started` 很晚，说明卡在 NexVoice 内部流程。
  - 若确认是系统事件投递延迟，再评估把右 Alt 也接入 `CGEventTap` 兜底。

## 本轮追加（2026-06-27：修复鼠标 OCR 框偏小、ASR 截断、双击后立刻结束）

- 用户复测反馈：
  - OCR 框明显比识别到的文字小，且有很多识别不出来的情况。
  - 单次快捷键普通语音输入中途像被打断，最终只显示前面一小段。
  - 企业微信图片窗口中双击后仍可能什么都不出现，没有稳定进入鼠标回答状态。
- 日志定位：
  - `ScreenReply.jsonl` 中新链路已进入 `mouse_visual_captured`，但例子里长句被 OCR 成 `What books would you recommend for learning Machine Lea`，说明鼠标屏幕截图取样区域太窄，文字尾部落在截图边缘外。
  - `TencentCloudASR.jsonl` 中 session `1292334A-4FEB-48B7-B55A-182641563988` 在 29 秒时已有 92 字完整识别，但随后同一分片又收到一条空的 `sliceType=2` 稳定结果，导致最终文本被覆盖成 20 字。
  - 企业微信相关记录里，问答录音启动后 0.14-0.15 秒就出现 `finish_requested`，随后 `no_speech`；这不是 OCR 慢，而是双击残留事件把刚开始的上下文问答录音立刻结束了。
- 本轮修复：
  - 鼠标问答仍保持纯视觉逻辑，但屏幕 OCR 取样区域从 `520x300` 扩到 `900x380`，兜底扩展到 `1280x620`；最终上下文仍只取鼠标附近自然段，不回到窗口扫描。
  - 鼠标 OCR 从 Vision `.fast` 改为 `.accurate` 并开启语言纠错，优先提高截图中文字识别完整度。
  - 修复腾讯云 ASR 分片合并：同一个 index 已有较长稳定文本时，后来的空分片或明显过短分片不能覆盖它。
  - 增加回归测试，覆盖“腾讯云后补空 ended 分片不应截断完整识别文本”的场景。
  - 上下文问答启动后 0.65 秒内忽略误触发的结束录音请求，并写入 `context_question_early_finish_ignored` 日志；普通单击语音输入不受影响。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，151 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.53-build54-mouse-ocr-asr-fix-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`12318`
  - 旧版备份：`dist/install-backups/20260627-022612-NexVoice.app`
  - 新 DMG：`dist/NexVoice-0.1.53-build54-mouse-ocr-asr-fix-embedded-keys-20260627.dmg`
- Git：
  - 本轮本地提交：`Stabilize mouse OCR and ASR sessions`
  - 当前 `main` 比 `origin/main` 多 10 个提交。
  - 远端推送仍失败：`fatal: could not read Username for 'https://github.com': Device not configured`，需要用户补 GitHub HTTPS 凭据后再推送。
- 需要用户复测：
  - 网页长句或图片中文字上双击，OCR 框是否能覆盖完整句子而不是半截。
  - 普通单击语音输入长句，是否不再被后续空分片截断成前半句。
  - 企业微信图片窗口中双击后，是否稳定显示 OCR 框和语音波形；如仍没反应，看 `ScreenReply.jsonl` 是否出现 `context_question_early_finish_ignored`。

## 本轮追加（2026-06-27：鼠标问答改为独立纯视觉 OCR 链路）

- 用户要求：
  - 看屏回复和鼠标问答必须是两套不同逻辑，不要混淆或耦合。
  - 鼠标问答应是纯视觉逻辑：围绕鼠标位置截屏、OCR、选取附近文字上下文，再进行问答。
  - 需要继续保留日志，能看清每次鼠标问答实际抓取了什么区域和什么文字。
- 本轮修复：
  - 新增 `MouseContextCaptureService`，鼠标问答不再调用 `ScreenReplyContextCaptureService.capture(...)`。
  - 鼠标问答不再扫描前台窗口列表，不再依赖前台窗口标题、窗口大小、窗口坐标，也不再走看屏回复的输入框/回复区域推断。
  - 双击鼠标问答现在直接按鼠标屏幕坐标截取周边屏幕区域，用 Vision OCR 识别本地文字。
  - OCR 框立即显示在鼠标附近；真正识别完成后，框会收缩到实际进入问答上下文的文字自然段。
  - 为避免 OCR 框污染截图，截图时使用“OCR 覆盖层下面”的屏幕内容，不把蓝色高亮层自身截进去。
  - `visibleText`、`lines.includedInReplyContext`、`mouseRegionInScreen` 使用同一批 OCR 行，避免“框很小但回答用了更大上下文”的错位。
  - `ScreenReply.jsonl` 新增 `screenCaptureRegion` 字段；鼠标问答新增 `mouse_visual_captured`、`mouse_visual_no_text`、`mouse_visual_region_missed` 事件，能看到屏幕截图范围、最终框选范围、OCR 文本、耗时和失败原因。
  - 鼠标问答生成、成功、失败日志补齐 `mouseRegionInScreen`，方便按同一 `captureID` 串起来排查。
- 明确保留的边界：
  - 长按“看屏回复”仍由 `ScreenReplyContextCaptureService` 负责，继续按窗口和输入框上下文处理。
  - 双击“鼠标问答”由 `MouseContextCaptureService` 负责，纯屏幕视觉 OCR，不调用看屏回复捕获逻辑。
  - 划词问答仍走选中文字，不受鼠标 OCR 改动影响。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=2 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.52-build53-visual-mouse-ocr-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`82017`
  - 旧版备份：`dist/install-backups/20260627-021245-NexVoice.app`
  - 新 DMG：`dist/NexVoice-0.1.52-build53-visual-mouse-ocr-embedded-keys-20260627.dmg`
- Git：
  - 本轮本地提交：`Decouple mouse context OCR capture`
  - 当前 `main` 比 `origin/main` 多 9 个提交。
  - 远端推送仍失败：`fatal: could not read Username for 'https://github.com': Device not configured`，需要用户补 GitHub HTTPS 凭据后再推送。
- 需要用户复测：
  - 企业微信图片预览窗口在前台时，双击鼠标问答应能立即出现 OCR 框并进入录音问答流程。
  - 普通网页或图片中文字上双击时，OCR 框应覆盖实际进入回答上下文的自然段，不再出现框和回答内容不一致。
  - `~/Library/Application Support/NexVoice/Logs/ScreenReply.jsonl` 中同一 `captureID` 的 `screenCaptureRegion`、`mouseRegionInScreen`、`visibleText` 应能解释本次回答用了什么上下文。

## 本轮追加（2026-06-27：调整 OCR 高亮层级、样式和范围）

- 用户复测反馈：
  - OCR 高亮框不应该盖住回答气泡；气泡层应该永远在最上面。
  - OCR 高亮应高于当前焦点窗口，尤其是企业微信图片预览窗口，但低于气泡。
  - OCR 高亮样式不需要外描边，只保留内部半透明颜色。
  - OCR 判定范围仍略大，临时框和最终框都需要再收紧。
- 本轮修复：
  - `OCRRegionOverlayController` 的窗口层级改为 `statusBar - 1`：高于普通窗口和大多数浮动图片窗口，但低于回答气泡的 `statusBar` 层。
  - OCR 高亮去掉蓝色描边，只保留半透明蓝色填充，并减小外扩 padding。
  - 鼠标 OCR 裁剪区域从较大的窗口局部区域进一步缩小，减少远处文字进入 OCR 候选。
  - 鼠标命中文字自然段最多扩展 5 行，并增加最终高亮宽高上限，避免长行或整块卡片被框得过大。
  - 双击后立即出现的临时候选框从 `520x280` 缩小到 `380x190`。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=4 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.51-build52-ocr-overlay-layer-style-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`42316`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-015204.app`
  - 新 DMG：`dist/NexVoice-0.1.51-build52-ocr-overlay-layer-style-embedded-keys-20260627.dmg`
- Git：
  - 本地提交：`35b028b Refine OCR overlay layering`
  - 当前 `main` 比 `origin/main` 多 8 个提交。
  - 远端推送仍失败：当前机器无法读取 GitHub HTTPS 用户名，需要用户补 GitHub 凭据后再推送。
- 需要用户复测：
  - 回答气泡出现时，OCR 高亮应在气泡下面，不再盖住气泡。
  - 企业微信图片预览窗口中，OCR 高亮应能盖在图片窗口上方。
  - OCR 高亮应只显示填充色，不再有外描边。

## 本轮追加（2026-06-27：降低鼠标 OCR 延迟，修正 OCR 框定位）

- 用户复测反馈：
  - 鼠标问答双击后 OCR 框不是实时出现，经常要等 1-2 秒。
  - OCR 框定位不稳定，有时框在空白处或只框到一小块无关内容。
- 日志和代码定位：
  - 旧流程是双击后先截取整个前台窗口，再对整张窗口截图跑 Vision OCR，最后才显示 OCR 框；窗口文字越多，框出现越慢。
  - 鼠标屏幕坐标和 Vision OCR 图片坐标的 Y 轴方向不一致；旧代码直接换算，导致鼠标附近搜索可能落到上下错位的位置。
  - 鼠标问答找不到可靠文字时，旧链路仍可能先退回 replyRegion，容易拿到大范围或远处内容。
- 本轮修复：
  - 鼠标问答双击后立即显示一个鼠标附近临时候选框，给用户即时反馈。
  - 鼠标 OCR 不再识别整个窗口；现在只裁剪双击鼠标附近区域做 OCR，再把结果映射回原窗口坐标。
  - 鼠标裁剪 OCR 使用 Vision `.fast` 且关闭语言纠错；普通看屏回复仍保留 `.accurate`。
  - 修正鼠标专用坐标换算：AppKit 鼠标屏幕点 -> Quartz 窗口坐标 -> OCR 图片坐标；OCR 框回屏幕时再转回 AppKit 坐标。
  - 鼠标问答如果裁剪区域里没有可靠命中文字，直接返回“未识别到鼠标附近文字”，不再退回整屏/大区域。
  - `ScreenReply.jsonl` 增加定位和耗时字段：`windowBounds`、`mouseScreenLocation`、`mouseImageLocation`、`ocrCropRegion`、`captureDurationMs`、`ocrDurationMs`；同时新增 `mouse_region_missed` 事件，方便排查。
- 当前行为：
  - 双击无划词后，屏幕会立即出现鼠标附近候选框。
  - OCR 完成后，候选框会缩到真实命中的文字自然段。
  - 如果鼠标附近没有可靠文字，候选框会隐藏并提示未识别到鼠标附近文字。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=4 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.50-build51-fast-mouse-ocr-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`26918`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-014129.app`
  - 新 DMG：`dist/NexVoice-0.1.50-build51-fast-mouse-ocr-embedded-keys-20260627.dmg`
- Git：
  - 本地提交：`656b33c Speed up mouse OCR context capture`
  - 当前 `main` 比 `origin/main` 多 7 个提交。
  - 远端推送仍失败：当前机器无法读取 GitHub HTTPS 用户名，需要用户补 GitHub 凭据后再推送。
- 需要用户复测：
  - 无划词双击鼠标问答：确认候选框是否立即出现。
  - 在网页/X/图片文字上测试：确认最终 OCR 框是否贴近鼠标指向的文字自然段。
  - 如仍偏移，看 `ScreenReply.jsonl` 中同一 `captureID` 的 `mouseScreenLocation`、`mouseImageLocation`、`ocrCropRegion`、`mouseRegionInScreen` 和 `ocrDurationMs`。

## 本轮追加（2026-06-27：固定双击问答气泡位置，收紧 OCR 框）

- 用户复测反馈：
  - 双击后的划词问答和鼠标问答，气泡位置仍会在不同状态间漂移。
  - 期望两种问答都固定出现在鼠标旁边，并且同一次会话内波形、loading、回答都保持同一个位置。
  - 鼠标 OCR 框选范围过大；期望只识别鼠标指向文字所在的自然段。
  - OCR 框应在双击后尽早出现；回答消失时 OCR 框也应同步消失，不要额外停留几秒。
- 本轮修复：
  - 双击入口会立即冻结当时的鼠标位置；划词问答和鼠标问答都使用这个鼠标锚点，不再使用选区位置或后续移动后的鼠标位置。
  - `VoiceCaptionPanelController` 的上下文浮层改为固定贴在鼠标右侧，靠近屏幕边缘时才切到左侧；不再因为波形、loading、回答高度不同而上下跳。
  - 鼠标 OCR 高亮不再固定 8 秒自动隐藏；现在由回答气泡生命周期控制，回答气泡关闭时同步隐藏 OCR 框。
  - 鼠标 OCR 文字块算法从“向周围同列模块扩展”改成“鼠标命中的文字行 + 上下紧邻且横向对齐的同自然段行”，并限制最多 8 行、限制最大高度，避免框住整块网页模块。
- 当前行为：
  - 双击右 Alt + 有选中文字：基于选中文字问答，但波形和回答固定出现在双击时鼠标旁边。
  - 双击右 Alt + 无选中文字：基于双击时鼠标位置做 OCR；OCR 框尽早显示，范围更接近自然段；回答气泡消失时 OCR 框同步消失。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=4 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.49-build50-stable-context-bubble-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`4174`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-012723.app`
  - 新 DMG：`dist/NexVoice-0.1.49-build50-stable-context-bubble-embedded-keys-20260627.dmg`
- Git：
  - 本地提交：`93a4edf Stabilize context QA bubble placement`
  - 当前 `main` 比 `origin/main` 多 6 个提交。
  - 远端推送仍失败：当前机器无法读取 GitHub HTTPS 用户名，需要用户补 GitHub 凭据后再推送。
- 需要用户复测：
  - 双击划词问答：确认波形、loading、回答都在双击时鼠标旁边，不随选区位置漂移。
  - 双击鼠标问答：确认 OCR 框范围接近自然段，不框住整块模块；回答气泡消失时 OCR 框同步消失。

## 本轮追加（2026-06-27：统一双击问答流程，并高亮鼠标 OCR 范围）

- 用户确认本轮目标：
  - 鼠标问答的触发是“双击右 Alt 两次短按”，不是第二下长按。
  - 划词问答和鼠标问答的交互流程要一致：双击开始录音，显示波形，说完后再按一次结束，然后在划词/鼠标附近显示回答。
  - 没有划词时，双击触发鼠标 OCR 问答，并且 OCR 覆盖范围必须在屏幕上明确标出来。
- 本轮修复：
  - `GlobalVoiceShortcutMonitor` 在识别到双击第二下后不再安排长按定时器，避免“双击第二下稍微按久一点”误触发长按看屏回复。
  - 鼠标问答不再走旧的看屏回复状态机；现在和划词问答一样先展示波形并开始收音，语音 final 后再用 OCR 上下文生成回答。
  - 鼠标问答的提示条和最终回答固定锚定在双击时的鼠标位置，不再跟随 OCR 大区域漂移。
  - OCR 捕获任务改为独立后台任务；它可以和录音并行，减少用户看到的状态跳转。
  - 新增 `OCRRegionOverlayController`：没有划词时，鼠标 OCR 命中的文字模块会以蓝色半透明边框高亮，默认 8 秒后自动隐藏；取消、失败、切换到其他模式会立即隐藏。
  - `ScreenReply.jsonl` 增加 `mouseRegionInScreen` 字段；同一个 `captureID` 下可以看到窗口内 OCR 区域、屏幕坐标区域、`visibleText`、`lines`、语音指令和最终回答。
  - 清理旧的鼠标问答兼容分支，避免鼠标问答和看屏回复继续共用状态导致互相打架。
- 当前行为：
  - 单击右 Alt：普通语音输入；再次单击结束并写入当前输入位置。
  - 双击右 Alt + 有选中文字：基于选中文字问答，波形和回答出现在选区附近，不覆盖文本。
  - 双击右 Alt + 无选中文字：基于鼠标附近 OCR 文字问答，波形和回答出现在鼠标附近，同时屏幕上高亮 OCR 覆盖范围。
  - 长按右 Alt：保留原看屏回复链路，仍按输入框看屏回复方式工作。
- 已验证：
  - `git diff --check` 通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `codesign --verify --deep --strict --verbose=4 /Applications/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.48-build49-mouse-ocr-highlight-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`72762`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-011409.app`
  - 新 DMG：`dist/NexVoice-0.1.48-build49-mouse-ocr-highlight-embedded-keys-20260627.dmg`
- Git：
  - 本地已提交；当前 `main` 比 `origin/main` 多 5 个提交。
  - 远端推送仍失败：当前机器无法读取 GitHub HTTPS 用户名，需要用户补 GitHub 凭据后再推送。
- 需要用户复测：
  - 没有划词时，把鼠标放到网页/图片/PDF/聊天窗口中一段文字附近，双击右 Alt 后说问题，再单击结束。
  - 预期：先在鼠标附近出现波形；OCR 命中的文字模块出现蓝色高亮；结束后回答固定显示在鼠标附近，不写入输入框。
  - 如需排查，查看 `~/Library/Application Support/NexVoice/Logs/ScreenReply.jsonl` 中同一 `captureID` 的 `visibleText`、`mouseRegionInScreen`、`voiceInstruction` 和 `replyPreview`。

## 本轮追加（2026-06-27：修复双击问答误落回普通输入）

- 用户复测反馈：
  - 单击和长按正常。
  - 双击问答经常落回普通语音输入，结果进入 Codex / 搜索框，用户无法分清是在回答问题还是写入文本。
  - 双击问答期间提示条也不稳定，应该始终贴近鼠标或划词位置。
- 日志结论：
  - 最新 `ContinuousRewrite.jsonl` 出现多条 `final_rewrite` / `inserted`，例如 Codex 中双击测试内容进入了普通输入链路。
  - 同期 `ScreenReply.jsonl` 没有新的 `selected_text_question` 或 `mouse_context_question`，说明主要问题是双击没有被稳定识别，而不是 AI 回答生成后显示错位置。
- 本轮修复：
  - `GlobalVoiceShortcutMonitor.doubleTriggerInterval` 从 `0.28s` 调整为 `0.50s`，避免第二下稍慢就先触发单击普通输入。
  - `VoiceCaptionPanelController.showOverlay(...)` 支持传入锚点；划词问答开始录音时直接锚定在选中文字附近。
  - 录音过程中的 `识别到指令`、`AI 回答中` 状态继续使用鼠标/划词锚点，不再跳回底部。
  - 鼠标 OCR 问答在等待语音 final 或停止录音后的加载状态，也会继续锚定鼠标附近。
- 已验证：
  - `git diff --check` 通过。
  - `swift test --disable-sandbox --filter VoiceShortcut --quiet` 通过，20 个相关测试。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `/Applications/NexVoice.app` 签名验证通过。
  - `/Applications/NexVoice.app` 版本号检查通过：`0.1.47 (48)`。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.47-build48-double-shortcut-fix-embedded-keys-20260627.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`7047`
  - 旧版备份：`dist/install-backups/NexVoice-20260627-001715.app`
  - 新 DMG：`dist/NexVoice-0.1.47-build48-double-shortcut-fix-embedded-keys-20260627.dmg`
- Git：
  - 本地提交：`d8100ef Fix double shortcut context QA routing`
  - 当前本地 `main` 比 `origin/main` 多 4 个提交；远端推送仍需要用户补 GitHub 凭据。

## 本轮追加（2026-06-26：撤销焦点路由，改为双击上下文问答）

- 用户确认新交互：
  - 避免任何需要判断“当前是否在输入框焦点”的路由行为。
  - 单击快捷键只负责普通语音输入；如果输入框里已有可编辑选区，仍由系统粘贴行为自然覆盖选中文本，保留“划词改写/覆盖”这条路。
  - 双击快捷键进入上下文问答：优先读取当前选中文字作为上下文；如果没有选中文字，再读取鼠标附近 OCR 文字作为上下文。
  - 长按快捷键继续保留看屏回复，不和单击/双击互抢。
- 本轮实现：
  - `GlobalVoiceShortcutMonitor` 新增双击识别；只在空闲态给单击等待约 0.28 秒的双击窗口，录音中单击停止不会被延迟。
  - `VoiceShortcutTriggerPolicy` 显式区分单击/双击：单击为普通输入开始/结束，双击仅在空闲态进入上下文问答。
  - `beginTranscriptionAfterSelectionCapture()` 已移除 `hasStrictFocusedEditableInput` 路由，不再因为焦点误判切到鼠标问答。
  - `FocusedTextInserter.selectedTextQuestionContext(...)` 新增“问答用选中文字读取”；它只判断是否存在选中文字，不再把焦点框作为模式路由依据。
  - 双击上下文问答路由顺序固定为：选中文字问答 -> 鼠标 OCR 问答。
  - `ScreenReply.jsonl` 增加选中文字问答日志字段：`contextSource`、`selectedTextCharacters`、`selectedText`，并记录 `context_question_captured/generating/succeeded/failed`。
- 当前行为：
  - 单击右 Alt：普通语音输入；再单击结束并写入当前输入位置。
  - 输入框内选中文字后单击右 Alt：语音结果会按原有写入链路覆盖选区。
  - 双击右 Alt：如果有选中文字，基于选中文字问答，结果显示在浮层，不覆盖文本；如果没有选中文字，则基于鼠标附近 OCR 问答。
  - 长按右 Alt：保留原看屏回复链路。
- 已验证：
  - `git diff --check` 通过。
  - `swift test --disable-sandbox --filter VoiceShortcut --quiet` 通过，20 个相关测试。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `/Applications/NexVoice.app` 签名验证通过。
  - `/Applications/NexVoice.app` 版本号检查通过：`0.1.46 (47)`。
  - `/Applications/NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在，未在日志或进展中展示密钥内容。
  - `hdiutil verify dist/NexVoice-0.1.46-build47-double-shortcut-context-qa-embedded-keys-20260626.dmg` 通过。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 当前运行 PID：`75127`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-235956.app`
  - 新 DMG：`dist/NexVoice-0.1.46-build47-double-shortcut-context-qa-embedded-keys-20260626.dmg`
- Git：
  - 本地提交：`9215102 Route context Q&A through double shortcut`
  - 当前本地 `main` 比 `origin/main` 多 3 个提交；前两次远端推送受当前机器 GitHub 凭据限制失败，仍需用户补 GitHub 凭据后推送。

## 本轮追加（2026-06-26：短按按焦点路由输入框/鼠标 OCR 问答）

> 重要：本节记录的是上一轮已验证不稳定的方案；当前实现已由“撤销焦点路由，改为双击上下文问答”替代。后续不要继续沿用“按焦点判断输入框/鼠标问答”的产品方向。

- 用户确认新路由：
  - 短按快捷键时，如果当前焦点在输入框，走普通语音输入。
  - 短按快捷键时，如果当前焦点不在输入框，走鼠标 OCR 问答。
  - 划词问答默认下线，不再作为短按的默认分支。
  - 长按快捷键仍保留为输入框场景的看屏回复；长按看屏回复不再传入鼠标位置，避免被鼠标 OCR 抢路由。
- 本轮实现：
  - `FocusedTextInserter.hasStrictFocusedEditableInput(in:)` 新增严格输入框焦点判断：只看当前 AX 焦点链是否为可编辑输入框，不使用底部输入框兜底、不扫描窗口、不看鼠标位置。
  - `beginTranscriptionAfterSelectionCapture()` 在短按开始时先做严格焦点判断；非输入框直接进入 `beginMouseContextQuestion()`。
  - 鼠标 OCR 问答不再按“介绍/总结/翻译”等关键词判断；只要短按时焦点不在输入框，就固定走 `mouse_context_command`。
  - 原 `VoiceMouseContextCommandPolicy` 关键词路由和对应测试已删除，避免未来误导。
  - `ScreenReply.jsonl` 新增 `interactionMode`，区分 `focused_input_screen_reply` 与 `mouse_context_question`。
- 当前行为：
  - 输入框内短按：普通语音输入，最终写入输入框。
  - 非输入框短按：读取鼠标附近 OCR 文字，语音问题结束后显示鼠标附近浮层答案，不自动写入输入框。
  - 输入框内长按：看屏回复，最终写入输入框。
- 版本递增：`0.1.44 (45)` -> `0.1.45 (46)`。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-233114.app`
  - 当前运行 PID：`33721`
  - 新 DMG：`dist/NexVoice-0.1.45-build46-focus-routed-mouse-ocr-embedded-keys-20260626.dmg`
- 验证：
  - `git diff --check` 通过。
  - `swift test --disable-sandbox --filter DeepSeekFinalRewriteConfiguration --quiet` 通过，26 个测试。
  - `swift test --disable-sandbox --quiet` 通过，149 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `/Applications/NexVoice.app` 签名、版本号和嵌入配置检查通过。
  - `hdiutil verify dist/NexVoice-0.1.45-build46-focus-routed-mouse-ocr-embedded-keys-20260626.dmg` 通过。
- 需要用户复测：
  - 点击输入框后短按右 Alt：应进入普通语音输入，不应触发鼠标 OCR 问答。
  - 不点击输入框、鼠标指向网页/图片/PDF/聊天窗口文字后短按右 Alt：应进入鼠标 OCR 问答，结果显示为鼠标附近浮层。
  - 点击输入框后长按右 Alt：应进入原看屏回复并写入输入框。
  - 日志中应能看到 `interactionMode=mouse_context_question` 或 `interactionMode=focused_input_screen_reply`。

## 本轮追加（2026-06-26：鼠标位置 OCR 问答第一阶段/第二阶段）

- 用户明确范围：
  - 只针对文字做 OCR，不引入图片视觉模型。
  - 优先完成第一阶段“鼠标附近文字块捕获 + 问答”和第二阶段“浮层结果展示”。
  - 必须记录日志，让用户能看到每次指令实际抓到了什么文字。
- 本轮实现：
  - 长按右 Alt 进入看屏语音指令时，会把当前鼠标位置传给 `ScreenReplyContextCaptureService`。
  - OCR 识别当前前台窗口后，优先找鼠标附近命中的文字行，并按周边同列/同段落关系扩展成一个文字块。
  - 如果鼠标附近找不到可靠文字块，回退到原来的看屏回复区域逻辑。
  - 如果语音指令像问答/总结/解释/翻译/分析类问题，走新的 `mouse_context_command`，答案以鼠标附近浮层展示并可复制，不自动写入输入框。
  - 如果语音指令不像问答，例如“用更强硬一点回复第二句”，仍保留原来的看屏回复插入逻辑，避免破坏旧能力。
- 日志：
  - 仍写入 `~/Library/Application Support/NexVoice/Logs/ScreenReply.jsonl`。
  - 新增/扩展字段：`captureMode`、`mouseLocation`、`mouseRegion`、`lines[].includedInReplyContext`。
  - 新增事件：`mouse_context_generating`、`mouse_context_succeeded`、`mouse_context_failed`。
  - 复测时重点看 `captureMode=mouseRegion`，以及 `includedInReplyContext=true` 的 OCR 行是否就是鼠标附近应被回答的文字块。
- 版本递增：`0.1.43 (44)` -> `0.1.44 (45)`。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-230905.app`
  - 当前运行 PID：`92095`
  - 新 DMG：`dist/NexVoice-0.1.44-build45-mouse-context-ocr-embedded-keys-20260626.dmg`
- 验证：
  - `git diff --check` 通过。
  - `swift test --disable-sandbox --filter DeepSeekFinalRewriteConfiguration --quiet` 通过，27 个测试。
  - `swift test --disable-sandbox --quiet` 通过，150 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `/Applications/NexVoice.app` 签名、版本号和嵌入配置检查通过。
  - `hdiutil verify dist/NexVoice-0.1.44-build45-mouse-context-ocr-embedded-keys-20260626.dmg` 通过。
- 需要用户复测：
  - 把鼠标放到网页/图片/PDF/聊天窗口中一段可见文字附近，长按右 Alt 后问“这是什么意思 / 帮我总结一下 / 这个合理吗”。
  - 预期：答案以鼠标附近浮层显示，不自动插入输入框。
  - 复测后查看 `ScreenReply.jsonl`，确认 `visibleText` 和 `includedInReplyContext=true` 的行是否符合鼠标附近文字块。

## 本轮接力（2026-06-26：拉取最新 main 并构建启动）

- 已安全接力最新远端代码：
  - 先确认本地工作区干净。
  - `git fetch --all --prune` 后发现远端 `main` 从 `b7b19f9` 更新到 `23e0f25`。
  - `git pull --ff-only` 已把本地 `main` 快进到 `23e0f25 Fix trusted draft handling and English rewrite output`。
- 当前进展判断：
  - 最新主线是修复 Web / Electron / Codex 输入框提示文案被误当成真实草稿的问题。
  - 同时修复英文输出模式下 DeepSeek 返回 `Here's the polished version...` 这类说明性外壳的问题。
  - 仍需要用户做真实右 Alt 语音复测；重点看 Codex / Chrome 空输入框提示文案是否不再进入输出或 DeepSeek 上下文。
- 已构建并安装新版：
  - App：`dist/NexVoice.app`
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-224227.app`
  - 当前运行 PID：`42973`
  - 包内版本：`0.1.43 (44)`
  - 已确认包内包含本机 `DeepSeek.json` 与 `TencentCloudASR.json` 嵌入配置，未暴露密钥内容。
- 验证：
  - `git diff --check` 通过。
  - `swift test --disable-sandbox --quiet` 通过，148 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - `/Applications/NexVoice.app` 签名、版本号和嵌入配置检查通过。

## 本轮追加（2026-06-26：修复英文输出时模型说明外壳泄漏）

- 用户切到英文输出后复测发现：
  - 说“互动百科工作流”时，DeepSeek 偶发返回 `Here's the polished version of your input:` / `Here’s the cleaned-up version of your input:` 这类说明性外壳。
  - 本地插入阶段会把清洗后的结果直接写入，因此外壳残留会进入真实输入框。
- 日志定位：
  - `ContinuousRewrite.jsonl` 显示这些轮次都是 `insertAtCursor`，不是连续改写或可信草稿机制导致。
  - `DeepSeekRewrite.jsonl` 显示 ASR 原文是 `互动百科工作流。`，异常出现在 DeepSeek 英文改写返回阶段。
  - 个人词库只有 `web端的GPT`，没有 `互动百科工作流`，所以不是词库把英文译文强制保护回中文。
- 本轮修复：
  - `VoiceRewritePromptPolicy.systemPrompt` 增加明确输出契约：不要输出“以下是 / Here is / Here's the rewritten text”等说明性前缀。
  - 英文输出指令增加硬约束：只返回最终英文正文，不加 label、解释、Markdown、引号或 `Here's the cleaned-up version...` 这类前缀。
  - `VoiceRewriteOutputSanitizer` 扩展英文 meta 前缀清洗，覆盖日志中真实出现的 `polished version of your input`、`cleaned-up version of your input`、弯引号 `Here’s` 和 Markdown 加粗包装。
- 当前取舍：
  - 这不是按用户内容做硬编码删除，不会识别并抹掉某个用户说过的词；只清理模型自己添加的说明性外壳。
  - 如果模型把中文短语保留为专名而不是翻译，当前修复不会强行二次翻译；但 prompt 已更明确要求英文模式只返回最终英文正文。
- 已构建并安装新版：
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-153829.app`
  - 当前运行 PID：`20472`
  - 包内版本仍为 `0.1.43 (44)`；本轮未提交，未触发版本 hook，属于同版本号下的本地修正版。
  - 新 DMG：`dist/NexVoice-0.1.43-build44-english-output-guard-embedded-keys-20260626.dmg`
- 验证：
  - 先写失败测试：覆盖日志里的 `Here's the polished version of your input:` 与 `Here’s the cleaned-up version of your input:`；初次运行失败并复现残留。
  - `swift test --disable-sandbox --filter DeepSeekFinalRewriteConfiguration --quiet` 通过，25 个测试。
  - `swift test --disable-sandbox --quiet` 通过，148 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - `hdiutil verify dist/NexVoice-0.1.43-build44-english-output-guard-embedded-keys-20260626.dmg` 通过。
  - `/Applications/NexVoice.app` 签名、版本号和嵌入配置检查通过。
- 需要用户复测：
  - 英文输出模式下再说短中文词组，例如“互动百科工作流”，不应再出现 `Here's...` 说明性前缀或 Markdown 加粗。
  - 如果模型仍把短中文专名原样保留，需要再单独判断“哪些中文短语应该翻译，哪些应该作为专名保留”的策略。

## 本轮追加（2026-06-26：阻止 Web/Electron 输入框提示文案污染连续改写）

- 用户复测发现更严重问题：
  - Codex 空输入框中的灰色示例文案 `要求后续变更` 会被 AXValue 读成真实草稿。
  - Chrome / ChatGPT Web 也会把提示性文案（如 `继续追问`、`有问题，尽管问`）作为输入框 Value 暴露，导致 NexVoice 把提示文案合并进最终文本。
  - 用户明确不要靠硬编码某几个提示字来抹除，需要更通用的机制。
- 根因：
  - 当前逻辑把“AXValue 非空”直接等同于“用户已有草稿”，这个假设在 Web / Electron / WebView 输入框里不成立。
  - 现有 placeholder 过滤只检查同一个 AX 元素的 `AXPlaceholderValue / AXDescription / AXTitle / AXHelp`；当 Web 把提示文案直接暴露成 `AXValue` 时无法识别。
- 本轮修复：
  - `VoiceContinuousRewritePolicy.decision(...)` 新增 `focusedDraftIsTrusted` 参数；非可信草稿一律不触发连续改写，按空输入框处理。
  - `FocusedDraftSnapshot` 新增 `requiresTrustValidation`；Chrome/Safari/Edge/Brave/Firefox/Arc/Codex 或 AX 树中包含 `AXWebArea` 的输入框草稿会被视为弱草稿，需要额外可信证据。
  - App 记录 NexVoice 上一轮成功写入的文本、目标 App bundle 和进程；弱草稿只有与这条可信写入记录一致或包含关系明确时，才允许进入连续改写。
  - `ContinuousRewrite.jsonl` 新增 `focusedDraftTrusted` 字段，后续复测可以直接看到是否因弱草稿被拦截。
  - 没有恢复固定文案兜底，也没有新增针对 `要求后续变更` / `继续追问` 的硬编码过滤。
- 当前取舍：
  - Web/Electron 场景首次语音会更保守：即使 AXValue 非空，只要不能证明是真草稿，就不会触发连续改写。
  - NexVoice 成功写入后，下一轮同 App / 同进程读到相同或延续内容，会恢复连续改写。
  - 如果用户手动在 Web 输入框里先输入一段草稿，再第一次用 NexVoice 接着说，本轮可能不会做整体改写；这是为了优先避免提示文案污染。
- 已构建并安装新版：
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-130750.app`
  - 当前运行 PID：`35622`
  - 包内版本仍为 `0.1.43 (44)`；本轮未提交，未触发版本 hook，属于同版本号下的本地修正版。
  - 新 DMG：`dist/NexVoice-0.1.43-build44-trusted-draft-embedded-keys-20260626.dmg`
- 验证：
  - 先写失败测试：非可信草稿不应触发连续改写；初次运行因 API 缺失失败。
  - `swift test --disable-sandbox --filter VoiceContinuousRewrite --quiet` 通过，6 个测试。
  - `swift test --disable-sandbox --quiet` 通过，146 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - `hdiutil verify dist/NexVoice-0.1.43-build44-trusted-draft-embedded-keys-20260626.dmg` 通过。
- 需要用户复测：
  - 在 Codex 空输入框直接语音，`ContinuousRewrite.jsonl` 应显示 `focusedDraftCharacters=7` 但 `focusedDraftTrusted=false`，`insertionMode=insertAtCursor`。
  - 在 Chrome / ChatGPT Web 空输入框直接语音，提示文案不应被带入最终文本。
  - NexVoice 写入第一句后，第二句继续说同一段内容，应重新出现可信连续改写。

## 本轮追加（2026-06-26：非可信输入框片段不再进入 DeepSeek 上下文）

- 用户复测后日志确认：
  - Codex 最新语音读到 `要求后续变更`，但 `focusedDraftTrusted=false`，`insertionMode=insertAtCursor`，最终写入未带入该提示文案。
  - Chrome / ChatGPT Web 最新语音读到 `有问题，尽管问`，但 `focusedDraftTrusted=false`，`insertionMode=insertAtCursor`，最终写入未带入该提示文案。
- 发现剩余风险：
  - 虽然非可信草稿不再参与连续改写，但 DeepSeek prompt 的 `当前上下文` 里仍会包含 `输入框片段`，例如 `要求后续变更` / `有问题，尽管问`。
  - 当前模型没有把它写进输出，但更彻底的方案是：非可信草稿也不作为上下文片段传给模型。
- 本轮修复：
  - `VoiceRewriteContext` 新增 `removingFocusedTextPreview()`，可保留 App、bundle、焦点角色、说明、词库等上下文，但移除输入框片段。
  - 录音开始时，如果读到的草稿不可信，会在构造 `rewriteContextForCurrentSession` 后移除 `focusedTextPreview`，避免提示文案进入 DeepSeek prompt。
  - 不影响可信草稿：NexVoice 上一轮成功写入后，下一轮同 App / 同进程读到匹配草稿，仍允许作为上下文和连续改写来源。
- 当前取舍：
  - Web/Electron 中用户手动先写的真实草稿，如果无法被证明可信，首次语音不会把它交给 DeepSeek 作上下文；这是为了彻底避免提示文案污染。
  - 这个取舍比把提示文案给模型再要求“不要写入结果”更稳。
- 已构建并安装新版：
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-132217.app`
  - 当前运行 PID：`62688`
  - 包内版本仍为 `0.1.43 (44)`；本轮未提交，未触发版本 hook，属于同版本号下的本地修正版。
  - 新 DMG：`dist/NexVoice-0.1.43-build44-trusted-draft-context-sanitized-embedded-keys-20260626.dmg`
- 验证：
  - 先写失败测试：`VoiceRewriteContext.removingFocusedTextPreview()` 应移除 prompt 中的输入框片段；初次运行因方法缺失失败。
  - `swift test --disable-sandbox --filter VoiceRewriteContext --quiet` 通过，8 个测试。
  - `swift test --disable-sandbox --quiet` 通过，147 个测试。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - `hdiutil verify dist/NexVoice-0.1.43-build44-trusted-draft-context-sanitized-embedded-keys-20260626.dmg` 通过。
- 需要用户复测：
  - Codex / Chrome 空输入框直接语音时，DeepSeek prompt 里不应再出现 `输入框片段` 下的提示文案。
  - 如果用户手动输入真实草稿后第一次用语音续写，Web/Electron 场景可能仍按空输入框处理；后续需要考虑 DOM 级读取来区分真实手写内容和 placeholder。

## 本轮追加（2026-06-26：接力最新 main 并构建安装 0.1.43）

- 已按用户要求拉取远端最新代码：本地 `main` 从 `9b0cf7c` 快进到 `b7b19f9`。
- 接力判断：
  - 最新目标是保留安全的 AXValue 直接替换路径，优先恢复 Codex 连续输入的“整篇改写/结构化”。
  - Codex 换行暂不作为当前目标；如果 Codex 仍读不到草稿，下一步应重新评估安全读写方案，不再恢复缓存、全选粘贴或键盘范围替换。
- 已构建私用 release 包：
  - App：`dist/NexVoice.app`
  - DMG：`dist/NexVoice-0.1.43-build44-embedded-keys-20260626.dmg`
  - 包内版本：`0.1.43 (44)`
  - 已确认包内包含本机 `DeepSeek.json` 与 `TencentCloudASR.json` 嵌入配置，未在文档或日志中暴露密钥内容。
- 已安装并启动新版：
  - 安装路径：`/Applications/NexVoice.app`
  - 旧版备份：`dist/install-backups/NexVoice-20260626-102523.app`
  - 当前运行 PID：`42283`
- 验证：
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - `plutil -lint dist/NexVoice.app/Contents/Info.plist` 通过。
  - `hdiutil verify dist/NexVoice-0.1.43-build44-embedded-keys-20260626.dmg` 通过。
  - 已挂载 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，且嵌入配置文件非空。
  - `/Applications/NexVoice.app` 签名、Info.plist、版本号和嵌入配置检查通过。
- 未完成 / 需要用户复测：
  - 尚未做真实右 Alt 语音验收。
  - 重点看连续第二句是否出现 `focusedDraftCharacters>0` 和 `insertionMode=replaceFocusedDraft`；如果仍没有，说明 Codex 当前仍未暴露可安全读取的草稿。

## 本轮追加（2026-06-26：回退到早期整篇改写策略，放弃 Codex 换行专项）

- 用户复测反馈：
  - 当前版本既没有整篇改写结构化，也没有换行；用户可以先不要求换行，但必须恢复“整篇改写”的结构化。
  - 用户要求回看最近几轮 Git 提交，找到合适的撤回点，不再继续堆读草稿缓存/快捷键补丁。
- 提交记录判断：
  - `9b0cf7c feat: add continuous input rewrite` 是整篇连续改写的起点，但当时替换路径使用 `Command+A` + 粘贴，不适合直接整仓回退。
  - `0713b3a Fix continuous rewrite insertion stability` 是更合适的功能基准点：保留整篇连续改写，用 AXValue 直接替换输入框；缺点是 Codex 可能不保留换行。
  - `e8fd9a5` / `89420b5` 开始引入 Codex 多行 Unicode 输入和光标修复；后续 `0fe6d95` / `6b46fa7` 引入缓存和键盘范围替换，风险逐步扩大。
- 本轮修复：
  - 将 Codex 草稿替换策略退回到 `0713b3a` 的 AXValue 直接替换路径，不再使用 `axClearThenUnicodeTyping`。
  - 删除 Unicode 直接输入分块逻辑，代码中不再出现 `virtualKey: 0`。
  - 底部输入框兜底重新允许 AXValue 可写元素作为候选，用于恢复 Codex/Electron 场景下读到当前输入框草稿的机会。
  - 保留后续修复过的输入框/划词隔离，不整仓回退到旧的剪贴板盲复制方案。
- 当前取舍：
  - 优先恢复整篇改写/结构化；Codex 换行暂时不作为目标。
  - 不恢复本地草稿缓存，不恢复全选粘贴，不恢复键盘范围替换。
- 版本递增：`0.1.42 (43)` -> `0.1.43 (44)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`40783`
  - 包内版本：`0.1.43 (44)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - 已检索确认 `axClearThenUnicodeTyping`、`postUnicodeText`、`virtualKey: 0`、`keyboardRangeReplace`、`cachedPreviousInsertion` 均已不存在。
- 需要用户复测确认：
  - 连续第二句是否出现 `focusedDraftCharacters>0` 和 `insertionMode=replaceFocusedDraft`。
  - 如果 Codex 仍不暴露草稿，下一步不再加缓存或快捷键补丁，而应重新评估安全的输入框读写方案。

## 本轮追加（2026-06-26：撤销危险的 Codex 缓存键盘替换）

- 用户复测反馈：
  - 第二句语音时会触发截图快捷键，截图快捷键是 `Command+Alt+A`。
  - 这是高风险问题，因为 NexVoice 不应该在语音输入过程中触发系统或其他 App 的快捷键。
- 根因定位：
  - 上一轮为了让 Codex 在 AX 读不到旧草稿时仍能“第二句回改第一句”，加入了 `keyboardRangeReplace` 兜底。
  - 这条兜底会先模拟带 `Command` 的键盘选择动作，再通过 `virtualKey: 0` 发送 Unicode 文本；macOS 中 `virtualKey: 0` 对应 A 键。
  - 如果系统或用户当前存在 `Option/Alt` 修饰键状态，就可能被组合成 `Command+Alt+A`，从而触发截图。这条方案本身不够安全，不能继续保留。
- 本轮修复：
  - 删除 `keyboardRangeReplace`、`replaceCachedFocusedDraft(...)` 和 `Command+Shift+Up` 选区替换路径。
  - 删除 Codex 短时本地草稿缓存：现在不会再把上一轮写入的 Codex 文本存在 NexVoice 内部，也不会跨 App 带过去。
  - `postUnicodeText(...)` 显式清空事件修饰键，降低 Unicode 直接输入时夹带 `Command/Option` 的风险。
- 当前取舍：
  - 安全优先：先停止所有“靠键盘快捷键选中旧内容再替换”的方案。
  - 代价是：当 Codex 自身 AX 读不到输入框旧草稿时，第二句自动回改第一句的能力会退回到不可用；后续必须找不依赖全选、粘贴、快捷键模拟的安全读写方案。
- 版本递增：`0.1.41 (42)` -> `0.1.42 (43)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`22563`
  - 包内版本：`0.1.42 (43)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - 已检索确认 `keyboardRangeReplace`、`cachedPreviousInsertion`、`replaceCachedFocusedDraft`、`postShiftCommandUp`、`CachedFocusedDraft` 均已不存在。

## 本轮追加（2026-06-26：收紧输入模式与划词模式边界）

- 用户复测反馈：
  - 可编辑输入框内选中文字后语音，仍会误触发“划词问答”。
  - Codex 连续输入时仍未看到分段结构化。
  - 用户明确要求从根本解决，不要继续堆 Codex 专项补丁；因为前几轮修改前曾经可用。
- 日志定位：
  - DeepSeek 没有失效：`DeepSeekRewrite.jsonl` 中最近几次 `final_rewrite` 都是 `succeeded`。
  - 连续结构化未触发的直接原因是 `ContinuousRewrite.jsonl` 显示 `focusedDraftCharacters=0`，也就是录音开始时没有读到 Codex 输入框已有草稿。
  - 误触发问答的直接证据是日志中出现 `operation=selected_text_command`；这来自此前用 `Command+C` 盲复制来判断页面是否有选中文本。
  - AX 调试显示 Codex 当前会把一些普通 `AXGroup` 容器暴露为可写 `AXValue`，继续把“可写 AXValue”当输入框会造成误判。
- 本轮修复：
  - `selectedTextContext(...)` 不再通过 `Command+C` / 剪贴板盲探测选中文本，只读取无障碍树里明确暴露的“非可编辑选区”。
  - `isEditableTextElement(...)` 收紧判断：不再把任意 `AXValue` 可写元素当输入框，避免 Codex 普通容器被误认为输入框。
  - 移除 Codex 文案 `"要求后续变更"` 的逐字硬编码过滤，改为通用过滤：如果读到的文本等于元素自身的 placeholder / title / description / help，就不当作用户草稿。
- 当前取舍：
  - 这轮优先解决严重误触发：输入框内选中文字不应进入问答模式。
  - 如果 Codex 仍然不暴露已有草稿，连续结构化仍可能无法触发；下一步需要单独评估“无全选、无粘贴、无盲复制”的草稿读取/替换方案，不能继续靠专项字符串或复制探测补丁。
- 版本递增：`0.1.36 (37)` -> `0.1.38 (39)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`61674`
  - 包内版本：`0.1.38 (39)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - 修复 `.githooks/pre-commit` 里的陈旧 plist 路径，并重新安装本地 hook；后续提交会调用统一 `scripts/bump_version.sh`。

## 本轮追加（2026-06-26：恢复 Codex 连续整体改写触发）

- 用户复测反馈：
  - 可编辑输入框内选中文字后语音，不再进入划词问答，这一点已确认 OK。
  - 连续结构化仍不触发，并且不是单纯没有分段，而是没有做“已有内容 + 新语音”的整体改写。
- 日志定位：
  - `DeepSeekRewrite.jsonl` 显示最近几次 `final_rewrite` 都是 `succeeded`，说明 DeepSeek 改写服务没有失效。
  - `ContinuousRewrite.jsonl` 中最近几轮 Codex 语音全部是 `focusedDraftCharacters=0`、`insertionMode=insertAtCursor`，说明没有读到输入框已有草稿，所以没有进入整体改写。
  - 对比上一版可触发整体改写的日志，能触发时 `focusedDraftCharacters` 为 `30/96`，`draftReadMethod=axValue`，`insertionMode=replaceFocusedDraft`。
  - 根因：上一轮为了避免普通容器误判输入框，把 `AXValue` 可写元素从“可编辑元素”里整体排除；但 Codex 的草稿读取正依赖 `AXValue`，因此把整体改写入口一并切断了。
- 本轮修复：
  - 将“输入框/划词判断”和“草稿读取/替换判断”分层：
    - 划词问答仍不把普通 `AXValue` 可写容器当输入框，也不恢复剪贴板盲复制。
    - 草稿读取和草稿替换重新允许读取/写入 `AXValue` 可写元素，以恢复 Codex 的 `focusedDraft` 捕获。
  - `nonEditableSelectedTextContext(...)` 会跳过可写草稿元素，避免输入框选中文字重新误触发划词问答。
- 版本递增：`0.1.38 (39)` -> `0.1.39 (40)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`72723`
  - 包内版本：`0.1.39 (40)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。

## 本轮追加（2026-06-26：Codex 草稿读不到时使用短时本地缓存）

- 用户复测反馈：
  - 可编辑输入框内选中文字后语音不会进入划词问答，已确认 OK。
  - 整体改写仍不触发：例如前文说“两个问题”，后文实际补到“三个问题”，NexVoice 没有回头修正前文。
  - 结构化仍不触发；用户同意如果继续卡住，可降低优先级。
- 日志定位：
  - `DeepSeekRewrite.jsonl` 中最近几轮仍然是 `final_rewrite succeeded`，说明不是 Prompt 或 DeepSeek 服务失败。
  - `ContinuousRewrite.jsonl` 在 `0.1.39` 后仍然全部是 `focusedDraftCharacters=0`、`insertionMode=insertAtCursor`。
  - 手动检查 Codex AX 树后确认：当前 Codex 节点虽暴露 `AXValue`、`AXSelectedTextRange`、`AXNumberOfCharacters`，但实际 `AXValue` 为空、`AXNumberOfCharacters=0`，所以 AX 无法读回输入框草稿。
- 本轮修复：
  - 新增短时本地草稿缓存：NexVoice 成功写入 Codex 后，缓存自己刚写入的文本。
  - 下一轮语音开始时，如果 AX 仍读不到 Codex 草稿，就用该缓存作为 `focusedDraft` 触发整体改写。
  - 缓存仅限 `com.openai.codex`，并且只保留 60 秒；可编辑选区替换时会清空缓存，降低用户发送/清空后误合并旧内容的风险。
  - 新增诊断方法名 `cachedPreviousInsertion`，方便复测时确认是否命中缓存。
- 当前取舍：
  - 这是针对 Codex 当前“不暴露草稿”的工程兜底，不依赖文案匹配、全选、粘贴或剪贴板盲探测。
  - 风险是：如果用户在 60 秒内发送上一条消息后马上开始新一条，缓存可能仍保留旧草稿；后续可根据真实复测再缩短 TTL 或增加失效条件。
- 版本递增：`0.1.39 (40)` -> `0.1.40 (41)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`93274`
  - 包内版本：`0.1.40 (41)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。

## 本轮追加（2026-06-26：缓存串场防护与缓存写回失败修复）

- 用户复测反馈：
  - 关心本地草稿缓存离开 Codex 后是否会带到其他场景。
  - 第一次输入后再次语音输入出现“输入失败”。
- 日志定位：
  - `0.1.40` 中缓存已命中：`draftReadMethod=cachedPreviousInsertion`、`focusedDraftCharacters=52`、`insertionMode=replaceFocusedDraft`。
  - DeepSeek 已输出整体改写结果，说明 ASR 和模型链路都不是失败点。
  - 失败点在写回：缓存草稿来自本地，不代表 Codex AX 当前可替换真实输入框；继续走 AX replace 会失败并显示“输入失败”。
- 本轮修复：
  - 进入语音会话时，如果当前前台 App 不是同一个 Codex 进程，立即清空缓存，防止缓存带到其他应用或其他 Codex 进程。
  - 对 `cachedPreviousInsertion` 增加专用写回路径 `keyboardRangeReplace`：不使用剪贴板、不粘贴；通过键盘选中当前输入框从光标到开头的内容，再用 Unicode 文本直接输入完整改写结果。
  - 增加 `insertion_failed` 诊断日志，后续如再出现“输入失败”，会记录错误原因和当时的写回方式。
- 版本递增：`0.1.40 (41)` -> `0.1.41 (42)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`5012`
  - 包内版本：`0.1.41 (42)`
- 验证：
  - `swift test` 通过，145 个测试。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=4 dist/NexVoice.app` 通过。
  - 已做非 ASR 写入机制试验：TextEdit 临时文档第一次直接替换写入成功，但第二次因 TextEdit 前台文档/焦点不稳定，不能作为 Codex 写回的可靠验收；真实验收需看 Codex 复测日志中的 `actualInsertionMethod=keyboardRangeReplace` 和是否还有 `insertion_failed`。

## 本轮追加（2026-06-26：可编辑选区替换与连续草稿读取兜底）

- 用户复测反馈：
  - Codex 换行已经成功。
  - 询问超过 Unicode 分块上限后是否还会复现尾部错字。
  - 在可编辑输入框内选中段落后语音，预期是替换选区，但实际触发了“划词问答”。
  - 最近一次多轮语音看起来没有结构化。
- 日志定位：
  - 最近“一整段未结构化”的几次都是 `insertionMode=insertAtCursor` 且 `focusedDraftCharacters=0`，说明没有读到输入框已有草稿，因此没有进入连续改写合并逻辑。
  - DeepSeek 对单次语音确实做了整理，但它没有拿到前几次草稿，自然无法做全局分段结构化。
  - 光标偏前最近没有稳定复现；这轮先不继续加大光标干预。
- 修复：
  - 可编辑输入框内只要焦点链路包含 editable 元素，就不再进入 `selectedTextContext` 划词问答模式；后续语音按普通输入处理，让系统用当前可编辑选区完成替换。
  - `focusedDraftSnapshotResult(...)` 和 `focusedTextPreview(...)` 增加底部输入框兜底读取：当 AX 焦点没有暴露到输入框时，尝试读取窗口底部的可编辑输入框，改善 Codex 读不到已有草稿导致连续改写不触发的问题。
  - `replaceFocusedDraft(...)` 的目标输入框定位也增加底部输入框兜底，减少焦点偶发漂移时写不到输入框的概率。
  - Unicode 单次输入上限从 512 UTF-16 单元提高到 2048；超过 2048 仍会分块，但普通 Codex 语音草稿基本不会触发，且跨块已有 20ms 间隔。
- 当前说明：
  - “512”不是业务字节数，也不是模型限制；它只是上一版输入事件分块大小。
  - 这次提高到 2048 后，理论上极长文本仍可能跨块，但常规语音输入基本不会再走跨块路径。
- 版本递增：`0.1.35 (36)` -> `0.1.36 (37)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`34909`
  - CDHash 前缀：`7f4aec46e6a14346b88901accfd64ab310d9e139`
  - 签名时间：`2026-06-26 02:27:03`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.36 (37)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：修复 Codex 多行输入乱序与光标偏前）

- 用户复测反馈：
  - 换行已成功保留。
  - 第二次/第三次连续输入后，光标会落在末尾前几个字的位置。
  - 尾部会出现类似“别是否”的莫名其妙文字。
- 日志定位：
  - `DeepSeekRewrite.jsonl` 中模型输出是正确的，例如第三项为“你要看一下语音识别是否有免费的解决方案。”
  - `ContinuousRewrite.jsonl` 显示写入走 `actualInsertionMethod=axClearThenUnicodeTyping`，且 `insertedTextCharacters=73`，但 `readbackMatchesInsertedText=false`。
  - 根因判断：上一版 Unicode 输入按 64 个 UTF-16 单元分块；超过 64 的文本被拆成两段，Codex/Electron 异步处理第二段时可能把后半段插入到错误光标位置，所以看起来像尾部多出几个字。
- 修复：
  - 将 Unicode 输入分块上限从 64 提高到 512，让常见 100-200 字以内的连续改写一次性输入，避免分块乱序。
  - 分块之间的等待从 1ms 提高到 20ms，降低极长文本跨块时的异步错位风险。
  - `axClearThenUnicodeTyping` 路径的光标修复改为输入完成后 80ms / 220ms 再设置到文末，不再刚发完事件就立即抢修光标。
- 版本递增：`0.1.34 (35)` -> `0.1.35 (36)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`14965`
  - CDHash 前缀：`e2043d01b4d9c6d039e87911f3770b6ba0cc0db5`
  - 签名时间：`2026-06-26 02:17:40`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.35 (36)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：Codex 多行连续改写写入修复与语音增强方案）

- 换行问题判断：
  - DeepSeek 已能输出真实换行；问题发生在 Codex/Electron 输入框写入层。
  - 非全选 `AXValue` 写入稳定，但会把 Codex 中的多行文本压成单行。
  - 已拒绝并移除 `Command+A` / 粘贴替换和 AX 全选替换路径，不能再回到这些方案。
- 本轮修复：
  - `FocusedTextInserter.replaceFocusedDraft(...)` 新增 Codex 多行专项路径：仅当目标 App 是 `com.openai.codex` 且待写入文本包含真实换行时触发。
  - 新路径为 `axClearThenUnicodeTyping`：先用 AX 非选择式清空当前输入框，再用 CGEvent Unicode 文本事件输入完整文本。
  - 这条路径不全选、不写剪贴板、不粘贴；缺点是多行长文本会比 AX 一次性写入慢一些。
  - `ContinuousRewrite.jsonl` 的 `actualInsertionMethod` 可观察是否命中 `axClearThenUnicodeTyping`。
- 语音识别增强方案：
  - 第一优先级：保留当前 16k PCM、40ms 实时发送、热词列表；补充可配置 ASR 参数和日志，例如 `noise_threshold`、`filter_modal`、`sentence_strategy`，先小范围试验，不默认强开高阈值。
  - 第二优先级：做本地“麦克风质量面板”和录音诊断，显示输入音量、是否太小、是否削波、环境噪声大不大；这比盲目加降噪更可靠。
  - 第三优先级：如果旁人说话是主要问题，再评估腾讯云说话人分离或本地说话人验证；它们能辅助过滤多人，但复杂度和误伤风险都高，不建议直接进主链路。
  - 不建议优先做强降噪 / AGC：资料和通用 ASR 最佳实践都提示过度前处理可能降低识别准确率，尤其容易误伤小声说话。
- 版本递增：`0.1.33 (34)` -> `0.1.34 (35)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`3256`
  - CDHash 前缀：`9a6bec9732805135fa4ddf037001e14ad7d11563`
  - 签名时间：`2026-06-26 02:11:18`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.34 (35)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：清理冗余并同步远端）

- 用户复测结论：
  - 上一版“第二句语音会全选上一句且不写入”的严重问题已经解决。
  - Codex 连续改写的换行问题仍存在：当前非全选 `AXValue` 写入路径稳定，但在 Codex/Electron 中仍可能把真实换行压扁。
- 清理：
  - 删除已无调用的 `FocusedTextAccessMethod.keyboardDraftSnapshot`。
  - 删除已无调用的 `postPlainKey(...)`。
  - 删除已无调用的 `focusedTextPreview(from:)` 包装函数。
  - 保留临时 `post_insert_readback` 诊断，因为换行问题仍未解决，还需要用它判断写入前后换行是否被压扁。
- 当前取舍：
  - 不恢复 `Command+A`、粘贴替换或 AX 全选替换；稳定输入优先。
  - 换行问题留作下一轮专项：需要找一条非全选、非粘贴、能让 Codex 保留换行的写入方式。
- 版本递增：`0.1.32 (33)` -> `0.1.33 (34)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`39115`
  - CDHash 前缀：`f313dd07fed4cae1fe89c614164cce1524482ad1`
  - 签名时间：`2026-06-26 01:19:31`
- 验证：
  - `rg -n "keyboardDraftSnapshot|postPlainKey\\(|focusedTextPreview\\(from|axSelectedTextReplace|replaceFocusedDraftUsingAXSelectedText|keyboardReplace|postCommandA|Command\\+A" Sources Tests` 无结果。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.33 (34)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：撤回 AX 选区替换，恢复非全选稳定写入）

- 用户明确反馈：
  - 第二句语音时，上一句会被全选，但新内容没有写回输入框。
  - 这比换行结构化更严重，必须先恢复稳定输入；不能再走任何全选或粘贴替换路径。
- 日志定位：
  - `ContinuousRewrite.jsonl` 显示第二句连续改写走了 `actualInsertionMethod=axSelectedTextReplace`。
  - 写入文本有内容，但 `post_insert_readback` 仍读回旧文本，`readbackMatchesInsertedText=false`。
  - 结论：`AXSelectedText` 替换在 Codex 输入框里会制造可见全选，但不能可靠写入，是失败路径。
- 修复：
  - 从 `FocusedTextInserter.replaceFocusedDraft(...)` 中移除 `axSelectedTextReplace` 分支。
  - 删除 `replaceFocusedDraftUsingAXSelectedText(...)` 方法和 `FocusedTextAccessMethod.axSelectedTextReplace` 诊断枚举。
  - 连续改写替换草稿现在只使用非选择式 `AXValue` 写入；写不进去就报“不支持安全替换已有草稿”，不会再尝试全选、粘贴或 AX 选区替换。
  - 临时 `post_insert_readback` 诊断继续保留，用来确认后续是否写入成功、是否仍有换行被压扁。
- 当前取舍：
  - 这次优先解决“第二句不写入、上一句被全选”的稳定性问题。
  - 连续改写里 Codex/Electron `AXValue` 可能仍会压扁换行；这个问题保留为下一步寻找第三条“非全选、非粘贴”的写入路径。
- 版本递增：`0.1.31 (32)` -> `0.1.32 (33)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`27315`
  - CDHash 前缀：`1ba02069a204799315b02673122f93495de84657`
  - 签名时间：`2026-06-26 01:14:16`
- 验证：
  - `rg -n "axSelectedTextReplace|replaceFocusedDraftUsingAXSelectedText|keyboardReplace|postCommandA|Command\\+A" Sources Tests` 无结果。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 已通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.32 (33)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：Codex 连续改写换行丢失修复）

- 用户复测三次语音后反馈：
  - 第一次空输入框发言时，DeepSeek 输出能分段，Codex 里也能看到分段。
  - 第二次、第三次基于已有草稿继续发言后，结构重新整理成了没有换行的版本。
- 新增临时读回诊断已定位根因：
  - 第一次是空输入框 `insertAtCursor`，实际写入方式 `keyboardInsert`；DeepSeek 输出有换行，写后读回仍至少保留 1 个换行，所以 Codex 中可见分段。
  - 第二次、第三次是连续改写 `replaceFocusedDraft`，实际写入方式 `axSetValue`；DeepSeek 输出有真实换行，但写后读回 `readbackNewlineCount=0`，说明 Codex 的 AX 全文写入路径会吞掉换行。
  - 因此这次不是 DeepSeek 结构化失败，而是 Codex/Electron 的 AX `kAXValue` 替换草稿时把换行压扁。
- 修复：
  - `FocusedTextInserter.replaceFocusedDraft(...)` 新增窄范围策略：仅当目标 App 是 `com.openai.codex` 且待写入文本包含换行时，跳过 `AXValue` 全文写入，改走现有 `Command+A` + `Command+V` 键盘替换兜底。
  - 不改变其他 App 的默认 AX 写入策略，避免影响原生输入框和其他应用。
  - 连续改写 Prompt 补充一句：已有分行或编号结构必须继续使用真实换行，每个编号项、问题项或段落单独成行，不要压成同一行。
  - 更新 `VoiceContinuousRewritePolicyTests`，锁定连续改写 Prompt 中的真实换行约束。
- 版本递增：`0.1.29 (30)` -> `0.1.30 (31)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`99676`
  - CDHash 前缀：`a85153555c28be27f69971b6e8aaaea8bb97e2d3`
  - 签名时间：`2026-06-26 00:56:52`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.30 (31)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：
  - 在 Codex 中按同样方式连续说三次，第二次和第三次应不再被压成无换行的一整段。
  - 复测后查看 `ContinuousRewrite.jsonl`：包含换行文本的 Codex 连续改写应出现 `actualInsertionMethod=keyboardReplace`，`post_insert_readback.readbackNewlineCount` 应大于 0。
  - 临时 `post_insert_readback` 诊断仍保留，确认稳定后应删除。

## 本轮追加（2026-06-26：临时结构化写后读回诊断）

- 用户要求先把结构化问题搞清楚，并确认新增诊断应是临时方案。
- 已新增临时诊断，不改变主功能策略：
  - `ContinuousRewriteDiagnosticEvent` 增加写入文本统计字段：`insertedTextCharacters`、`insertedTextNewlineCount`、`insertedTextBlankLineCount`、`insertedTextContainsBlankLine`。
  - 插入成功后延迟 350ms 再读当前输入框，新增 `post_insert_readback` 日志事件，记录 `readbackAvailable`、`readbackMethod`、`readbackCharacters`、`readbackNewlineCount`、`readbackBlankLineCount`、`readbackContainsBlankLine`、`readbackMatchesInsertedText`。
  - `post_insert_readback` 不记录正文 preview，只记录统计值，避免为临时诊断额外扩大日志正文暴露面。
  - 代码注释明确这是临时诊断：确认 Codex / Electron 是否保留段落换行后应删除。
- 下一次用户复测后判断方式：
  - 如果 `insertedTextContainsBlankLine=true` 且 `readbackContainsBlankLine=true`，说明 NexVoice 写入和 Codex 存储都保留空行，截图只是视觉上不明显。
  - 如果 `insertedTextContainsBlankLine=true` 但 `readbackContainsBlankLine=false`，说明 Codex/AX 写入后压扁了空行，需要改写入方式。
  - 如果 `readbackAvailable=false`，说明写后读回拿不到输入框内容，需要继续做 Codex 专项读回验证。
- 版本递增：`0.1.28 (29)` -> `0.1.29 (30)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`81662`
  - CDHash 前缀：`be3c80081c479d3340ae27538046ab944d38463a`
  - 签名时间：`2026-06-26 00:50:55`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.29 (30)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。

## 本轮追加（2026-06-26：结构化日志对比与腾讯云 ASR 参数评估）

- 用户用截图复测“两个问题”的连续改写效果，怀疑结构化没有生效，或在 Codex 输入框中被渲染成一整段。
- 结构化诊断结论：
  - `DeepSeekRewrite.jsonl` 中 2026-06-25T16:21:22Z 对应请求 `BEC24687-0BEB-4244-9576-5808E822FD1C` 是成功请求，非 timeout / fallback。
  - DeepSeek 输出本身包含空行分段：开头一句“再试一次。这次也是两个问题。”，随后分别是“第一个问题...”和“第二个问题...”两段。
  - 截图中看起来像一整块，主要是 Codex 输入框视觉样式不显示明显段间距；同时 `ContinuousRewrite.jsonl` 的 preview 会把换行显示成空格，不能单独作为结构化判断依据。
  - 判断结构化是否真的生效，应以 `DeepSeekRewrite.jsonl` 的 `outputPreview` 为准；`ContinuousRewrite.jsonl` 主要用于判断是否读到草稿、采用插入还是替换、实际写入方式。
- 腾讯云 ASR 当前代码配置：
  - 当前使用普通实时 ASR `16k_zh_en`，PCM、16k、单声道、40ms 分片上传。
  - 已开启 `needvad=1`，`vad_silence_time=800`，`max_speak_time=90000`，`filter_empty_result=1`，临时热词 `hotword_list` 按个人词库传入。
  - 目前没有暴露 `noise_threshold`、`sentence_strategy`、`filter_modal`、`hotword_id`、`customization_id`、`replace_text_id`，也没有本地麦克风增益、降噪、回声消除或声纹过滤。
- 官方参数评估：
  - `noise_threshold` 可作为轻量噪声门限试验项，取值越大越容易判为噪音，但官方提示慎用，可能误伤小声说话。
  - `filter_modal` 过滤语气词，能减少“呃、嗯、啊”，但不能解决旁人说话混入。
  - `sentence_strategy=1` 可让分句更像小段落，对最终文本结构可能有帮助，但不是降噪能力。
  - 普通实时 ASR 没看到“只识别指定声纹”的参数；腾讯云另有“实时说话人分离”接口 `16k_zh_en_speaker`，能返回 speaker_id，但本质是区分多人，不等于天然只收用户本人。
- 推荐后续方案：
  - 低风险一：把 `noise_threshold` 做成可配置实验项，先小范围测试 `0.5 / 1.0`，避免直接强行上线高阈值。
  - 低风险二：把当前 ASR 参数写入日志更完整，增加 `noise_threshold`、`filter_modal`、`sentence_strategy` 字段，方便实测归因。
  - 中风险：新增“说话人分离模式”，接腾讯云 speaker 接口，先观察 speaker_id 是否稳定，再考虑只保留目标 speaker 的文本。
  - 高风险：真正的“只认我的声音”需要本地声纹注册 + 说话人验证 / 前置音频门控，复杂度明显高于普通参数调优，应作为二期能力。

## 本轮追加（2026-06-26：禁止非输入框全选与结构化超时修复）

- 用户反馈三个问题：
  - 严重问题：在非输入框区域按右 Alt 会触发全选，网页选中文字后也会变成整页全选。
  - Codex 专项兜底匹配是否过度复杂。
  - 连续改写看起来没有做全局结构化，只是在一整段里改字句。
- 根因：
  - 为了兼容 Codex 早期 AX 读不到输入框草稿，`focusedDraftSnapshotResult(...)` 在 AX 读不到草稿时用了 `Command+A / Command+C` 作为键盘兜底读取；这个兜底没有严格证明当前焦点是输入框，所以在网页、普通页面、非输入区域会把整页选中。
  - 最近一次结构化失败从 `DeepSeekRewrite.jsonl` 可以确认不是 prompt 没触发，而是连续改写请求在 12 秒超时，随后降级为只插入本轮 ASR fallback，因此表现成“没有全局结构化”。
- 修复：
  - 完全移除录音开始阶段的 `Command+A / Command+C` 草稿读取兜底；现在读取已有草稿只走 AX 直接读取路径，读不到就当作空草稿。
  - 保留写入阶段的 `Command+A / Command+V` 兜底，因为它只会在已确认要替换输入框草稿时执行，不会在录音开始时误全选网页。
  - 连续改写长草稿 / 碎片化语音 timeout 放宽：碎片化或 260 字以上给到 `16s`，160 字以上给到 `14s`，降低长草稿结构化超时概率。
  - 连续改写 prompt 增加明确要求：多个问题、要求、原因、方案或待办要用空行分段，不要压成一个长段。
  - 同步更新 `VoiceRewriteContextTests` 的 timeout 期望。
- 关于 Codex 专项兜底的当前判断：
  - 通用方案仍是 AX placeholder/title/description 过滤；Codex 固定文案过滤只是兜底。
  - 但用户提出“是否过度复杂”是合理的，后续如果 AX label 过滤稳定，可以考虑移除固定文案兜底，避免产品逻辑被某个引导语绑定。
- 版本递增：`0.1.27 (28)` -> `0.1.28 (29)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`12117`
  - CDHash 前缀：`193b2d9f6e601e0f21713c02083961e8718d817d`
  - 签名时间：`2026-06-26 00:03`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.28 (29)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：
  - 在网页、非输入框区域、普通选中文本区域按右 Alt，不应再触发整页全选。
  - Codex 连续改写长草稿应更少超时；如果仍超时，日志 `DeepSeekRewrite.jsonl` 会显示 `failed / The request timed out`。
  - 多问题连续改写应输出空行分隔的段落结构，而不是只在一段里写“第几个问题”。

## 本轮追加（2026-06-25：placeholder 过滤解释与短延迟光标补位）

- 用户追问三点：placeholder 是否只靠固定文案匹配、连续改写读写策略是否只针对 Codex、以及第二次连续改写后光标仍可能回到开头。
- 当前逻辑澄清：
  - 连续改写主体是通用能力，优先用 macOS Accessibility 读取/写入输入框；无法直接读写时才回退剪贴板和键盘事件。
  - App 专项逻辑按 bundle ID 隔离；Codex 专项 placeholder 过滤只作用于 `com.openai.codex`，不会影响微信、飞书、浏览器等其他 App。
  - 精确文案过滤只是 Codex 的兜底，不是首选方案。
- 修复：
  - placeholder 过滤继续优先使用通用 AX 属性：`AXPlaceholderValue`。
  - Codex 场景新增 label 过滤：如果读到的文本等于 AX 元素的 `AXDescription` / `AXTitle` / `AXHelp`，也视为非用户草稿，减少对“要求后续变更”固定文案的依赖。
  - 仍保留 `要求后续变更` 精确过滤作为最后兜底，用于 Codex 没有把 placeholder 正确暴露成 AX placeholder/title/description 的情况。
  - 光标补位从“只设置一次”改为“立即设置 + 30ms 后短补一次”；不再使用 50ms/160ms 长延迟，也不再发送 `Command+Down`，降低用户手动移动光标后被拉回的风险。
- 版本递增：`0.1.26 (27)` -> `0.1.27 (28)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`83353`
  - CDHash 前缀：`93e1f60937c9f6f17469c130c88d9bc907178168`
  - 签名时间：`2026-06-25 23:46`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.27 (28)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：
  - Codex 空输入框不应把 placeholder 纳入正文。
  - 连续改写第二次、第三次后光标应尽量留在文末；用户在完成后手动移动光标，不应再被长延迟拉回。
  - 如果 Codex 后续换引导语，优先观察日志中是否仍 `focusedDraftCharacters=0`；如果失败，说明 Codex 没把新引导语暴露在 AX label/placeholder，需要继续补 Codex 专项兜底。

## 本轮追加（2026-06-25：光标回拉弱化与 Codex placeholder 过滤）

- 用户在 Codex 测试反馈两个问题：
  - 上一版为了修复光标回到开头，延迟多次把光标拉到末尾，导致用户手动把光标挪到前面后仍被强行拉回末尾。
  - Codex 空输入框里的灰色提示文案“要求后续变更”被读成真实草稿，导致空输入框也进入连续改写。
- 修复：
  - 移除 `50ms / 160ms` 延迟重复拉光标和 `Command+Down` 兜底；AX 直接写入后只做一次默认文末光标设置，不再持续干预用户后续手动移动光标。
  - 草稿读取新增 placeholder 过滤：如果 AX 元素提供 `AXPlaceholderValue` 且读到的文本与 placeholder 一致，视为空草稿。
  - 针对 Codex bundle `com.openai.codex` 增加已知非草稿 placeholder 过滤：读到纯 `要求后续变更` 时视为空输入框；该过滤同时作用于连续改写草稿读取和 `VoiceRewriteContext.focusedTextPreview`。
  - 键盘兜底 `Command+A / Command+C` 读到纯 Codex placeholder 时也会丢弃，避免 placeholder 从兜底路径进入 prompt。
- 版本递增：`0.1.25 (26)` -> `0.1.26 (27)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`71819`
  - CDHash 前缀：`4361e5f1390ef9574052268dffaa77eae699f34d`
  - 签名时间：`2026-06-25 23:40`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.26 (27)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：
  - Codex 空输入框只显示灰色“要求后续变更”时，说话后应按空草稿处理，不应把这句 placeholder 纳入输出。
  - 连续改写完成后默认光标尽量在文末；如果用户随后手动移动光标，App 不应再把光标强行拉回末尾。

## 本轮追加（2026-06-25：连续改写后光标位置修复）

- 用户在 Codex 输入框测试确认连续改写已能无感合成整理，但每次写入后光标会回到文本开头，而不是停在文末。
- 修复：`FocusedTextInserter.replaceFocusedDraft(...)` 的 AX 直接写入路径现在会在写入后修复光标位置：
  - 写入前先激活目标 App，确保后续光标修复作用在同一个输入框。
  - `AXUIElementSetAttributeValue(kAXValueAttribute, ...)` 写入成功后，立即把 `AXSelectedTextRange` 设置到文末。
  - 针对 Electron / WebView 可能异步把 selection 重置到开头的问题，延迟 `50ms` 和 `160ms` 再次把光标设置到文末。
  - 如果目标输入框不支持 AX selection 设置，则轻量兜底发送一次 `Command+Down`，把光标移到文本末尾；不再重新全选或重贴文本。
- 版本递增：`0.1.24 (25)` -> `0.1.25 (26)`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`52074`
  - CDHash 前缀：`7f73a63c1c88503f7dcde6eef5b15c5c5b512431`
  - 签名时间：`2026-06-25 23:27`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.25 (26)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：继续在 Codex 输入框连续说 2-3 次，确认改写后光标停在文本末尾，可以直接接着输入或继续语音追加。

## 本轮追加（2026-06-25：连续改写无感读写优先与版本修正）

- 版本号已补齐：`0.1.23 (24)` -> `0.1.24 (25)`，避免连续改写新功能仍沿用旧版本号。
- 连续改写读写路径改为分层策略：
  - 读取输入框草稿时优先用 AX 直接读取 `AXValue`，读不到时尝试 `AXStringForRange`，最后才回退到 `Command+A / Command+C` 键盘兜底。
  - 替换输入框草稿时优先用 `AXUIElementSetAttributeValue(kAXValueAttribute, ...)` 直接写入，并尽量把光标放到文末；不支持直接写入时才回退到旧的 `Command+A / Command+V`。
  - 普通空输入框插入仍走原来的剪贴板粘贴，不改变旧路径。
- `ContinuousRewrite.jsonl` 诊断增强：
  - `decision` 事件新增 `draftReadMethod`，可看到草稿来自 `axValue`、`axStringForRange` 还是 `keyboardDraftSnapshot`。
  - `inserted` 事件新增 `actualInsertionMethod`，可看到最终是 `axSetValue`、`keyboardReplace` 还是 `keyboardInsert`。
- 当前测试版已构建并启动：
  - 运行路径：`/Users/nefish/Desktop/Coding/NexVoice/dist/NexVoice.app`
  - 运行 PID：`43323`
  - Bundle ID：`com.nexvoice.mac`
  - CDHash 前缀：`2d061969d50d7a2f2add43f5941acaaadf83a63f`
  - 签名时间：`2026-06-25 23:22`
- 验证：
  - `swift build --disable-sandbox -c debug --product NexVoiceApp` 通过。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `git diff --check` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过。
  - 已确认包内版本为 `0.1.24 (25)`，`NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 存在。
- 下一轮复测重点：
  - 在 Codex、微信、飞书里用同一输入框连续说 2-3 次，观察是否合并成一版完整新草稿。
  - 测试后查看 `~/Library/Application Support/NexVoice/Logs/ContinuousRewrite.jsonl`：原生输入框理想结果应尽量出现 `draftReadMethod=axValue` 和 `actualInsertionMethod=axSetValue`；Electron / WebView 如果仍显示键盘兜底，说明对应 App 的 AX 能力不足，需要再专项做 Electron / 浏览器适配。

## 本轮追加（2026-06-25：输入框短草稿连续改写可行性）

- 根据用户确认，先把普通语音输入升级为“基于当前输入框内容连续改写”的第一版可行性实现，而不是新增一个独立模式。
- 新增 `Sources/NexVoiceCore/VoiceContinuousRewritePolicy.swift`：
  - 输入框为空时维持旧逻辑，只整理本轮语音并在光标处粘贴。
  - 输入框有短草稿且没有输入框选区时，生成“连续改写输入”源文本，要求 DeepSeek 把已有草稿和本轮新增语音合并成完整新草稿。
  - 输入框内已有选区时先不全文替换，避免用户只想改选中片段时误伤整段。
  - 草稿超过 `2000` 字符时先不全文替换，为后续长文本/网页编辑器按自然段或局部范围改写留出兼容空间。
- `VoiceRewritePromptPolicy` 增加连续改写专用 Prompt 规则：明确输出一版完整新草稿，不要只改写本轮新增语音，也不要简单追加。
- `FocusedTextInserter` 增加 `replaceFocusedDraft(...)`：确认当前焦点仍是可编辑输入框后，用 `Command+A` + 粘贴替换当前输入框草稿；如果不满足连续改写策略则仍使用原来的粘贴路径。
- `AppDelegate` 在录音开始时记录输入框草稿快照和输入框选区状态；最终整理时按策略决定是替换草稿还是旧式插入。AI 改写失败时会降级为只插入本轮 ASR 清理结果，不覆盖已有草稿。
- 用户复测后日志确认：运行的确实是 `dist/NexVoice.app`，但 DeepSeek prompt 里没有 `连续改写输入`，说明当前 App 未读到 Codex 输入框已有草稿，而不是用户跑错版本。
- 根因：Codex 输入框无法通过常规 AXValue 读取全文，`focusedTextPreview` 为空，连续改写策略自动降级为只整理本轮语音。
- 修复：`FocusedTextInserter.focusedDraftSnapshot(...)` 增加兜底读取，AX 读不到时在录音开始阶段临时 `Command+A` / `Command+C` 复制当前输入框全文，恢复剪贴板后收起选区；该兜底只在没有输入框内选区时启用，避免破坏“只改选中片段”的场景。
- 用户再次复测后仍未触发连续改写，日志显示 DeepSeek 仍只收到本轮语音；进一步确认阻断点是兜底读取前仍要求 `focusedEditableElement != nil`，而 Codex 输入框很可能无法被识别为 AX 可编辑元素。
- 二次修复：`focusedDraftSnapshot(...)` 不再依赖 `focusedEditableElement`，只要目标 App 存在且辅助功能权限可用，就尝试键盘兜底读取；`replaceFocusedDraft(...)` 也不再因为 AX 元素识别失败而退回普通插入。
- 新增 `Sources/NexVoiceHost/ContinuousRewriteDiagnosticsLogger.swift`，每次 final 后记录连续改写决策到 `~/Library/Application Support/NexVoice/Logs/ContinuousRewrite.jsonl`，包含是否有输入框选区、是否读到草稿、草稿长度、新语音长度和最终插入策略。
- 已重启当前测试版：`/Users/nefish/Desktop/WorkSpace/Coding/NexVoice/dist/NexVoice.app`，最新运行 PID 曾确认为 `67508`；上一轮 dist 进程 `51799` 已退出；新构建签名时间为 `2026-06-25 22:19`，CDHash 前缀 `8e649c`。
- 已构建但未替换安装版：`dist/NexVoice.app`，包含本机 DeepSeek / 腾讯云 ASR 嵌入配置。
- 验证：
  - 新增 `VoiceContinuousRewritePolicyTests`，覆盖短草稿连续改写、空输入框降级、输入框选区降级、超长草稿降级、Prompt 完整草稿约束。
  - `swift test --disable-sandbox --filter VoiceContinuousRewrite --quiet` 通过，5 个测试。
  - `swift test --disable-sandbox --quiet` 通过，145 个测试。
  - `swift build --disable-sandbox -c release --product NexVoiceApp` 通过。
  - `./scripts/build_app.sh release --embed-local-keys` 通过。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app` 通过；确认 `DeepSeek.json` 和 `TencentCloudASR.json` 已嵌入。
- 未完成 / 下一步：
  - 尚未做真实 App 内语音验收，需要安装/启动新版后，在微信、飞书、Codex 输入框里分 2-3 次语音补充同一段内容，确认会替换为完整结构化草稿。
  - 长文本和网页编辑器暂不全文替换；后续建议新增“自然段 / 光标附近段落 / 可编辑区域类型”规则，再接入 Notion、飞书文档、网页富文本编辑器等场景。
  - 用户复测确认连续改写可用，但当前键盘兜底会出现可感知的全选闪烁，体验不够无感。
  - 已做方向调研：Apple 官方 AX 路线可用 `AXUIElementSetAttributeValue` / `AXSelectedTextRange` / `AXStringForRange` 等能力尝试无感读写；但 Electron / WebView / 终端 / 自定义编辑器经常暴露不完整，开源工具和自动化工具常见仍会回退到剪贴板 + 模拟按键。
  - 后续规划采用“输入框读写引擎分层”，不要继续只修补 `Command+A/C/V`：
    1. `AXDirectTextAdapter`：优先尝试 AXValue / selected range / string-for-range，无感读取和替换输入框内容。
    2. `ElectronAccessibilityAdapter`：针对 Electron/Codex，尝试设置 `AXManualAccessibility` 后重新读取 AX tree，减少键盘兜底依赖。
    3. `BrowserDOMTextAdapter`：针对 Chrome / Safari / Edge 的网页编辑器，后续通过 Apple Events / JXA 读取 `document.activeElement`、selection、contenteditable；需要用户开启浏览器 Apple Events 权限。
    4. `KeyboardFallbackAdapter`：保留当前 `Command+A/C/V` 方案作为最后兜底，并尽量缩短选区停留时间、恢复剪贴板和光标。
  - 下一轮优先实现 `AXDirectTextAdapter + 读写路径诊断日志`，目标是能无感处理原生输入框；如果 Codex 仍不支持，再专项攻 Electron/Codex。

## 本轮完成（2026-06-25：看屏回复 OCR 诊断与长语音截断排查）

- 新增 `Sources/NexVoiceHost/ScreenReplyDiagnosticsLogger.swift`，看屏回复会写入本地日志：`~/Library/Application Support/NexVoice/Logs/ScreenReply.jsonl`。
- `ScreenReply.jsonl` 记录每次看屏回复的 `captureID`、前台应用、窗口标题、OCR 原文、结构化 `我 / 对方 / 未知` 消息、每一行 OCR 的坐标和置信度、语音指令、最终回复或错误信息；用于定位“究竟读到了什么”和为什么复读上文。
- 看屏回复逻辑未加“相似度硬拦截”或“不输出提示”，保留用户要求的两个状态：有语音指令时结合指令回复；无语音指令时直接根据可见内容回复。
- 长语音截断排查：最新日志中用户 42 秒语音只返回了前半段，代码里腾讯云 `max_speak_time` 之前写死为 `10000ms`。腾讯云该参数是连续说话强制断句配置，当前已调到 `90000ms`，降低长语音被过早切段后丢尾部的概率。
- `TencentCloudASR.jsonl` 增加逐分片诊断：每个识别分片会记录 `sliceType`、`resultIndex`、起止时间、分片文本、当前拼接文本、`maxSpeakTime`、`vadSilenceTime` 等字段；下次复现可以判断是腾讯云没返回尾段，还是本地拼接逻辑丢段。
- 版本递增：`0.1.11 (12)` -> `0.1.12 (13)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-005151.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`CLANG_MODULE_CACHE_PATH=.build/module-cache swift build --disable-sandbox --product NexVoiceApp` 通过；`./scripts/build_app.sh release --embed-local-keys` 通过；安装包签名、版本和资源检查通过。

## 本轮追加（2026-06-25：看屏回复重复输出定位与过滤）

- 用户连续复现 3 次企业微信看屏回复：
  - 第一次输出完全复读了屏幕里已有的上一条回复：“那外包团队视觉水平确实不太行...”
  - 后两次都输出同一句：“你感觉咋样？好用吗？”，而这句话也已经在 OCR 中出现并被标成“我”。
- 日志结论：`ScreenReply.jsonl` 证明 OCR 把企业微信左侧导航、会话列表、时间标签、多个历史消息和当前聊天混在一起；传给模型的上下文不够聚焦，模型把可见的“我方旧消息”当成可输出回复。
- 修复：
  - 企业微信 / 微信场景生成回复时，只使用主聊天区 OCR 行，过滤左侧导航、会话列表、时间标签、明显 UI 文案和链接；完整 OCR 行仍保留在日志。
  - `ScreenReplyCapturedLine` 增加 `includedInReplyContext`，下一次可以直接看每行 OCR 是否真正参与生成。
  - 调整左右角色判断：右侧或横跨到右侧的气泡更稳定标为“我”，左侧主聊天气泡标为“对方”。
  - Prompt 增加非硬拦截规则：`我：` 内容是用户已说过/输入过/刚生成过的旧消息，不能作为本次输出；连续触发相同上下文时也要生成一条新的可发送回复。
- 版本递增：`0.1.12 (13)` -> `0.1.13 (14)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-005942.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；调试构建通过；`./scripts/build_app.sh release --embed-local-keys` 通过；安装包签名、版本和资源检查通过。

## 本轮追加（2026-06-25：看屏回复输入框锚点区域）

- 根据用户确认的规则，把看屏回复生成上下文改成“以当前输入框为基准，左右扩展一点，向上取同一列内容”。
- 新增 `FocusedTextInserter.focusedInputFrame(in:)`，通过辅助功能读取当前可编辑输入框的屏幕位置和大小。
- `ScreenReplyContextCaptureService` 会把输入框屏幕坐标换算到窗口截图坐标，计算 `replyRegion`：
  - 横向：输入框左右各扩展约 12%，限制在 80-160px，并保证最小宽度约 620px。
  - 纵向：从窗口顶部到输入框上方，避开输入框当前草稿内容。
  - 能拿到输入框时优先用该区域过滤 OCR；拿不到输入框时回退到之前的聊天 App 过滤策略。
- `ScreenReply.jsonl` 增加 `inputFrame` 和 `replyRegion` 字段，`includedInReplyContext` 继续标记每行 OCR 是否真的参与生成，便于下一轮确认截取范围是否准确。
- 版本递增：`0.1.13 (14)` -> `0.1.14 (15)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-011247.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；调试构建通过；`./scripts/build_app.sh release --embed-local-keys` 通过；安装包签名、版本和资源检查通过。

## 本轮追加（2026-06-25：看屏回复区域左侧安全线）

- 用户复测 `0.1.14` 后，日志显示输入框锚点已生效，但 `replyRegion.x` 仍从 `x=225/231` 开始，企业微信左侧会话列表仍进入生成上下文，导致“好的，收到。”和复述上文。
- 调整 `replyRegion` 策略：
  - 聊天 App 下左侧只少量扩展输入框，约 4%，限制 20-48px。
  - 聊天 App 下右侧多扩展，约 18%，限制 120-240px。
  - 聊天 App 下增加左侧安全线：`replyRegion.x >= imageWidth * 0.34`，避免切入企业微信/微信左侧会话列表。
  - 非聊天 App 仍使用通用左右扩展策略。
- 版本递增：`0.1.14 (15)` -> `0.1.15 (16)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-012309.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；调试构建通过；`./scripts/build_app.sh release --embed-local-keys` 通过；安装包签名、版本和资源检查通过。

## 本轮追加（2026-06-25：修正输入框坐标单位）

- 用户指出企业微信里输入框和上方消息视觉上基本纵向对齐，怀疑不是输入框本身错位。
- 复查日志后确认：`inputFrame.x=311` 看似偏左，但这是系统辅助功能返回的屏幕点坐标；OCR 行坐标来自窗口截图像素坐标。在 Retina 屏上两者通常差约 2 倍，之前代码直接混用，导致 `replyRegion` 被整体算偏左，企业微信左侧会话列表被误纳入生成上下文。
- 修复：`ScreenReplyContextCaptureService.inputFrameInWindow(...)` 现在会根据窗口点尺寸和截图像素尺寸计算 `scaleX / scaleY`，把输入框坐标转换成截图像素坐标后再计算 `replyRegion`。
- 版本递增：`0.1.15 (16)` -> `0.1.16 (17)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-013305.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本、资源检查通过；新版进程已启动。
- 下一轮复测重点：用户在企业微信复测后，新的 `ScreenReply.jsonl` 中 `inputFrame.x` 应接近原来的 2 倍，`replyRegion.x` 应明显避开左侧会话列表。

## 本轮追加（2026-06-25：聊天输入框宽度自适应）

- 用户确认企业微信不希望再做横向扩展，期望所有窗口宽度下都按当前输入框宽度向上取同一列聊天内容。
- 修复：
  - 聊天 App（企业微信 / 微信）一旦拿到输入框区域，`replyRegion` 不再左右扩展，左右边界直接使用输入框左右边界，避免企业微信右侧群公告 / 群成员栏混入上下文。
  - `FocusedTextInserter.focusedInputFrame(in:)` 增加应用无障碍树扫描兜底：如果当前聚焦元素不是输入框，会扫描当前应用窗口里的底部可编辑文本元素，优先选择最靠近窗口底部、宽度更大的候选输入框。
  - 微信拿不到 AX 输入框时，`ScreenReplyContextCaptureService` 会用 OCR 识别到的底部输入占位文案（如“输入文字，或按住Fn使用语音输入”）推算聊天列，作为最后兜底；该推算基于截图宽度比例和占位文案位置，不依赖固定窗口大小。
- 版本递增：`0.1.16 (17)` -> `0.1.17 (18)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-014237.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本、资源检查通过；新版进程已启动。
- 下一轮复测重点：在企业微信和微信分别用全屏、小窗口、窄窗口复测；日志中企业微信 `replyRegion.x / width` 应贴合输入框，不再包含右侧栏；微信应尽量出现 `inputFrame` / `replyRegion`，且不混入左侧群聊列表。

## 本轮追加（2026-06-25：微信左侧群聊列表二次过滤）

- 用户在企业微信和微信复测 `0.1.17 (18)`：
  - 企业微信效果明显改善，`replyRegion=(x:622,w:896)`，右侧群公告 / 群成员栏基本不再进入生成上下文。
  - 微信已经能拿到 `inputFrame/replyRegion`，但 `inputFrame.x=401,w=1062` 实际是底部大容器，不是真正输入文字区域；左侧群聊列表部分长标题和时间戳仍进入上下文。
- 修复：
  - `shouldIncludeInReplyContext` 在存在 `replyRegion` 时不再只判断矩形相交，还要求 OCR 行的起点进入回复列，避免左侧列表长标题“擦边”进入。
  - 微信场景下，如果 OCR 识别到底部输入占位文案（如“输入文字，或按住Fn使用语音输入”），会用该占位文案修正 `inputFrame` 左边界；右边界仍保留 AX 输入容器右边界，确保全屏、小窗口、窄窗口都跟随当前窗口布局。
- 版本递增：`0.1.17 (18)` -> `0.1.18 (19)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-022306.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本、资源检查通过；新版进程已启动。
- 下一轮复测重点：微信日志中的 `replyRegion.x` 应从约 `401` 收窄到约 `620+`，左侧群聊列表的标题和时间戳不应再 `includedInReplyContext=true`。

## 本轮追加（2026-06-25：Chrome/Twitter 与飞书上下文裁剪）

- 用户在微信、Twitter/Chrome、飞书复测 `0.1.18 (19)`：
  - 微信已基本正确，`replyRegion.x` 收窄到约 `614/619`，左侧群聊列表不再进入上下文。
  - Twitter/Chrome 能拿到输入框和帖子正文，但通用规则仍向右扩展，导致右侧栏如 Premium、搜索、趋势、推广内容混入上下文。
  - 飞书仍然 `input=null / region=null`，退回全窗口 OCR，左侧导航、会话列表、当前聊天、右侧话题栏全部混在一起，属于不稳定结果。
- 修复：
  - 新增“回复列应用”判断：微信 / 企业微信 / 飞书 / 浏览器类应用拿到输入框后走列裁剪，不再使用通用左右扩展。
  - Chrome / Edge / Safari 场景保留输入框左侧少量余量，右侧不扩展，用于 Twitter/X 这类三栏页面，避免右栏混入。
  - 飞书场景新增 OCR 底部输入锚点推断：识别 `发送给...`、`Aa`、`新建话题`、`回复话题` 等底部输入区文案后，推断当前聊天列起点，并排除左侧导航/会话列表。
- 版本递增：`0.1.18 (19)` -> `0.1.19 (20)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-023350.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本、资源检查通过；新版进程已启动。
- 下一轮复测重点：Twitter/Chrome 日志中右侧栏不应再进入 `includedInReplyContext=true`；飞书应出现 `inputFrame/replyRegion`，且 `replyRegion.x` 应避开左侧导航和会话列表。

## 本轮追加（2026-06-25：飞书话题侧栏细分）

- 用户追问飞书是否能判定主聊天列和右侧话题列，以及这些分场景策略是否会污染未测试场景。
- 结论：
  - 飞书可以通过底部 OCR 锚点区分：普通聊天输入区常见 `发送给...`；话题侧栏同时出现左侧 `+ 新建话题` 和右侧 `回复话题 / Aa`。
  - 现有策略按 bundle ID 分支：飞书只作用于 `com.electron.lark`，微信/企业微信只作用于对应腾讯 bundle，浏览器列裁剪只作用于 Chrome / Edge / Safari；原生 Codex App `com.openai.codex` 不会走这些分支。
- 修复：
  - 飞书 OCR 底部锚点推断改为：如果同屏存在 `+ 新建话题` 且右侧存在 `回复话题 / Aa`，优先取右侧话题回复列；如果存在 `发送给...`，优先取普通聊天输入列。
  - 增加少量明显 UI 文案过滤：`Q 搜索`、`草稿`、`回复话题`、`新建话题`、`快捷指令`、`最佳实践`。
- 版本递增：`0.1.19 (20)` -> `0.1.20 (21)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-024051.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本检查通过；新版进程已启动。
- 下一轮复测重点：飞书右侧话题栏场景的 `replyRegion.x` 应进一步右移到话题回复列附近；普通飞书聊天仍应使用 `发送给...` 所在列；Chrome/Twitter 仅保留帖子主体，减少搜索/草稿等 UI 文案。

## 本轮追加（2026-06-25：飞书右侧话题栏宽度阈值）

- 用户复测 `0.1.20 (21)`：
  - 飞书普通聊天正确，继续使用 `发送给 Nefish的智能伙伴` 所在列，未混入左侧会话列表。
  - 飞书右侧话题栏仍出现一次 `input=null / region=null`。日志里实际已经 OCR 到右侧底部 `回复话题 / Aa` 和左侧 `+ 新建话题`，但右侧话题栏宽度小于整窗 35%，被上一版可信宽度阈值丢弃。
- 修复：飞书右侧话题栏专用阈值从整窗 35% 降到 18%；普通飞书聊天仍保留 35% 阈值，避免误判左侧小控件。
- 版本递增：`0.1.20 (21)` -> `0.1.21 (22)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-024643.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本检查通过；新版进程已启动。
- 下一轮复测重点：飞书右侧话题栏应出现 `inputFrame/replyRegion`，`replyRegion.x` 应靠近右侧 `回复话题 / Aa` 输入区。

## 本轮追加（2026-06-25：飞书/Twitter 上下文杂音过滤）

- 用户复测 `0.1.21 (22)` 后查看日志：
  - 飞书右侧话题栏已能识别到输入列，`replyRegion.x` 从此前约 `754` 收窄并右移到约 `1397/1400`，宽度约 `680`，说明右侧话题栏锚点生效。
  - 飞书上下文主体正确，但仍混入右侧话题栏顶部按钮（如文件/话题/关闭）和头像/姓名 OCR 碎片（如重复的 `Nefish 1943`）。
  - Twitter/Chrome 主帖子正文能拿到，但仍混入少量右侧栏固定文案（如搜索、草稿、什么新鲜事）。
- 修复：
  - 看屏回复生成前新增行级杂音过滤，继续保留完整 OCR 日志，只减少真正参与生成的行。
  - 飞书右侧话题栏过滤顶部工具按钮、关闭按钮和大号头像/姓名数字块，降低重复人名/旧上下文误导模型的概率。
  - 浏览器/Twitter 过滤搜索、草稿、什么新鲜事、正在关注、帖子、显示更多、订阅、推广回复等固定 UI 文案。
- 版本递增：`0.1.21 (22)` -> `0.1.22 (23)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-025202.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本检查通过；新版进程已启动，PID 为 `29583`。
- 下一轮复测重点：飞书右侧话题栏日志中顶部按钮和重复头像名不应再 `includedInReplyContext=true`；Twitter/Chrome 日志中搜索、草稿、什么新鲜事等右侧栏固定文案不应再参与生成。

## 本轮追加（2026-06-25：最终日志复查与推送前收口）

- 用户复测 `0.1.22 (23)` 后复查最新日志：
  - 飞书右侧话题栏定位保持正确，`replyRegion.x` 仍在约 `1397/1400`，能稳定取右侧话题回复列。
  - 第一条飞书右侧话题栏日志已很干净，只剩“老周不太周...”这条话题原文和用户问题，生成回复没有复读上方历史消息。
  - 第二条飞书日志仍残留少量顶部 OCR 误识别（如 `呵。`、`已云文档`、`因`），但主体正文和回复意图正确。
  - Twitter/Chrome 已不再混入搜索、草稿、什么新鲜事等右栏固定文案，但顶部兴趣标签 `Design Engineers / AI Leaders / AI Founders` 仍会进入上下文。
- 修复：
  - 飞书顶部工具区过滤新增 `呵。`、`已云文档`、单字 `因` 等 OCR 误识别。
  - 浏览器/Twitter 过滤顶部兴趣标签 `Design Engineers`、`AI/Al Leaders`、`AI/Al Founders #1 of 3`。
  - 保持输入框定位和列裁剪逻辑不变，只收窄真正参与生成的 OCR 行，降低对其他场景的影响。
- 版本递增：`0.1.22 (23)` -> `0.1.23 (24)`。
- 已构建并安装新版：`/Applications/NexVoice.app`；旧版备份：`dist/install-backups/NexVoice-20260625-025753.app`。
- 验证：`git diff --check` 通过；`swift test --disable-sandbox --quiet` 通过，140 个测试；`./scripts/build_app.sh release --embed-local-keys` 通过；`dist/NexVoice.app` 和 `/Applications/NexVoice.app` 签名、版本检查通过；新版进程已启动，PID 为 `41101`。
- 下一轮复测重点：飞书右侧话题栏顶部 OCR 误识别和 Twitter 顶部兴趣标签不应再进入 `includedInReplyContext=true`。

## 本轮完成（2026-06-24：设置窗口 Web 化迁移）

- 采用新的设置窗口路线：视觉层改为 `SettingsWeb`（React + Vite 静态页），宿主 App 通过 `WKWebView` 加载本地资源；Swift 只负责真实数据、系统权限、快捷键、词库写入和菜单入口。
- 新增 `Sources/NexVoiceHost/VoiceWebSettingsWindowController.swift`，并把菜单 `设置...` / `个人词库...` 入口切到新的 Web 设置窗口；旧 Swift 设置窗口、旧快捷键窗口、旧个人词库窗口已删除，避免两套设置实现并存。
- `SettingsWeb` 已包含 5 个真实设置页：
  - `输入设置`：快捷键显示、录制、恢复、输出语言切换。
  - `输出模式`：四种输出模式卡片，点击后写回真实 `VoiceRewriteStyle`。
  - `工作流`：展示当前应用、识别场景、工作流规则；输出模式下拉目前会切换真实全局输出模式。
  - `个人词库`：读取真实个人词库，按全部 / 自动学习 / 手动添加筛选；支持添加、删除真实词条。
  - `权限`：展示麦克风、辅助功能、屏幕录制权限；未授权时可打开系统设置。
- 已补齐 Web 交互：
  - 左侧 Tab、按钮、分段控件、输出模式卡片、词库条目、弹窗、权限按钮都有 hover / active 反馈。
  - 品牌蓝统一升级为 `#126DFF`，用于版本号、输出模式指标条等关键状态点缀。
  - 输出模式选中态不再使用蓝色背景，只保留浅描边；选中卡片内的指标条使用品牌蓝并带展开动画。
  - 工作流页的输出模式选择器已从系统原生下拉框改为自定义菜单，视觉与设置页其他控件一致。
  - 快捷键录制期间按 `ESC` 会取消录制，不会保存为快捷键。
  - 词库 Tab 与 `添加词条` 按钮保持同一行；添加词条后弹窗会立即关闭并切到手动添加列表。
  - 词库添加弹窗支持 `Enter` 添加、`Esc` 取消，输入框占位文字垂直居中。
- 窗口外观：
  - 设置窗口启用透明标题栏和 full-size content view，隐藏顶部标题条，Web 页面整体上移，不再留下旧标题栏造成的大块顶部空白。
- 打包流程更新：
  - `scripts/build_app.sh` 会先构建 `SettingsWeb`，再把 `SettingsWeb/dist` 复制到 `NexVoice.app/Contents/Resources/SettingsWeb`。
  - `.gitignore` 已忽略 `SettingsWeb/node_modules/` 和 `SettingsWeb/dist/`。
- 空白页补充修复：
  - 用户实测发现新版设置窗口打开后为空白，AppShot 显示已加载 `NexVoice.app/Contents/Resources/SettingsWeb/index.html`，但页面没有渲染。
  - 根因定位：Vite 默认产物通过 `type="module"` 外链 JS/CSS；在 App 内 `file:// + WKWebView` 场景下容易静默失败。第一次内联时还踩到 `String.replace` 会把 JS 中的 `$&` 当成替换占位符，导致原始 `<script type="module"...>` 被重新插进内联脚本，破坏 HTML。
  - 修复：新增 `SettingsWeb/scripts/inline-assets.mjs`，构建后把 CSS/JS 安全内联进 `index.html`，并使用函数式替换避免 `$` 被误解释；同时转义 `</script>` / `</style>`。
  - 修复：内联 JS 会移动到 `</body>` 前执行，确保 React 启动时 `<div id="root">` 已存在；CSS 仍保留在 `<head>`，避免首屏无样式闪烁。
  - 修复：`VoiceWebSettingsWindowController` 注入前端错误上报脚本，Web 设置页如果再发生脚本错误，会在宿主日志中打印 `[SettingsWeb] ...`，不再只显示空白。
- 验证：
  - `npm install`：通过，无漏洞提示。
  - `npm run build`：通过。
  - `swift build --disable-sandbox -c debug --product NexVoiceApp`：通过。
  - `swift test --disable-sandbox --quiet`：通过，138 个测试通过。
  - `./scripts/build_app.sh release`：通过，已生成 `dist/NexVoice.app`。
  - `codesign --verify --deep --strict --verbose=2 dist/NexVoice.app`：通过。
  - 已确认 App 包内存在 `Contents/Resources/SettingsWeb/index.html`，且最终 HTML 没有 `type="module"` 外链和 `./assets/` 外链标签；CSS 位于 `<body>` 之前，JS 位于 `root` 节点之后、`</body>` 之前，包内 HTML 含 `#1CE5FF` 与 `0.1.9 (10)`。
  - 通过本地静态服务器打开 `SettingsWeb/dist/index.html`，冒烟测试通过：输出模式切换、工作流自定义下拉、词库筛选、词库弹窗、新增词条、筛选状态均正常。
- 重要边界：
  - 本轮按 Git 同步要求递增版本：`0.1.8 (9)` -> `0.1.9 (10)`。
  - 当前工作流里的“输出模式”先接到真实全局输出模式；如果要做到“每个工作流单独保存默认输出模式并影响实际改写链路”，还需要新增设置存储和主改写链路读取逻辑。

## 本轮完成（2026-06-24：设置页细节收口与私用 DMG）

- 设置页视觉与交互继续收口：
  - 左侧导航图标统一切到 `@tabler/icons-react`，输入页改名为 `常规`。
  - DeepSeek 评测菜单和临时评测功能已从工程中删除。
  - 设置窗口顶部可拖动，首次打开增加加载占位，减少 WebView 空白等待。
  - 菜单栏状态菜单按用户实际使用逻辑简化，移除 ASR 展示行，保留输出语言、输出模式、个人词库、权限等直接入口。
  - 工作流支持单独保存输出模式，新增 `VoiceWorkflowRewriteStyleStore` 和对应测试。
  - 输出模式页选中模块再次点击会重新播放参数条动画，动画速度调整为更利落。
  - 个人词库页复用工作流 Tab 和列表结构，修复外层容器 `overflow` 导致的圆角裁切；按钮、Tab、列表、模块圆角 token 收敛为外层 / 内层两级。
  - 添加词条弹窗输入框只保留单层亮灰焦点描边；工作流输出模式下拉箭头改为通用亮灰。
  - 工作流输出模式下拉菜单每项增加 2px 间隔，并通过提升所在行层级修复被下方卡片行压住/裁切的问题。
  - 设置页色彩体系调整为蓝灰中性色为主，品牌色改为 `#126DFF`，仅作为少量强调色使用；窗口外框恢复为较弱的冷色描边。
- 本轮私用包：
  - 已手动 bump 版本：`0.1.9 (10)` -> `0.1.10 (11)`，避免提交后版本与 DMG 不一致。
  - 使用 `./scripts/build_app.sh release --embed-local-keys` 构建，确认本机 DeepSeek / 腾讯云 ASR 配置文件已嵌入 App 资源目录。
  - 新 DMG：`dist/NexVoice-0.1.10-build11-settings-web-polish-embedded-keys-20260624.dmg`。
  - 新 DMG SHA256：`8d77054b15851cbbb044a6e7ed4170a10b709263c7a2523dbbf2dc703836562f`。
- 验证：
  - `SettingsWeb` `npm run build`：通过。
  - `./scripts/build_app.sh release --embed-local-keys`：通过。
  - `hdiutil verify dist/NexVoice-0.1.10-build11-settings-web-polish-embedded-keys-20260624.dmg`：通过。
  - 已挂载 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。
  - 已验证 DMG 内 `NexVoice.app` 签名通过。
  - 已验证 DMG 内 `DeepSeek.json` 和 `TencentCloudASR.json` 存在且非空，未在文档或 Git 中写入密钥内容。
  - `git diff --check`：通过。

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
  - 按住默认右 Alt 触发，同时抓取当前前台窗口可见文字并监听语音指令；松开右 Alt 后结束指令识别并生成回复。
  - 读取当前前台应用最大可见窗口，使用 Apple Vision 本地 OCR 提取可见文字。
  - 按文字位置粗略生成 `我 / 对方 / 未知` 结构；用户可在按住期间用语音指定语气、回复对象或回复方向。
  - 回复遵循当前输出语言和四个输出模式，最终写入当前输入框，但不自动发送。
  - 看屏监听阶段只显示极简状态条，不复用普通语音输入的实时转写大框或波形条。
  - DeepSeek prompt 明确要求生成新回复，默认禁止复读、翻译、整理或摘抄屏幕里的原句。
  - 该模式只基于屏幕可见内容，不滚动、不读取屏幕外历史；`screen_reply` 诊断日志不保存 OCR 全文。

## 本轮完成

- 2026-06-22 继续修复外设裸按键“录制窗口内可触发，关闭窗口后桌面失效”的问题：
  - 新症状：用户确认外设键可以录制，录制窗口还开着时也能触发；但关闭录制窗口、回到桌面或其他 App 后再次按键失效。
  - 进一步根因：录制窗口前台时主要依赖 App 内的 local monitor；窗口关闭后必须依赖真正的全局键盘通道。上一版只保留 Carbon + `NSEvent.addGlobalMonitorForEvents`，仍不能覆盖该外设键的桌面全局触发。
  - 修复：新增 `GlobalKeyboardEventTap`，使用 CoreGraphics `CGEvent.tapCreate(..., options: .listenOnly)` 监听全局 keyDown / keyUp / flagsChanged，作为 `.keyCombo` 的低层键盘回退。
  - event tap 只监听，不吞键、不改键盘输入；按下/松开仍复用 `GlobalVoiceShortcutMonitor` 原有短按/长按状态机，避免另建一套触发逻辑。
  - `VoiceShortcutGlobalCapturePolicy` 新增 `usesLowLevelKeyboardTapFallback(for:)`：仅 `.keyCombo` 启用低层 keyboard tap；右 Alt 仍走原 flagsChanged 路径。
  - 启动 `.keyCombo` 快捷键时，现在要求 Carbon 注册和低层 keyboard tap 都可用；如果失败，会提示 `需要输入监控权限` 或 `快捷键被占用`，不再静默失效。
  - 新增菜单项 `申请输入监控权限`，使用 CoreGraphics `CGRequestListenEventAccess()` 触发系统授权，并可跳转到系统“输入监控”设置页。
  - 新增测试：`.keyCombo` 必须启用低层 keyboard tap fallback。
  - `swift test --quiet` 通过 132 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - `git diff --check` 通过；仓库精确密钥扫描通过，未发现本机 AppID / SecretId / SecretKey 精确值写入仓库。
  - 已 bump 版本：`0.1.6 (7)` -> `0.1.7 (8)`。
  - 已重新构建并安装带本机配置的 `/Applications/NexVoice.app`，当前运行 PID 为 `76053`。
  - 安装版 `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - 安装版 `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 新 DMG：`dist/NexVoice-0.1.7-build8-keyboard-event-tap-embedded-keys-20260622.dmg`。
  - 新 DMG SHA256：`b3ec2f7a1ebaf26287478b4ab54832f4d340e961b3ff281dbb288af63d41445e`。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，App 内含 DeepSeek / TencentCloudASR 嵌入配置且字段完整。
  - `hdiutil verify dist/NexVoice-0.1.7-build8-keyboard-event-tap-embedded-keys-20260622.dmg` 通过。
  - 仍需用户真实验收：如果首次使用时提示 `需要输入监控权限`，从菜单点击 `申请输入监控权限` 并允许 NexVoice；授权后重新打开 App，再测试 F17/外设裸键在桌面和其他 App 中触发。
- 2026-06-22 继续修复外设裸按键“能录制但不能激活”的问题：
  - 用户实测截图显示快捷键可录制为 `Key 64`，说明设置窗口录制和 `UserDefaults` 写入已成功；本机偏好里也确认保存为 `{"keyCombo":{"modifiers":[],"keyCode":64}}`。
  - 根因：上一版让裸按键走 Carbon `RegisterEventHotKey`，但 `GlobalVoiceShortcutMonitor` 在 `usesRegisteredHotKey == true` 时直接忽略普通 `NSEvent` 全局 keyDown/keyUp；对这类外设/扩展功能键，Carbon 可能注册成功但实际不回调，导致“能录上但触发不了”。
  - 修复：注册热键路径继续保留，同时新增 `VoiceShortcutGlobalCapturePolicy.allowsEventMonitorFallback`；自定义组合键和裸按键即使走 Carbon，也会保留原有 `NSEvent.addGlobalMonitorForEvents` / local monitor 回退。
  - 这不是轮询，也不是另起一套复杂快捷键系统；只是避免 Carbon 成功注册后把本来可用的事件通道关掉。
  - 根据 macOS Carbon `Events.h`，`keyCode 64` 是 `kVK_F17`；已补充 F17 / F18 / F19 / F20 显示名，设置窗口以后会显示 `F17`，不再显示 `Key 64`。
  - 新增测试：注册热键快捷键必须保留 event monitor fallback；`keyCode 64` 显示为 `F17`。
  - `swift test --filter VoiceShortcut --quiet` 通过 17 个快捷键测试。
  - `swift test --quiet` 通过 131 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - `git diff --check` 通过；仓库精确密钥扫描通过，未发现本机 AppID / SecretId / SecretKey 精确值写入仓库。
  - 已 bump 版本：`0.1.5 (6)` -> `0.1.6 (7)`。
  - 已重新构建并安装带本机配置的 `/Applications/NexVoice.app`，当前运行 PID 为 `30562`。
  - 安装版 `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - 安装版 `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 新 DMG：`dist/NexVoice-0.1.6-build7-hotkey-event-fallback-embedded-keys-20260622.dmg`。
  - 新 DMG SHA256：`983f7a9ebcad3db15e23aee64462a10b7c44292aa911e63e6c3b9e96acba2d9d`。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，App 内含 DeepSeek / TencentCloudASR 嵌入配置且字段完整。
  - `hdiutil verify dist/NexVoice-0.1.6-build7-hotkey-event-fallback-embedded-keys-20260622.dmg` 通过。
  - 仍需用户真实验收：重新打开快捷键设置应看到 `F17`；关闭设置窗口后，在桌面和其他 App 中按外设键应能触发开始/结束语音输入。
- 2026-06-22 修复外设“裸按键”无法作为快捷键的问题：
  - 背景：用户需要把其他设备上绑定的独立按键录制为 NexVoice 快捷键，该按键不是键盘上的常规组合键，但会被 macOS 识别为一个独立 keyCode。
  - 根因：上一轮为了避免普通键盘字母误触，`VoiceShortcutRecordingPolicy` 把没有 Control / Option / Command / Shift 的 `keyDown` 全部过滤掉，导致外设裸按键无法录制。
  - 修复：`keyDown` 现在允许录制为空修饰键的 `.keyCombo(keyCode, modifiers: [])`；这类快捷键仍走 Carbon `RegisterEventHotKey` 系统全局热键注册，而不是回到不稳定的轮询/普通全局监听。
  - 如果裸按键被系统或其他 App 占用，注册失败时仍会显示 `快捷键被占用`；普通键盘裸字母也可被录制，但不建议用户把常用输入键当全局快捷键。
  - 修复裸按键显示名：例如 `K` 不再显示成带前导空格的 ` K`。
  - 设置窗口提示已更新，明确支持 `右 Alt`、`外设独立按键` 或常规组合键。
  - 新增/更新快捷键测试：裸按键录制、裸按键显示名、裸按键走 registered hotkey 策略。
  - `swift test --filter VoiceShortcut --quiet` 通过 16 个快捷键测试。
  - `swift test --quiet` 通过 129 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - `git diff --check` 通过；仓库精确密钥扫描通过，未发现本机 AppID / SecretId / SecretKey 精确值写入仓库。
  - 已 bump 版本：`0.1.4 (5)` -> `0.1.5 (6)`。
  - 已重新构建并安装带本机配置的 `/Applications/NexVoice.app`，当前运行 PID 为 `86824`。
  - 安装版 `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - 安装版 `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 新 DMG：`dist/NexVoice-0.1.5-build6-bare-hotkey-fix-embedded-keys-20260622.dmg`。
  - 新 DMG SHA256：`43754a917c34d5634b1fb87c6557a56cc17cf6ae66c4d0abc78c8e05809533b4`。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，App 内含 DeepSeek / TencentCloudASR 嵌入配置且字段完整。
  - `hdiutil verify dist/NexVoice-0.1.5-build6-bare-hotkey-fix-embedded-keys-20260622.dmg` 通过。
  - 仍需用户真实验收：用目标外设裸按键录制快捷键，关闭设置窗口后在桌面、浏览器、微信、Codex 等 App 中测试短按开始/结束语音输入，以及长按看屏回复。
- 2026-06-22 修复快捷键设置录制不稳定问题：
  - 根因 1：自定义组合键在 keyUp 阶段仍用 modifierFlags 做精确匹配；macOS 的 keyUp 事件经常已经不带修饰键，导致“录上了但松开后不能触发”。
  - 根因 2：快捷键设置窗口只用 local event monitor；窗口失焦或事件未派发给 NexVoice 时，录制状态下按键会没有反应。
  - 修复 `VoiceShortcut.matchesKeyReleaseEvent(keyCode:)`：组合键释放阶段只按 keyCode 结束，按下阶段仍严格校验 modifier 集合。
  - 新增 `VoiceShortcutRecordingPolicy`：统一右 Alt flagsChanged 录制和 keyDown 组合键录制逻辑。
  - `VoiceShortcutSettingsWindowController` 录制时同时监听 local/global event，并在窗口关闭时清理 monitor。
  - 录制期间临时停止主 `GlobalVoiceShortcutMonitor`，录制完成或窗口关闭后恢复，避免旧快捷键抢事件。
  - 新增快捷键录制/释放测试；`swift test --filter VoiceShortcut --quiet` 通过 13 个快捷键测试。
  - `swift test --quiet` 通过 126 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - 已 bump 版本：`0.1.2 (3)` -> `0.1.3 (4)`。
  - 已重新构建并安装带本机配置的 `/Applications/NexVoice.app`，当前运行 PID 为 `26124`。
  - 安装版 `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - 安装版 `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 新 DMG：`dist/NexVoice-0.1.3-build4-shortcut-recording-fix-embedded-keys-20260622.dmg`。
  - 新 DMG SHA256：`2f6b44dc9c17dd360362779b5d5e37d9eb5cc026c967f6921349cc854e772ab3`。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，App 内含 DeepSeek / TencentCloudASR 嵌入配置且字段完整。
  - `hdiutil verify dist/NexVoice-0.1.3-build4-shortcut-recording-fix-embedded-keys-20260622.dmg` 通过。
  - 仍需用户真实验收：打开“设置快捷键...”，多次录制右 Alt、`Control + Space`、`Option + Space` 等组合键，并确认录制后短按/长按均可触发预期流程。
- 2026-06-22 继续修复“录制窗口内可用、关闭后到其他 App 失效”的问题：
  - 进一步根因：设置窗口内靠 local monitor 捕捉按键，所以当场看起来可用；关闭窗口后进入其他 App 时，普通 `NSEvent.addGlobalMonitorForEvents` 对自定义组合键不够稳定，尤其是系统/输入法可能接管的组合键。
  - 修复策略：右 Alt / Fn 这种单修饰键仍走 `NSEvent.flagsChanged`；自定义组合键统一走 Carbon `RegisterEventHotKey`，使用系统全局热键注册机制。
  - 新增 `VoiceShortcutGlobalCapturePolicy`，明确 `.keyCombo` 使用 `.registeredHotKey`，右 Alt / Fn 使用 `.eventMonitor`。
  - 如果系统或其他 App 已占用该快捷键，注册失败后会显示 `快捷键被占用`，避免用户以为录制成功但外部场景不可用。
  - 录制策略改为忽略裸按键；只能录制右 Alt，或至少包含一个修饰键的组合键，避免把普通字母键注册为全局热键。
  - `swift test --filter VoiceShortcut --quiet` 通过 15 个快捷键测试。
  - `swift test --quiet` 通过 128 个测试。
  - `swift build --product NexVoiceApp` 通过。
  - 已 bump 版本：`0.1.3 (4)` -> `0.1.4 (5)`。
  - 已重新构建并安装带本机配置的 `/Applications/NexVoice.app`，当前运行 PID 为 `56878`。
  - 安装版 `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - 安装版 `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 新 DMG：`dist/NexVoice-0.1.4-build5-global-hotkey-fix-embedded-keys-20260622.dmg`。
  - 新 DMG SHA256：`6670c16c69489e8d71f7cbc262414073c8cc56d4647aae87b9a7410d2c21d66c`。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 和 `Applications` 快捷入口，App 内含 DeepSeek / TencentCloudASR 嵌入配置且字段完整。
  - `hdiutil verify dist/NexVoice-0.1.4-build5-global-hotkey-fix-embedded-keys-20260622.dmg` 通过。
  - 仍需用户真实验收：重点测试录制窗口关闭后，在桌面、浏览器、微信、Codex 等 App 中触发新快捷键。
- 2026-06-22 已按用户提供的新腾讯云 SecretId / SecretKey 更新本机 ASR 私有配置：
  - 配置文件：`~/Library/Application Support/NexVoice/TencentCloudASR.json`。
  - 文件权限：`600`。
  - 配置完整性检查通过：AppID、SecretId、SecretKey 三项均存在。
  - 没有把 AppID、SecretId、SecretKey 精确值写入仓库或文档。
  - 重新构建 `dist/NexVoice.app`，并完整替换安装到 `/Applications/NexVoice.app`。
  - 替换安装时先删除旧 `/Applications/NexVoice.app`，避免覆盖旧 bundle 后签名资源残留。
  - `codesign --verify --deep --strict /Applications/NexVoice.app` 通过。
  - `plutil -lint /Applications/NexVoice.app/Contents/Info.plist` 通过。
  - 已启动 `/Applications/NexVoice.app`，当前 `NexVoiceApp` 进程 PID 为 `60702`。
  - `swift test --filter TencentCloud --quiet` 通过 10 个腾讯云相关测试。
  - 尚未由用户做真实语音验收；仍需用户实际按右 Alt 测试腾讯云实时 ASR、DeepSeek 整理、文本写回和延迟体感。
- 2026-06-22 重新打包明确包含本机 Key/API 配置的私用 DMG：
  - 现有 `dist/NexVoice-0.1.2-build3-deepseek-configured.dmg` 已验证包含嵌入配置。
  - 现有 `dist/NexVoice-0.1.2-build3-latest.dmg` 已验证不包含嵌入配置，不应作为私用 Key 包分发。
  - 新包路径：`dist/NexVoice-0.1.2-build3-embedded-keys-20260622.dmg`。
  - SHA256：`d446d73711c0097a6ff247e0222bd461e0393dcf515da5fa528016e3cedd2874`。
  - 使用 `./scripts/build_app.sh release --embed-local-keys` 构建，确认 `NexVoice.app/Contents/Resources/NexVoiceEmbeddedConfig/DeepSeek.json` 和 `TencentCloudASR.json` 均存在且字段完整。
  - 已挂载新 DMG 验证根目录包含 `NexVoice.app` 与 `Applications` 快捷入口。
  - 已验证 DMG 内 `NexVoice.app` 签名通过。
  - `hdiutil verify dist/NexVoice-0.1.2-build3-embedded-keys-20260622.dmg` 通过。
- 修复普通语音输入首次显示时波形浮层“先矮后被拉高”的问题：
  - 原因是紧凑波形态外框高度为 `44`，但内部需要 `上内边距 14 + 波形高度 28 + 下内边距 14 = 56`。
  - 将 `compactPanelSize.height` 和默认 `panelSize.height` 调整为 `56`，让面板第一次出现时就满足内部约束。
  - 保持波形高度为 `28`，上下内边距仍为 `14`，波形内容在外框中垂直居中。
  - 增加测试约束，防止未来再次把紧凑态高度改到小于内部布局所需高度。
- 已重新构建带本机 API 配置的 APP / DMG：
  - 版本：`0.1.2 (3)`
  - APP 路径：`dist/NexVoice.app`
  - DMG 路径：`dist/NexVoice-0.1.2-waveform-height-fix.dmg`
  - SHA256：`7fc6cc812c2619770f00e33dd73e90f06ea2c50f2e09439f5dc4798556885864`
- 新增仓库内版本递增自动化：
  - `scripts/bump_version.sh`：统一递增 `Resources/NexVoiceHost/Info.plist`、`Resources/NexVoiceRewriteEval/Info.plist`、`Resources/NexVoiceRewriteEvalRunner/Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`。
  - `.githooks/pre-commit`：提交前检测 staged 内容，只要包含真实迭代改动，就自动执行版本递增并重新 stage 版本文件。
  - `scripts/install_git_hooks.sh`：把仓库 hook 安装到本地 `.git/hooks/pre-commit`，避免依赖人工手动改版本号。
  - 可用 `NEXVOICE_SKIP_VERSION_BUMP=1` 临时跳过自动递增，仅用于极特殊维护场景。
- 看屏回复交互进一步简化：按住时只显示 `识别中`；如果检测到语音指令，显示 `识别到指令`；松开后直接进入 `AI 输入中`。
- 修复 `识别到指令` 状态反复抖动：同一轮看屏回复里只允许从 `识别中` 切换到 `识别到指令` 一次，后续 partial 识别结果不会重复触发状态条动画。
- 看屏回复分支不再调用普通语音输入的 `captionPanel.apply(event)`，因此不会展示实时识别文字、波形条或普通语音输入大框。
- `VoiceCaptionPanelController.showPassiveMessage` 对相同文案做 no-op，避免重复调用导致面板重算尺寸或重放过渡动画。
- 本轮待重新构建带本机 API 配置的 DMG：
  - 路径：`dist/NexVoice-20260621-screen-status-debounce.dmg`
  - SHA256：`d385272f6f0b870c50e705b628d262af856ca4bc07668fb2ecbfe32689f7cf9c`

## 上轮完成

- 修复用户截图中的浮层上下间距不一致问题：外层上下 padding 统一为左右 padding 的 `14`。
- 修复单行翻译/输出结果贴上沿的问题：文本容器会按当前内容高度动态设置上下内边距，单行时在垂直方向居中。
- 彻底禁用文本结果浮层横向滚动：去掉 `scrollToEndOfDocument` 导致的横向偏移，只允许纵向滚动，并强制横向 origin 为 `0`，避免出现滚动条时左侧文字被裁切。
- 修复看屏回复容易复读上方聊天记录的问题：`screen_reply` prompt 改为“生成一条新回复”，并明确禁止在默认情况下复读、翻译、整理、改写或摘抄屏幕里的原句。
- 看屏回复改为按住式语音指令：长按右 Alt 后同时抓屏和开启腾讯云 ASR；松开右 Alt 结束识别，DeepSeek 会结合屏幕上下文和语音指令生成回复。如果没有识别到指令，会按默认上下文生成自然回复。
- 本轮待重新构建带本机 API 配置的 DMG：
  - 路径：`dist/NexVoice-20260621-hold-screen-instruction.dmg`
  - SHA256：`d748a6604eb1cbb5cde58e4c2e9d395cf2d8ad7f74d824465f592e8fedaaaaee`

## 更早完成

- 修复用户截图中的严重浮层问题：选中文本后语音指令的翻译结果不再左右裁切，滚动条改为悬浮 overlay，不再挤压正文导致文字消失。
- 同步修复实时识别文字框：识别草稿和结果框共用同一套文本容器宽度、正文内边距和滚动条安全区。
- 提高最大展示高度：
  - 实时识别浮层最大高度从 `128` 提到 `180`。
  - 选中文本指令结果浮层最大高度提高到 `300`，尽量减少长翻译结果的滚动条。
- 新增布局测试，防止最大高度和滚动条安全区被回退。
- 本轮待重新构建带本机 API 配置的 DMG：
  - 路径：`dist/NexVoice-20260621-text-panel-fix.dmg`
  - SHA256：`0d6851c5d339b65230eaa372a8d5ea4be722ec958dc7563b0cb8d4ae30e6f203`

## 更早完成

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
- `hdiutil attach -readonly -nobrowse dist/NexVoice-0.1.2-waveform-height-fix.dmg`：通过，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。
- `hdiutil attach -readonly -nobrowse dist/NexVoice-20260621-screen-status-debounce.dmg`：通过，根目录包含 `NexVoice.app` 和 `Applications` 快捷入口。

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
