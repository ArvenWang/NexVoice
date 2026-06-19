# NexVoice DeepSeek 上下文评测

- 模式：真实请求 DeepSeek
- 场景数：11

## Agent 协作：中文结构化需求

- ID：agent-zh-structure
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3
- 耗时：12 ms

输入：
```text
我们现在先别急着做界面，先帮我判断一下这个需求有没有问题，然后如果没有问题你就直接改，第一点是要低延迟，第二点是要保留 loading 状态，第三点是如果没有输入框就复制到剪贴板，嗯大概是这样。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## Agent 协作：连续想法不强行结构化

- ID：agent-zh-natural-no-list
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3
- 耗时：1 ms

输入：
```text
我刚才想了一下，这个事情可能不要做得太复杂，重点还是先保证它每次都能稳定写进去，不然用户会觉得不可信，然后后面再慢慢加那些更高级的功能。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 即时沟通：普通聊天保持自然段

- ID：chat-zh-natural
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Slack|com.tinyspeck.slackmacgap|workChat|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
我今天可能会晚一点到，你们先开始不用等我，我到的时候再看一下前面的讨论记录，然后有问题我再补充。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 海外社交：中文口述转自然英文评论

- ID：social-en-natural
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Google Chrome|com.google.Chrome|socialConversation|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
我想回复他说，我同意这个方向，但是这个东西最大的问题不是功能多少，而是它每一次都能不能稳定工作，如果输入一次失败一次，用户很快就不会再信任它了。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 海外社交：单个观点不编号

- ID：social-en-no-list
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Google Chrome|com.google.Chrome|socialConversation|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
我想说这个产品最吸引我的地方不是它功能多，而是它让我不用切换上下文，想到什么就可以直接说出来，这个感觉很重要。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 邮件回复：礼貌但不模板化

- ID：mail-en-reply
- 操作：final_rewrite
- 输出语言：english
- 风格：automatic
- 上下文：Mail|com.apple.mail|emailReply|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
你帮我回一下，大概意思是谢谢他的更新，我们这边这周会先完成内部测试，如果没有严重问题，下周一可以给他一个可以试用的版本。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 中文邮件：简单回复不编号

- ID：mail-zh-natural
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Mail|com.apple.mail|emailReply|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
帮我回复一下，就说我看到了这封邮件，今天晚点会把材料整理好发给他，如果他那边有特别需要提前看的部分，也可以先告诉我。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 划词指令：翻译选中文本

- ID：selected-translate
- 操作：selected_text_command
- 输出语言：simplifiedChinese
- 风格：general
- 上下文：Safari|com.apple.Safari|general|selected_text|dictionary_terms_3
- 耗时：0 ms

输入：
```text
选中文本：Voice input only feels magical when it is fast, reliable, and context-aware.
语音指令：翻译成中文，稍微自然一点
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 划词指令：总结选中文本

- ID：selected-summarize
- 操作：selected_text_command
- 输出语言：simplifiedChinese
- 风格：general
- 上下文：Safari|com.apple.Safari|general|selected_text|dictionary_terms_3
- 耗时：0 ms

输入：
```text
选中文本：The main issue is not whether the tool has a long feature list. The real question is whether users can trust it to work every single time they need it.
语音指令：总结成一句中文
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 创意发散：不能乱出 Markdown 符号

- ID：creative-no-markdown
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：creativeWild
- 上下文：X|com.apple.Safari|socialConversation|normal_input|dictionary_terms_3
- 耗时：0 ms

输入：
```text
帮我把这句话说得更有冲击力一点，意思是语音输入最怕的不是识别错一次，而是用户说完之后发现它没有任何反馈，那种感觉特别伤信任。
```

结果：失败
```text
A server with the specified hostname could not be found.
```

## 明确要求结构化：应该编号

- ID：explicit-structured
- 操作：final_rewrite
- 输出语言：simplifiedChinese
- 风格：automatic
- 上下文：Cursor|com.todesktop.230313mzl4w4u92|agentCollaboration|normal_input|dictionary_terms_3
- 耗时：1 ms

输入：
```text
帮我整理成三点，第一是现在网络不通所以真实模型测试跑不了，第二是上下文已经确认进入 prompt，第三是我们要继续收集样本。
```

结果：失败
```text
A server with the specified hostname could not be found.
```
