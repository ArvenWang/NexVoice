# NexVoice DeepSeek 上下文评测

- 模式：dry-run，仅检查 prompt
- 场景数：11

## Agent 协作：中文结构化需求

- ID：agent-zh-structure
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我们现在先别急着做界面，先帮我判断一下这个需求有没有问题，然后如果没有问题你就直接改，第一点是要低延迟，第二点是要保留 loading 状态，第三点是如果没有输入框就复制到剪贴板，嗯大概是这样。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：优先整理成目标、约束、步骤、问题和期望结果，表达要直接、可执行。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
- 输入框已有内容片段：
请继续实现 NexVoice 的语音输入稳定性优化。
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我们现在先别急着做界面，先帮我判断一下这个需求有没有问题，然后如果没有问题你就直接改，第一点是要低延迟，第二点是要保留 loading 状态，第三点是如果没有输入框就复制到剪贴板，嗯大概是这样。
```

结果：dry-run 未发起模型请求。

## Agent 协作：连续想法不强行结构化

- ID：agent-zh-natural-no-list
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我刚才想了一下，这个事情可能不要做得太复杂，重点还是先保证它每次都能稳定写进去，不然用户会觉得不可信，然后后面再慢慢加那些更高级的功能。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：优先整理成目标、约束、步骤、问题和期望结果，表达要直接、可执行。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
- 输入框已有内容片段：
我们继续评估 NexVoice 的功能优先级。
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我刚才想了一下，这个事情可能不要做得太复杂，重点还是先保证它每次都能稳定写进去，不然用户会觉得不可信，然后后面再慢慢加那些更高级的功能。
```

结果：dry-run 未发起模型请求。

## 即时沟通：普通聊天保持自然段

- ID：chat-zh-natural
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Slack|com.tinyspeck.slackmacgap|workChat|normal_input|dictionary_terms_3

输入：
```text
我今天可能会晚一点到，你们先开始不用等我，我到的时候再看一下前面的讨论记录，然后有问题我再补充。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Slack
- 应用类型倾向：即时沟通：保持简洁、自然、行动明确，避免过长铺垫。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Message input
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我今天可能会晚一点到，你们先开始不用等我，我到的时候再看一下前面的讨论记录，然后有问题我再补充。
```

结果：dry-run 未发起模型请求。

## 海外社交：中文口述转自然英文评论

- ID：social-en-natural
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Google Chrome|com.google.Chrome|socialConversation|normal_input|dictionary_terms_3

输入：
```text
我想回复他说，我同意这个方向，但是这个东西最大的问题不是功能多少，而是它每一次都能不能稳定工作，如果输入一次失败一次，用户很快就不会再信任它了。
```

Prompt 片段：
```text
输出语言模式：
Please output the final text in natural American English. If the source is Chinese or mixed Chinese-English, translate and rewrite it so it sounds like something a fluent native speaker would actually post in a Reddit comment, YouTube reply, or Twitter/X conversation.
Avoid literal, stiff, textbook, corporate, or obviously translated phrasing. Use contractions and idiomatic wording when they fit, but do not force slang, memes, emojis, jokes, or attitude that the user did not imply.
Preserve the user's meaning, tone, and level of certainty. Keep proper nouns, code terms, product names, and intentional mixed-language terms when appropriate. Prefer natural paragraphs by default; use numbered points only for actual task lists, steps, comparisons, or explicit requests for structured output.

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Google Chrome
- 应用类型倾向：社交评论或公开回复：表达要像真人自然发言，避免翻译腔、营销腔和过度正式。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Reddit comment box
- 输入框已有内容片段：
What do you think about voice-first AI tools?
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我想回复他说，我同意这个方向，但是这个东西最大的问题不是功能多少，而是它每一次都能不能稳定工作，如果输入一次失败一次，用户很快就不会再信任它了。
```

结果：dry-run 未发起模型请求。

## 海外社交：单个观点不编号

- ID：social-en-no-list
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Google Chrome|com.google.Chrome|socialConversation|normal_input|dictionary_terms_3

输入：
```text
我想说这个产品最吸引我的地方不是它功能多，而是它让我不用切换上下文，想到什么就可以直接说出来，这个感觉很重要。
```

Prompt 片段：
```text
输出语言模式：
Please output the final text in natural American English. If the source is Chinese or mixed Chinese-English, translate and rewrite it so it sounds like something a fluent native speaker would actually post in a Reddit comment, YouTube reply, or Twitter/X conversation.
Avoid literal, stiff, textbook, corporate, or obviously translated phrasing. Use contractions and idiomatic wording when they fit, but do not force slang, memes, emojis, jokes, or attitude that the user did not imply.
Preserve the user's meaning, tone, and level of certainty. Keep proper nouns, code terms, product names, and intentional mixed-language terms when appropriate. Prefer natural paragraphs by default; use numbered points only for actual task lists, steps, comparisons, or explicit requests for structured output.

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Google Chrome
- 应用类型倾向：社交评论或公开回复：表达要像真人自然发言，避免翻译腔、营销腔和过度正式。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：YouTube reply box
- 输入框已有内容片段：
Do voice tools actually change how you work?
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我想说这个产品最吸引我的地方不是它功能多，而是它让我不用切换上下文，想到什么就可以直接说出来，这个感觉很重要。
```

结果：dry-run 未发起模型请求。

## 邮件回复：礼貌但不模板化

- ID：mail-en-reply
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Mail|com.apple.mail|emailReply|normal_input|dictionary_terms_3

输入：
```text
你帮我回一下，大概意思是谢谢他的更新，我们这边这周会先完成内部测试，如果没有严重问题，下周一可以给他一个可以试用的版本。
```

Prompt 片段：
```text
输出语言模式：
Please output the final text in natural American English. If the source is Chinese or mixed Chinese-English, translate and rewrite it so it sounds like something a fluent native speaker would actually post in a Reddit comment, YouTube reply, or Twitter/X conversation.
Avoid literal, stiff, textbook, corporate, or obviously translated phrasing. Use contractions and idiomatic wording when they fit, but do not force slang, memes, emojis, jokes, or attitude that the user did not imply.
Preserve the user's meaning, tone, and level of certainty. Keep proper nouns, code terms, product names, and intentional mixed-language terms when appropriate. Prefer natural paragraphs by default; use numbered points only for actual task lists, steps, comparisons, or explicit requests for structured output.

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Mail
- 应用类型倾向：邮件或正式回复：表达要礼貌、清楚、有分寸，但不要写成模板化公文。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Message body
- 输入框已有内容片段：
Hi, just checking when we might be able to try the new build.
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
你帮我回一下，大概意思是谢谢他的更新，我们这边这周会先完成内部测试，如果没有严重问题，下周一可以给他一个可以试用的版本。
```

结果：dry-run 未发起模型请求。

## 中文邮件：简单回复不编号

- ID：mail-zh-natural
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Mail|com.apple.mail|emailReply|normal_input|dictionary_terms_3

输入：
```text
帮我回复一下，就说我看到了这封邮件，今天晚点会把材料整理好发给他，如果他那边有特别需要提前看的部分，也可以先告诉我。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Mail
- 应用类型倾向：邮件或正式回复：表达要礼貌、清楚、有分寸，但不要写成模板化公文。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Message body
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
帮我回复一下，就说我看到了这封邮件，今天晚点会把材料整理好发给他，如果他那边有特别需要提前看的部分，也可以先告诉我。
```

结果：dry-run 未发起模型请求。

## 划词指令：翻译选中文本

- ID：selected-translate
- 操作：selected_text_command
- 输出语言：simplifiedChinese
- 风格：general
- 上下文：Safari|com.apple.Safari|general|selected_text|dictionary_terms_3

输入：
```text
选中文本：Voice input only feels magical when it is fast, reliable, and context-aware.
语音指令：翻译成中文，稍微自然一点
```

Prompt 片段：
```text
你正在处理用户选中的文本。用户会先选中一段文字，再用语音说出一个指令，例如“翻译”“总结”“解释一下”“改写得更自然”。

处理规则：
1. 以“用户语音指令”为最高优先级，基于“用户选中的文本”完成任务。
2. 如果用户只说“翻译”，请把选中文本翻译成当前输出语言；如果输出语言与原文相同且目标语言不明确，请翻译成另一种最自然的语言。
3. 如果用户要求总结、解释、改写、润色、提炼要点或生成回复，请只基于选中文本和用户指令处理，不要新增事实。
4. 只输出最终结果，不要解释你如何判断，也不要复述“已选中文本”或“根据你的指令”。

输出语言：
请优先用简体中文输出结果；必要时可以保留原文中的英文术语、代码、品牌名、产品名和专有名词。

输出风格：
使用通用风格：清晰、自然、少加工，适合大多数输入。把口语整理成通顺、有条理、可直接发送的文字；不要过度正式，也不要刻意幽默。

当前上下文：
- 应用：Safari
- 应用类型倾向：通用输入：保持清晰、自然、少加工，优先让文字可直接发送。
- 交互模式：选中文本 + 语音指令
- 焦点控件：AXWebArea
- 焦点说明：Article body
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

用户选中的文本：
Voice input only feels magical when it is fast, reliable, and context-aware.

用户语音指令：
翻译成中文，稍微自然一点
```

结果：dry-run 未发起模型请求。

## 划词指令：总结选中文本

- ID：selected-summarize
- 操作：selected_text_command
- 输出语言：simplifiedChinese
- 风格：general
- 上下文：Safari|com.apple.Safari|general|selected_text|dictionary_terms_3

输入：
```text
选中文本：The main issue is not whether the tool has a long feature list. The real question is whether users can trust it to work every single time they need it.
语音指令：总结成一句中文
```

Prompt 片段：
```text
你正在处理用户选中的文本。用户会先选中一段文字，再用语音说出一个指令，例如“翻译”“总结”“解释一下”“改写得更自然”。

处理规则：
1. 以“用户语音指令”为最高优先级，基于“用户选中的文本”完成任务。
2. 如果用户只说“翻译”，请把选中文本翻译成当前输出语言；如果输出语言与原文相同且目标语言不明确，请翻译成另一种最自然的语言。
3. 如果用户要求总结、解释、改写、润色、提炼要点或生成回复，请只基于选中文本和用户指令处理，不要新增事实。
4. 只输出最终结果，不要解释你如何判断，也不要复述“已选中文本”或“根据你的指令”。

输出语言：
请优先用简体中文输出结果；必要时可以保留原文中的英文术语、代码、品牌名、产品名和专有名词。

输出风格：
使用通用风格：清晰、自然、少加工，适合大多数输入。把口语整理成通顺、有条理、可直接发送的文字；不要过度正式，也不要刻意幽默。

当前上下文：
- 应用：Safari
- 应用类型倾向：通用输入：保持清晰、自然、少加工，优先让文字可直接发送。
- 交互模式：选中文本 + 语音指令
- 焦点控件：AXWebArea
- 焦点说明：Article body
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

用户选中的文本：
The main issue is not whether the tool has a long feature list. The real question is whether users can trust it to work every single time they need it.

用户语音指令：
总结成一句中文
```

结果：dry-run 未发起模型请求。

## 创意发散：不能乱出 Markdown 符号

- ID：creative-no-markdown
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：creativeWild
- 上下文：X|com.apple.Safari|socialConversation|normal_input|dictionary_terms_3

输入：
```text
帮我把这句话说得更有冲击力一点，意思是语音输入最怕的不是识别错一次，而是用户说完之后发现它没有任何反馈，那种感觉特别伤信任。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
使用创意发散风格：允许更大胆地重组句子、增强表达张力、加入更鲜明的语气，让文字更有个性、更抓人、更不普通。可以脑洞更大、变化更大，但不能新增事实、不能改变核心意图，也不要写成尴尬段子。即使风格更强，也必须输出普通纯文本，禁止用 **、#、反引号、引用块等 Markdown 符号来制造强调。

当前上下文：
- 应用：X
- 应用类型倾向：社交评论或公开回复：表达要像真人自然发言，避免翻译腔、营销腔和过度正式。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Post composer
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
帮我把这句话说得更有冲击力一点，意思是语音输入最怕的不是识别错一次，而是用户说完之后发现它没有任何反馈，那种感觉特别伤信任。
```

结果：dry-run 未发起模型请求。

## 明确要求结构化：应该编号

- ID：explicit-structured
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
帮我整理成三点，第一是现在网络不通所以真实模型测试跑不了，第二是上下文已经确认进入 prompt，第三是我们要继续收集样本。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

输出风格：
自动判断风格：根据原始语义在通用、严谨专业、轻松有趣、创意发散四类中选择最合适的文风，但不要说明你的判断过程。判断不明显时必须落在通用风格；只有明显需要正式、准确、工作化表达时才使用严谨专业；明显是日常回复、轻量评论或对话时可使用轻松有趣；只有用户明显在吐槽、表达强观点或希望内容更抓人时，才谨慎使用创意发散。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：优先整理成目标、约束、步骤、问题和期望结果，表达要直接、可执行。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
帮我整理成三点，第一是现在网络不通所以真实模型测试跑不了，第二是上下文已经确认进入 prompt，第三是我们要继续收集样本。
```

结果：dry-run 未发起模型请求。

