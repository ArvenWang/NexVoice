import type { BridgeMessage, SettingsState } from "./types";

export const demoState: SettingsState = {
  selectedTab: "input",
  versionText: "0.1.9 (10)",
  shortcutCommand: {
    title: "快速翻译",
    value: "quick-translate"
  },
  shortcut: { title: "右 Alt", recording: false },
  outputLanguage: "simplifiedChinese",
  rewriteStyle: "standard",
  modes: [
    {
      id: "standard",
      title: "标准模式",
      description: "修正吞字、断词、重复和口头禅，让表达自然清晰；严格贴合原意。",
      metrics: [
        { label: "原意", value: 95 },
        { label: "情绪", value: 30 },
        { label: "发散", value: 10 }
      ]
    },
    {
      id: "socialExpert",
      title: "社交达人",
      description: "更适合聊天、评论和社交媒体；表达轻松，有网感。",
      metrics: [
        { label: "原意", value: 78 },
        { label: "情绪", value: 58 },
        { label: "发散", value: 42 }
      ]
    },
    {
      id: "amplifiedSpokesperson",
      title: "强化嘴替",
      description: "放大原本情绪和态度，表达更锋利、更有冲击力。",
      metrics: [
        { label: "原意", value: 62 },
        { label: "情绪", value: 96 },
        { label: "发散", value: 76 }
      ]
    },
    {
      id: "calm",
      title: "冷静模式",
      description: "压低攻击性和混乱表达，用更少的字保留核心诉求。",
      metrics: [
        { label: "原意", value: 88 },
        { label: "情绪", value: 18 },
        { label: "发散", value: 14 }
      ]
    }
  ],
  workflows: [
    {
      id: "agent-collaboration",
      title: "开发协作",
      promptHint: "保留用户的任务、约束、判断和问题边界；不要把需求改成泛泛建议。",
      sources: "Codex, Cursor, Xcode, VS Code, ChatGPT, Claude, Windsurf。",
      status: "已识别",
      mode: "standard"
    },
    {
      id: "email-reply",
      title: "邮件回复",
      promptHint: "表达礼貌清楚、有分寸；必要称呼和收尾要克制。",
      sources: "Mail, Outlook, Spark, Airmail, Gmail。",
      status: "未命中",
      mode: "calm"
    },
    {
      id: "social",
      title: "社交发布",
      promptHint: "像真人自然发言，避免翻译腔和过度正式；允许更强网感。",
      sources: "X, Reddit, YouTube, Threads, 评论框。",
      status: "未命中",
      mode: "socialExpert"
    },
    {
      id: "work-chat",
      title: "即时沟通",
      promptHint: "简洁自然，行动明确，少铺垫；不要扩写成正式文档。",
      sources: "Slack, Discord, Telegram, WeChat, Lark, 飞书。",
      status: "未命中",
      mode: "standard"
    },
    {
      id: "general",
      title: "通用输入",
      promptHint: "清晰自然，少加工，可直接发送。",
      sources: "没有命中其他工作流时使用。",
      status: "未命中",
      mode: "standard"
    }
  ],
  selectedWorkflow: "agent-collaboration",
  currentAppName: "Codex",
  dictionaryFilter: "all",
  dictionaryTerms: [
    { phrase: "Typeless", weight: 8, scene: "Codex", source: "automatic" },
    { phrase: "HTML", weight: 8, scene: "开发协作", source: "automatic" },
    { phrase: "NexHub", weight: 10, scene: "全局", source: "manual" }
  ],
  permissions: [
    { id: "microphone", title: "麦克风", detail: "用于录音和语音指令识别。", allowed: true, status: "已允许" },
    { id: "accessibility", title: "辅助功能", detail: "把最终文本写入当前输入框。", allowed: true, status: "已允许" },
    { id: "screenRecording", title: "屏幕录制", detail: "看屏回复只读取当前屏幕可见内容。", allowed: true, status: "已允许" }
  ]
};

export function postToNative(message: BridgeMessage) {
  const handler = window.webkit?.messageHandlers?.settings;
  if (handler) {
    handler.postMessage(message);
    return;
  }
  window.dispatchEvent(new CustomEvent("nexvoice-demo-message", { detail: message }));
}
