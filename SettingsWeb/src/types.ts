export type SettingsTab = "input" | "modes" | "workflow" | "dictionary" | "permissions";
export type OutputLanguage = "simplifiedChinese" | "english";
export type RewriteStyle = "standard" | "socialExpert" | "amplifiedSpokesperson" | "calm";
export type DictionaryFilter = "all" | "automatic" | "manual";

export type ModeMetric = {
  label: string;
  value: number;
};

export type RewriteMode = {
  id: RewriteStyle;
  title: string;
  description: string;
  metrics: ModeMetric[];
};

export type WorkflowOption = {
  id: string;
  title: string;
  promptHint: string;
  sources: string;
  status: string;
  mode: RewriteStyle;
};

export type DictionaryTerm = {
  phrase: string;
  weight: number;
  scene: string;
  source: "automatic" | "manual";
};

export type PermissionItem = {
  id: "microphone" | "accessibility" | "screenRecording";
  title: string;
  detail: string;
  allowed: boolean;
  status: string;
};

export type SettingsState = {
  selectedTab: SettingsTab;
  versionText: string;
  shortcut: {
    title: string;
    recording: boolean;
  };
  outputLanguage: OutputLanguage;
  rewriteStyle: RewriteStyle;
  modes: RewriteMode[];
  workflows: WorkflowOption[];
  selectedWorkflow: string;
  currentAppName: string;
  dictionaryFilter: DictionaryFilter;
  dictionaryTerms: DictionaryTerm[];
  permissions: PermissionItem[];
};

export type BridgeMessage =
  | { type: "ready" }
  | { type: "selectTab"; tab: SettingsTab }
  | { type: "beginShortcutRecording" }
  | { type: "cancelShortcutRecording" }
  | { type: "resetShortcut" }
  | { type: "setOutputLanguage"; language: OutputLanguage }
  | { type: "setRewriteStyle"; style: RewriteStyle }
  | { type: "setWorkflow"; workflow: string }
  | { type: "setWorkflowMode"; workflow: string; style: RewriteStyle }
  | { type: "setDictionaryFilter"; filter: DictionaryFilter }
  | { type: "addDictionaryTerm"; phrase: string }
  | { type: "deleteDictionaryTerm"; phrase: string }
  | { type: "requestPermission"; permission: PermissionItem["id"] }
  | { type: "refresh" };

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        settings?: {
          postMessage: (message: BridgeMessage) => void;
        };
      };
    };
    NexVoiceSettings?: {
      receiveState: (state: SettingsState) => void;
    };
  }
}
