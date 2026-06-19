# NexVoice DeepSeek 上下文评测

- 模式：dry-run，仅检查 prompt
- 场景数：15

## Agent 协作：中文结构化需求

- ID：agent-zh-structure
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：faithful
- Temperature：0.05
- Timeout：10s
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我们现在先别急着做界面，先帮我判断一下这个需求有没有问题，然后如果没有问题你就直接改，第一点是要低延迟，第二点是要保留 loading 状态，第三点是如果没有输入框就复制到剪贴板，嗯大概是这样。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户同时包含提问、请求或操作指令。整理时分别保留这些语义动作的关系：问题仍是问题，请求仍是请求，指令仍是指令。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
- 输入框已有内容片段（仅供判断上下文，不要复述、改写、续写或合并进最终输出）：
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
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我刚才想了一下，这个事情可能不要做得太复杂，重点还是先保证它每次都能稳定写进去，不然用户会觉得不可信，然后后面再慢慢加那些更高级的功能。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在陈述想法。整理后保持原本的判断、犹豫和语气强弱，不要改写成命令或问题。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
- 输入框已有内容片段（仅供判断上下文，不要复述、改写、续写或合并进最终输出）：
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

## Agent 协作：问题不能改成命令

- ID：agent-question-preserve
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我想问一下，这个需求是不是本身有问题，我们是不是应该先判断一下再决定要不要改？
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在提问或表达疑问。整理后仍应保留疑问语气，不要改写成命令、结论或替用户下判断。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我想问一下，这个需求是不是本身有问题，我们是不是应该先判断一下再决定要不要改？
```

结果：dry-run 未发起模型请求。

## 真实 ASR：混乱需求仍需忠实整理

- ID：real-asr-messy-agent-request
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：faithful
- Temperature：0.05
- Timeout：10s
- 上下文：Codex|com.openai.codex|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
有两个问题啊，我觉得你都要去解决一下。第一个问题就是你给的测试的输入其实太标准了，虽然说你现在是。是有很多模拟了呃正常的。就是人的表达，但是其实还不够自由，不够，不够，没有不够，呃，怎么说呢？不够，没有逻辑啊。你需要。在。更加。没有逻辑性，就像我去跟你说话一样，没有逻辑。然后。嗯，还有一点，还有一点就是关于。呃，关于。现在的输出。现在的输出结果，我觉得有的时...
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户同时包含提问、请求或操作指令。整理时分别保留这些语义动作的关系：问题仍是问题，请求仍是请求，指令仍是指令。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Codex
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
有两个问题啊，我觉得你都要去解决一下。第一个问题就是你给的测试的输入其实太标准了，虽然说你现在是。是有很多模拟了呃正常的。就是人的表达，但是其实还不够自由，不够，不够，没有不够，呃，怎么说呢？不够，没有逻辑啊。你需要。在。更加。没有逻辑性，就像我去跟你说话一样，没有逻辑。然后。嗯，还有一点，还有一点就是关于。呃，关于。现在的输出。现在的输出结果，我觉得有的时...
```

结果：dry-run 未发起模型请求。

## 真实 ASR：中途改口的评测要求

- ID：real-asr-messy-eval-request
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：faithful
- Temperature：0.05
- Timeout：10s
- 上下文：Codex|com.openai.codex|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
我又做了一次测评，你再帮我看一下，这次不仅是看刚才已有的问题，而且你还要看。呃，或者你直接列出来给我，就是你所给的。呃，你所给的内容和。AI转写出来的。列出来给我看一下，我是不符是否符合我的预期。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户同时包含提问、请求或操作指令。整理时分别保留这些语义动作的关系：问题仍是问题，请求仍是请求，指令仍是指令。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Codex
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Agent 输入框
用户个人词库：
- NexVoice：macOS 语音输入产品名
- DeepSeek：AI 整理模型
- Codex：AI 编程 Agent

处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。

原始语音转写：
我又做了一次测评，你再帮我看一下，这次不仅是看刚才已有的问题，而且你还要看。呃，或者你直接列出来给我，就是你所给的。呃，你所给的内容和。AI转写出来的。列出来给我看一下，我是不符是否符合我的预期。
```

结果：dry-run 未发起模型请求。

## 即时沟通：普通聊天保持自然段

- ID：chat-zh-natural
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
- 上下文：Slack|com.tinyspeck.slackmacgap|workChat|normal_input|dictionary_terms_3

输入：
```text
我今天可能会晚一点到，你们先开始不用等我，我到的时候再看一下前面的讨论记录，然后有问题我再补充。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在下达操作指令。整理后可以更清楚、更可执行，但不要额外添加原文没有的目标或判断。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

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
- 输出模式：natural
- Temperature：0.25
- Timeout：9s
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
Do not soften frequency, severity, or causal force. If the source says something happens every time, fails once and trust is lost, or fails again and again, do not translate it as "once in a while", "occasionally", or any weaker frequency.

本次语义动作：
用户主要是在提出请求。整理后应保留请求语气和协作关系，不要改写成已经确定的结论或强硬命令。

输出模式：
使用自然表达模式：让文本更像真人自然写出来。中文要顺滑自然，英文要偏自然美式表达，避免翻译腔、教材腔和营销腔。可以替换生硬措辞，但不能改变核心意思、语气、立场、频率和严重程度；不要强行加梗、表情或额外态度。

当前上下文：
- 应用：Google Chrome
- 应用类型倾向：社交评论或公开回复：表达要像真人自然发言，避免翻译腔、营销腔和过度正式。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Reddit comment box
- 输入框已有内容片段（仅供判断上下文，不要复述、改写、续写或合并进最终输出）：
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
- 输出模式：natural
- Temperature：0.25
- Timeout：9s
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
Do not soften frequency, severity, or causal force. If the source says something happens every time, fails once and trust is lost, or fails again and again, do not translate it as "once in a while", "occasionally", or any weaker frequency.

本次语义动作：
用户主要是在提问或表达疑问。整理后仍应保留疑问语气，不要改写成命令、结论或替用户下判断。

输出模式：
使用自然表达模式：让文本更像真人自然写出来。中文要顺滑自然，英文要偏自然美式表达，避免翻译腔、教材腔和营销腔。可以替换生硬措辞，但不能改变核心意思、语气、立场、频率和严重程度；不要强行加梗、表情或额外态度。

当前上下文：
- 应用：Google Chrome
- 应用类型倾向：社交评论或公开回复：表达要像真人自然发言，避免翻译腔、营销腔和过度正式。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：YouTube reply box
- 输入框已有内容片段（仅供判断上下文，不要复述、改写、续写或合并进最终输出）：
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
- 输出模式：professional
- Temperature：0.2
- Timeout：9s
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
Do not soften frequency, severity, or causal force. If the source says something happens every time, fails once and trust is lost, or fails again and again, do not translate it as "once in a while", "occasionally", or any weaker frequency.

本次语义动作：
用户主要是在提出请求。整理后应保留请求语气和协作关系，不要改写成已经确定的结论或强硬命令。

输出模式：
使用专业严谨模式：表达要准确、克制、可靠，适合需求说明、技术判断、正式邮件和文档。可以减少口语感并理顺逻辑，但不要写成官腔、公文腔或过度客套；不能新增事实或改变结论。

当前上下文：
- 应用：Mail
- 应用类型倾向：邮件或正式回复：表达要礼貌、清楚、有分寸，但不要写成模板化公文。
- 交互模式：普通语音输入
- 焦点控件：AXTextArea
- 焦点说明：Message body
- 输入框已有内容片段（仅供判断上下文，不要复述、改写、续写或合并进最终输出）：
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
- 输出模式：clear
- Temperature：0.15
- Timeout：9s
- 上下文：Mail|com.apple.mail|emailReply|normal_input|dictionary_terms_3

输入：
```text
帮我回复一下，就说我看到了这封邮件，今天晚点会把材料整理好发给他，如果他那边有特别需要提前看的部分，也可以先告诉我。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在提出请求。整理后应保留请求语气和协作关系，不要改写成已经确定的结论或强硬命令。

输出模式：
使用清晰优化模式：在忠于原意的基础上，让表达更顺、更清楚。可以适度合并重复内容、调整句序、补足必要连接词，但不能改变用户立场、态度、强弱和事实范围。适合工作沟通、邮件和较正式说明。

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
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
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

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

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
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
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

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

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

## 增强表达：观点更有力度但不变味

- ID：expressive-zh-opinion
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：expressive
- Temperature：0.45
- Timeout：9s
- 上下文：X|com.apple.Safari|socialConversation|normal_input|dictionary_terms_3

输入：
```text
我想说这个功能现在最重要的不是看起来多聪明，而是它在关键时候别掉链子，只要它掉链子一次，用户后面就会开始怀疑它。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在陈述想法。整理后保持原本的判断、犹豫和语气强弱，不要改写成命令或问题。

输出模式：
使用增强表达模式：在不新增事实、不改变立场的前提下，让观点更有力度、更有节奏、更容易被读懂。可以强化表达重点和句子节奏，但不要写成口号，不要使用羞辱性、冒犯性、死亡、暴力或粗俗比喻，不要把语气推到用户没有表达的程度。

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
我想说这个功能现在最重要的不是看起来多聪明，而是它在关键时候别掉链子，只要它掉链子一次，用户后面就会开始怀疑它。
```

结果：dry-run 未发起模型请求。

## 疯狂模式：更猛但不能乱出 Markdown 符号

- ID：creative-no-markdown
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 输出模式：creativeWild
- Temperature：0.85
- Timeout：8s
- 上下文：X|com.apple.Safari|socialConversation|normal_input|dictionary_terms_3

输入：
```text
帮我把这句话说得更有冲击力一点，意思是语音输入最怕的不是识别错一次，而是用户说完之后发现它没有任何反馈，那种感觉特别伤信任。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在提出请求。整理后应保留请求语气和协作关系，不要改写成已经确定的结论或强硬命令。

输出模式：
使用疯狂模式：这是最高改写幅度，只在用户手动选择时使用。允许明显放大表达张力、重组句子、制造更强的节奏和记忆点，让文字更锋利、更有画面感、更抓人；可以使用大胆比喻和更强情绪，但仍然不能新增事实、不能改变核心立场，不能做人身攻击、低俗辱骂、仇恨表达或无关猎奇。即使风格更强，也必须输出普通纯文本，禁止用 **、#、反引号、引用块等 Markdown 符号来制造强调。

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
- 输出模式：faithful
- Temperature：0.05
- Timeout：9s
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3

输入：
```text
帮我整理成三点，第一是现在网络不通所以真实模型测试跑不了，第二是上下文已经确认进入 prompt，第三是我们要继续收集样本。
```

Prompt 片段：
```text
输出语言模式：
请输出简体中文为主的最终文本；原文里的英文术语、代码、品牌名、产品名或自然的中英混合表达可以保留。默认用自然段表达，只有确实是任务清单、步骤、方案对比或用户明确要求结构化时才编号。

本次语义动作：
用户主要是在提出请求。整理后应保留请求语气和协作关系，不要改写成已经确定的结论或强硬命令。

输出模式：
使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。

当前上下文：
- 应用：Cursor
- 应用类型倾向：AI Agent 或开发工具协作：保留用户是在提问、请求判断、下达任务还是补充约束；只在原文确实是任务清单时整理成目标、约束、步骤和期望结果。
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
