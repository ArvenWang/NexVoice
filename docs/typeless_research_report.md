# Typeless 产品调研与个人复刻建议

调研日期：2026-06-18  
调研对象：Typeless，AI voice dictation / voice keyboard 产品  
目标：判断个人是否能复刻类似产品，并给出产品、技术、模型、差异化路线建议。

## 1. 结论先说

Typeless 本质上不是传统“语音转文字”工具，而是一个系统级 AI 输入层：

1. 用户按住快捷键或切换到语音键盘说话。
2. 系统捕获音频和少量上下文，例如当前应用、选中文本、附近文本。
3. 云端 ASR 把语音转成文本。
4. LLM 再做清理、改写、结构化、翻译、语气适配、纠错。
5. 客户端把结果插入任何可输入的地方。

个人可以复刻一个“有商业价值的窄版”，但不建议一开始复刻 Typeless 的完整全平台产品。最现实路线是：

- 第一阶段只做 macOS，聚焦中文/英文混合、AI 工具提示词、邮件/IM/文档场景。
- 核心卖点不要是“我也能转写”，而是“我能把碎话稳定变成你想要的文本，并且不会过度改写”。
- 模型组合建议：OpenAI `gpt-4o-transcribe` 或 `gpt-4o-mini-transcribe` 做转写，`gpt-5.4-mini` 或 `gpt-5.5` 做后处理；再提供本地 Whisper/SenseVoice 隐私模式。
- 要比 Typeless 更好，优先解决它公开评论里反复出现的问题：过度润色、移动端不能快速打字/emoji、缺少按应用自定义、长语音中断、术语纠错不够稳定。

核心判断：一个人可以做出 70% 体验，并以单平台切入商业化；要做到 Typeless 当前的全平台、低延迟、稳定、合规、订阅体系和增长规模，通常需要小团队。

## 2. Typeless 是什么

官方定位是 AI voice dictation，进一步的公司愿景是 voice OS company。它的 Manifesto 明确把“键盘是旧时代输入方式”作为产品叙事，目标不是做录音转写，而是重做“输入层”。

官方 About 页显示，公司主体是 Simply CA LLC，位于 Palo Alto，创始人兼 CEO 是 Huang Song，团队自称为 Stanford 校友和连续创业者，并获得 Stanford 相关创业加速器支持。

公开来源：

- 官网功能页：https://www.typeless.com/
- About：https://www.typeless.com/about
- Manifesto：https://www.typeless.com/manifesto
- Product Hunt：https://www.producthunt.com/products/typeless-2

## 3. 当前功能拆解

### 3.1 核心输入功能

Typeless 的基础流程是“自然说话 -> 自动变成可直接发送的文字”。它强调用户不需要像传统听写那样刻意说标点，而是可以说碎话、停顿、反复修正。

公开功能包括：

- 去掉 filler words，例如 um、uh、you know。
- 去掉重复表达。
- 识别用户中途反悔或自我修正，只保留最终意思。
- 理解意图，而不是逐字转写。
- 自动格式化列表、步骤、重点。
- 100+ 语言支持和自动语言检测。
- 个人词典，支持人名、术语、特殊拼写。
- 按应用自动调整语气，例如邮件更正式、聊天更自然。

来源：

- 官网功能页：https://www.typeless.com/
- macOS beta release note：https://www.typeless.com/help/release-notes/macos/introducing-typeless-macos-app-beta
- Windows beta release note：https://www.typeless.com/help/release-notes/windows/introducing-typeless-windows-app-beta

### 3.2 编辑与问答功能

Typeless 已经从“语音输入”延展到“选中文本后用语音操作文本”：

- Speak to edit selected text：选中文本，说“缩短一点”“换成更专业”“翻译成英文”等。
- Speak to ask about selected text：选中网页或文档的一段内容，询问总结、解释、翻译。
- Quick answers & actions：官方首页提到可以查最新信息、头脑风暴、搜索网站和服务、打开相关页面。

这说明它的产品方向正在从“输入法”走向“跨应用 AI 助手”，也就是轻量 voice OS。

来源：https://www.typeless.com/

### 3.3 翻译功能

Typeless 支持边说边翻译，并强调翻译后的文本不像机器翻译，而是像本地人会写的表达。Google Play 当前更新说明也强调 Translate 会把你的话变成可直接发送的信息、邮件或帖子，并适配目标语言下的语气和用途。

来源：

- 官网功能页：https://www.typeless.com/
- Google Play 页面：https://play.google.com/store/apps/details?id=com.typeless.mobile&hl=en_US

### 3.4 平台覆盖

截至 2026-06-18，公开页面显示 Typeless 支持：

- macOS 桌面端
- Windows 桌面端
- iOS 语音键盘
- Android 语音键盘

官网 Downloads 页提供 macOS、Windows、App Store、Google Play 入口。

来源：https://www.typeless.com/downloads

### 3.5 隐私与数据

Typeless 对外主打：

- zero cloud data retention
- 不用用户数据训练模型
- 本地保存 dictation history
- 云端实时处理音频和有限上下文，结果返回后立即丢弃
- 使用第三方 LLM provider，例如 OpenAI，但声称配置为 zero retention

重要判断：Typeless 不是纯本地产品。它自己在 Data Controls 页面写明 cloud processing，并说明会使用 leading LLM providers such as OpenAI。

来源：

- Privacy Policy：https://www.typeless.com/privacy
- Data Controls：https://www.typeless.com/data-controls
- Trust Center：https://trust.typeless.com/

## 4. 发展历程

根据公开资料，可以大致还原 Typeless 的发展路线：

1. 2025-08-14：macOS beta V0.1.0 发布。核心功能已经包括自动润色、去 filler、去重复、自我修正、自动格式化、按应用语气、100+ 语言、个人词典、隐私声明。
2. 2025-10-22：Windows beta V0.1.0 发布，说明它从 Mac 单平台扩展到 Windows。
3. 2025-11-18：Product Hunt 上线 Typeless，获得当日 #1、当周 #4。Product Hunt 页面显示产品 launched in 2025。
4. 2025-12-24：Typeless for iOS 上线 Product Hunt，获得当日 #1、当周 #2。
5. 2026-01-20：Typeless for Android 上线 Product Hunt，获得当日 #3。
6. 2026-06：移动端已经有较明显规模。Google Play 页面显示 500K+ downloads、约 1.9K reviews、4.5 star；App Store 显示 513 ratings、4.6。

来源：

- Product Hunt Launches：https://www.producthunt.com/products/typeless-2
- macOS release note：https://www.typeless.com/help/release-notes/macos/introducing-typeless-macos-app-beta
- Windows release note：https://www.typeless.com/help/release-notes/windows/introducing-typeless-windows-app-beta
- Google Play：https://play.google.com/store/apps/details?id=com.typeless.mobile&hl=en_US
- App Store：https://apps.apple.com/us/app/typeless-ai-voice-keyboard/id6749257650

## 5. 商业模式与价格

Typeless 当前价格：

- Free：8,000 words/week，标准准确度，标准高峰期访问。
- Pro：$12 / member / month，按年计费；月付 $30。
- Pro 包括 unlimited words、enhanced accuracy、priority access、team member management、prioritized feature requests、early access。

这说明它实际做的是 SaaS 订阅，核心计费单位是“可用字数/质量/高峰优先级”，不是按分钟或 API 成本透明计费。

来源：https://www.typeless.com/pricing

## 6. 技术逻辑推断

以下是基于公开功能、隐私声明、OS 平台机制和同类产品形态的技术推断，不代表 Typeless 官方披露的内部架构。

### 6.1 桌面端链路

桌面端大概率包含：

1. 全局快捷键监听。
2. 麦克风录音和 VAD 断句。
3. 当前 app/window/text field 检测。
4. 音频流或音频片段上传云端。
5. ASR 模型转写。
6. LLM 做意图清理、格式化、翻译、语气适配。
7. 用粘贴板、键盘事件、Accessibility API 或 UI Automation 把结果插回当前输入框。

macOS 上，全局跨应用文本操作通常依赖 Accessibility API。Apple 的 AXUIElement 文档说明 assistive applications 可以与 macOS 上的 accessible applications 通信和控制。Windows 上类似能力通常靠 Microsoft UI Automation，它提供桌面 UI 元素的程序化访问和操作。

官方 OS 资料：

- Apple AXUIElement：https://developer.apple.com/documentation/applicationservices/axuielement_h
- Microsoft UI Automation：https://learn.microsoft.com/en-us/windows/win32/winauto/entry-uiauto-win32

### 6.2 移动端链路

移动端更像“第三方键盘”：

- Android：可做 IME。Android 官方文档说明系统支持第三方 input method，安装后可在全系统输入。
- iOS：可做 custom keyboard extension，但限制更多。Apple 文档说明用户必须显式开启 Allow Full Access，键盘才有更高权限。第三方键盘还有边界、内存、网络、输入框限制。

这也是为什么用户评论里会出现“不能方便切回普通键盘”“没有 emoji/GIF”“iPhone 操作有摩擦”等问题。不是简单 UI 没做好，而是平台机制本身有约束。

官方 OS 资料：

- Android input method：https://developer.android.com/develop/ui/views/touch-and-input/creating-input-method
- Apple custom keyboard open access：https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- Apple custom keyboard guide：https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html

### 6.3 AI 管线

最可能的 AI 管线不是单模型完成，而是多段式：

1. ASR：将语音转为原始文本。
2. NLU/cleaning：去口头禅、重复、错误自修正。
3. Context-aware rewrite：结合当前应用、目标场景、个人风格、词典。
4. Guardrail：避免过度改写、避免幻觉、保留用户意思。
5. Output policy：根据 Gmail、Slack、Notion、Cursor、ChatGPT 等不同应用输出不同风格。

Typeless Data Controls 公开说明会处理语音音频和有限上下文，包括当前应用和相关文本，以提供 context-aware transcription。这基本印证了“音频 + 应用上下文 + 文本上下文”的管线。

来源：https://www.typeless.com/data-controls

## 7. 竞品格局

### 7.1 Wispr Flow

定位非常接近 Typeless：跨应用 AI dictation，Mac、Windows、iPhone、Android。主打 clear polished writing。价格公开资料显示 Pro 大约 $15/month 或 $12/month annual。优势是品牌早、跨平台、体验成熟；劣势是云端、价格高、部分用户反馈可靠性和隐私担忧。

来源：

- 官网：https://wisprflow.ai/
- Google Play：https://play.google.com/store/apps/details?id=com.wispr.flowapp&hl=en_US

### 7.2 Superwhisper

主打 macOS、Windows、iOS，支持 offline 和 cloud speech recognition、100+ languages、custom AI modes、BYOK。它和 Typeless 的最大差异是“更偏 power user 和隐私/本地可控”，不一定主动把用户话术改得很漂亮。

来源：https://superwhisper.com/

### 7.3 Aqua Voice

Aqua 主打速度、低延迟、上下文识别、Mac/Windows。公开页面强调 fast、accurate、private，并称可在 text field、Cursor、Gmail、Slack、terminal 等地方输入。适合技术用户、开发者、vibe coding。

来源：

- 官网：https://aquavoice.com/
- Product Hunt：https://www.producthunt.com/products/aqua

### 7.4 TalkTastic

TalkTastic 更早提出 context-aware voice keyboard，重点是个人上下文、智能 rewrite、macOS 跨应用。

来源：

- 官网：https://talktastic.com/
- Help：https://help.talktastic.com/en/articles/9554689-new-to-talktastic-start-here

### 7.5 Typeless 的相对位置

Typeless 的差异点是：

- 更强“AI 改写感”，不是纯转写。
- 全平台进展很快，桌面和移动都有。
- 产品叙事强，voice OS 方向明确。
- 免费额度比部分竞品更慷慨。

弱点也明显：

- 云端处理，隐私用户会犹豫。
- 过度改写会伤害“这是我说的话”的信任感。
- 移动端第三方键盘体验天然受限。
- 对专业术语、特殊场景、按应用自定义还有优化空间。

## 8. 个人复刻可行性

### 8.1 可以复刻的部分

一个人可以在 1-3 个月做出：

- macOS 全局快捷键录音。
- 调用 ASR API 转写。
- 调用 LLM 做清理和改写。
- 个人词典。
- 简单 app-aware prompt，例如 Gmail/Slack/Notion/Cursor。
- 把结果粘贴回输入框。
- 本地历史、基础设置、订阅前的 MVP。

这已经能形成一个可售卖的小产品。

### 8.2 难复刻的部分

难点不是模型，而是工程细节：

- 低延迟：用户说完后 1 秒内出字才像输入法，3-5 秒就像工具。
- 跨 app 插入稳定性：不同 app、网页、Electron、Terminal、富文本框行为不同。
- 光标/选中文本处理：替换选区、保留格式、撤销栈、输入法兼容都麻烦。
- 移动端键盘：iOS 限制多，Android 也有输入法切换和权限信任问题。
- AI 可控性：不能乱加内容、乱格式化、乱“发挥”。
- 隐私合规：你处理的是语音、文本、当前 app、可能还有屏幕上下文，属于高敏感产品。

### 8.3 推荐切入口

不建议从“全平台 Typeless clone”开始。推荐：

第一版产品名义：AI 语音输入法 for Mac，专为中文/英文混合工作流设计。  
目标人群：AI 重度用户、PM、设计师、开发者、内容创作者、需要大量和 ChatGPT/Cursor/Claude/Notion/Gmail 沟通的人。  
核心承诺：随便说，它帮你变成能直接粘贴的清楚文字，但你能控制它“忠实转写”还是“智能润色”。

## 9. 推荐技术架构

### 9.1 MVP 架构

客户端：

- macOS 原生 Swift/SwiftUI。
- AVAudioEngine 录音。
- Global hotkey。
- Accessibility permission。
- AXUIElement 获取当前 app、选中文本、focused element。
- Clipboard paste 或模拟键盘输入。
- 本地 SQLite 存历史、词典、风格配置。

后端：

- FastAPI 或 Node.js。
- Auth：Clerk/Supabase/Auth0 任一。
- DB：Postgres。
- Queue：可选，MVP 暂时不需要。
- Billing：Stripe。
- Observability：Sentry + PostHog。

AI：

- VAD：Silero VAD 或 WebRTC VAD。
- ASR：OpenAI Transcription API 起步。
- LLM 后处理：OpenAI Responses API。
- 可选本地模式：whisper.cpp / faster-whisper / SenseVoice。

### 9.2 AI prompt 设计

后处理 prompt 应该显式区分模式：

- Exact mode：尽量忠实，只修错字、标点、明显口头禅。
- Polish mode：清楚、自然、可发送，但不添加新事实。
- Structured mode：把碎话整理成标题、列表、行动项。
- Translate mode：按目标语言和目标场景本地化。
- Command mode：选中文本后执行“缩短、改正式、翻译、解释”等指令。

最重要的产品规则：

- 不准补充用户没说过的新事实。
- 不准擅自加结尾寒暄，例如“感谢观看”。
- 不确定的专有名词保留原音或向个人词典靠拢。
- 输出应按 app profile 控制，例如 Slack 不要过度格式化，Gmail 可以更完整。

## 10. 模型选择建议

### 10.1 OpenAI 方案

OpenAI 官方实时和音频文档把任务分成几类：

- 低延迟语音 agent：`gpt-realtime-2`
- 实时转写：`gpt-realtime-whisper`
- 文件或 bounded audio 转写：audio transcription models

官方实时转写文档建议：

- `gpt-realtime-whisper`：live audio、transcript deltas、可调延迟。
- `gpt-4o-transcribe`：更高准确率，但不需要流式时更适合。
- `gpt-4o-mini-transcribe`：更低成本。
- `whisper-1`：已有 Whisper 集成。

官方价格页显示：

- `gpt-4o-transcribe` 约 $0.006/minute。
- `gpt-4o-mini-transcribe` 约 $0.003/minute。
- `gpt-realtime-whisper` 约 $0.017/minute。

模型选择：

- MVP：`gpt-4o-transcribe` + `gpt-5.4-mini` 后处理。
- 低成本版：`gpt-4o-mini-transcribe` + `gpt-5.4-mini`。
- 高质量版：`gpt-4o-transcribe` + `gpt-5.5` low/medium reasoning。
- 实时预览版：`gpt-realtime-whisper` 用于边说边出草稿，结束后再用 `gpt-4o-transcribe` 或 LLM final polish。

来源：

- OpenAI Realtime/audio overview：https://developers.openai.com/api/docs/guides/realtime
- OpenAI realtime transcription：https://developers.openai.com/api/docs/guides/realtime-transcription
- OpenAI speech-to-text：https://developers.openai.com/api/docs/guides/speech-to-text
- OpenAI pricing：https://developers.openai.com/api/docs/pricing
- OpenAI latest model guide：https://developers.openai.com/api/docs/guides/latest-model
- OpenAI models：https://developers.openai.com/api/docs/models

### 10.2 非 OpenAI ASR 备选

如果你想降成本或提升实时转写速度，可以评估：

- Deepgram Nova-3：官方 pricing 显示标准 Nova-3 pay-as-you-go 大约 $0.29/hour monolingual streaming、$0.35/hour multilingual streaming。
- Groq Whisper large-v3-turbo：官方 pricing 显示约 $0.04/hour transcribed，极低成本，但需要自己评测中文、噪声、专有名词质量。
- ElevenLabs Scribe v2：官方强调 90+ 语言和实时 STT，适合高准确率评测。

来源：

- Deepgram pricing：https://deepgram.com/pricing
- Groq pricing：https://groq.com/pricing
- ElevenLabs STT docs：https://elevenlabs.io/docs/overview/capabilities/speech-to-text

### 10.3 本地模型备选

本地模式适合做差异化：

- Whisper large-v3-turbo：成熟、生态强、多语言。
- SenseVoice：中文、粤语、英语、日语、韩语等亚洲语言场景值得评测。
- NVIDIA Parakeet：更偏高吞吐和部分欧洲语言。
- Moonshine：主打本地、低延迟、跨平台语音应用。

来源：

- Whisper large-v3-turbo：https://huggingface.co/openai/whisper-large-v3-turbo
- SenseVoice：https://github.com/FunAudioLLM/SenseVoice
- Parakeet：https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- Moonshine：https://usefulsensors.com/

## 11. 如何做得比 Typeless 更好

### 11.1 做“可控改写”，不是一味更聪明

Typeless 用户评论里最典型的问题是 AI 有时过度发挥：加不该加的格式、结尾、词，或者把专业词改错。你可以把“可控”作为核心卖点。

建议内置三档：

- 原话模式：只修错别字和标点。
- 清晰模式：去口头禅、去重复、稍微润色。
- 作品模式：结构化、改语气、翻译、本地化。

每次输出旁边给一个“一键还原原话”。

### 11.2 按应用自定义

Product Hunt 评论里有用户明确希望不同软件输出不同风格，例如聊天保留口吻，工作邮件更正式，Figma/设计标注更结构化。

建议做 app profiles：

- ChatGPT/Cursor：保留完整上下文，输出 prompt 风格。
- Slack/微信/WhatsApp：短、自然、少格式。
- Gmail/Superhuman：完整、礼貌、有主题。
- Linear/Jira：自动拆成问题、期望结果、验收标准。
- Figma/Notion：自动结构化成标题、要点、决策。

### 11.3 中文/中英混说优化

Typeless 虽然支持 100+ 语言，但如果你面向中文用户，可以专门做：

- 中英混合术语词典。
- 常见 AI 工具词汇：prompt、workflow、agent、MCP、Figma、Cursor、PRD。
- 中文口语整理成产品/技术/商业表达。
- “中文说，英文写”且保留业务语气。

这比泛语言支持更容易形成口碑。

### 11.4 移动端不要只做语音键盘

Google Play 和 App Store 评论都暴露了移动端痛点：

- 用户有时必须手打密码、短词、人名。
- 需要 emoji/GIF。
- 不想频繁切回系统键盘。
- 语音键盘如果不能快速打字，会影响日常主键盘替代。

如果你做移动端，必须把普通键盘、emoji、语音按钮、快速切换放在同一个键盘里，而不是只做一个麦克风界面。

### 11.5 隐私模式和 BYOK

Typeless 是云端处理。你可以做：

- Local mode：本地 Whisper/SenseVoice，仅转写，不上传。
- Cloud smart mode：上传做高质量润色。
- BYOK：用户填自己的 OpenAI/Deepgram key。
- 企业模式：不保存文本，不记录音频，日志脱敏。

这会吸引开发者、律师、医疗、咨询、企业用户。

## 12. MVP 计划

### 0-2 周：验证技术闭环

- macOS 菜单栏 app。
- 按住快捷键录音。
- 松开后上传转写。
- LLM 清理成文本。
- 粘贴到当前输入框。
- 本地历史记录。

成功标准：

- 10 秒语音，结束后 1.5-3 秒内出结果。
- Gmail、Notion、Cursor、Slack、Chrome 文本框可用。
- 中文/英文/中英混合基本准确。

### 3-6 周：做成可日用

- 个人词典。
- 三种输出模式。
- app profiles。
- 选中文本后语音编辑。
- 错误反馈按钮。
- 快捷键设置。
- 本地隐私说明。

成功标准：

- 连续用一周不想关掉。
- 100 条真实语音样本里，80 条无需修改即可发送或粘贴。

### 7-12 周：商业化 MVP

- 登录、订阅、免费额度。
- 用量统计。
- onboarding。
- 更新机制。
- 崩溃上报。
- 官网下载页。
- 20-50 个种子用户。

成功标准：

- 至少 10 个用户连续使用 7 天。
- 至少 3 个用户愿意付费。
- 主要投诉集中在可改进体验，而不是“根本不可用”。

## 13. 主要风险

1. 平台权限风险：macOS Accessibility、iOS keyboard full access、Android IME 都会让用户担心隐私。
2. 延迟风险：模型慢一点就从“输入法”变成“转写工具”。
3. 过度改写风险：AI 加了用户没说过的内容，会严重破坏信任。
4. 成本风险：如果免费额度太大，ASR + LLM 成本会被重度用户打穿。
5. 获客风险：AI dictation 市场已经有 Typeless、Wispr Flow、Superwhisper、Aqua，泛泛而做很难赢。
6. 移动端风险：iOS/Android 键盘是深坑，不建议第一阶段做。

## 14. 我给你的推荐方向

如果你的目标是个人做出比 Typeless 更好的东西，我建议方向是：

产品定位：

> 面向中文和中英混合工作者的可控 AI 语音输入层，先做 Mac，专注把碎话稳定变成邮件、prompt、需求、设计备注和任务。

不要和 Typeless 正面拼：

- 全平台
- 100+ 语言
- 最大增长
- 最漂亮品牌

要拼：

- 中文/中英混说更准
- 不乱改
- 按 app 定制更强
- 本地/隐私模式
- AI 工具用户体验更好
- 开发者、设计师、PM 的垂直工作流

第一版不要叫“Typeless clone”。应该是一个更垂直、更可控、更专业的 voice-to-work 工具。

## 15. 最小技术选型

推荐：

- macOS 客户端：Swift + SwiftUI。
- 云后端：FastAPI + Postgres + Redis 可选。
- ASR：OpenAI `gpt-4o-transcribe` 起步；成本版用 `gpt-4o-mini-transcribe`。
- 后处理：OpenAI `gpt-5.4-mini` 起步；复杂命令用 `gpt-5.5`。
- 本地模式：后续加 Whisper large-v3-turbo 或 SenseVoice。
- 支付：Stripe。
- 监控：Sentry。
- 产品分析：PostHog，注意不要记录用户正文。

不推荐第一版：

- 同时做 Mac/Windows/iOS/Android。
- 自研 ASR。
- 自研大模型。
- 先做团队管理和企业合规。
- 先做完整语音 agent。

## 16. 需要马上验证的问题

真正动手前，建议先做 5 个小实验：

1. macOS 当前光标输入稳定性：Chrome、Cursor、Notion、Slack、Gmail 是否能稳定粘贴。
2. 中文/中英混合 ASR 质量：OpenAI、Groq、Deepgram、SenseVoice 各跑 100 条样本。
3. 后处理 prompt：是否能严格避免加新事实。
4. 延迟：10 秒音频端到端是否能压到 2 秒左右。
5. 用户价值：找 10 个重度 AI 工具用户试用，记录他们每天真实节省多少输入时间。

只要这 5 个实验通过，就值得继续做商业化 MVP。

