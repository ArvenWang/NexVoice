import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { demoState, postToNative } from "./bridge";
import type {
  DictionaryFilter,
  DictionaryTerm,
  PermissionItem,
  RewriteStyle,
  SettingsState,
  SettingsTab,
  WorkflowOption
} from "./types";
import "./styles.css";

const navItems: Array<{ id: SettingsTab; title: string; icon: string }> = [
  { id: "input", title: "输入", icon: "⌘" },
  { id: "modes", title: "输出模式", icon: "✦" },
  { id: "workflow", title: "工作流", icon: "◇" },
  { id: "dictionary", title: "词库", icon: "▦" },
  { id: "permissions", title: "权限", icon: "●" }
];

const styleTitles: Record<RewriteStyle, string> = {
  standard: "标准模式",
  socialExpert: "社交达人",
  amplifiedSpokesperson: "强化嘴替",
  calm: "冷静模式"
};

function App() {
  const [state, setState] = useState<SettingsState>(demoState);
  const [termDraft, setTermDraft] = useState("");
  const [showAddTerm, setShowAddTerm] = useState(false);
  const closeAddTerm = () => {
    setShowAddTerm(false);
    setTermDraft("");
  };

  useEffect(() => {
    window.NexVoiceSettings = {
      receiveState(nextState) {
        setState(nextState);
      }
    };

    const demoHandler = (event: Event) => {
      const message = (event as CustomEvent).detail;
      setState((current) => applyDemoMessage(current, message));
      if (message.type === "addDictionaryTerm" || message.type === "deleteDictionaryTerm") {
        setShowAddTerm(false);
        setTermDraft("");
      }
    };
    window.addEventListener("nexvoice-demo-message", demoHandler);
    postToNative({ type: "ready" });
    return () => window.removeEventListener("nexvoice-demo-message", demoHandler);
  }, []);

  const activeWorkflow = useMemo(
    () => state.workflows.find((item) => item.id === state.selectedWorkflow) ?? state.workflows[0],
    [state.selectedWorkflow, state.workflows]
  );

  const filteredTerms = useMemo(
    () => filterTerms(state.dictionaryTerms, state.dictionaryFilter),
    [state.dictionaryTerms, state.dictionaryFilter]
  );

  const selectTab = (tab: SettingsTab) => postToNative({ type: "selectTab", tab });

  return (
    <main className="settings-shell">
      <aside className="sidebar">
        <div className="brand">NexVoice</div>
        <nav className="nav" aria-label="设置导航">
          {navItems.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`nav-item ${state.selectedTab === item.id ? "active" : ""}`}
              onClick={() => selectTab(item.id)}
            >
              <span className="nav-icon">{item.icon}</span>
              <span>{item.title}</span>
            </button>
          ))}
        </nav>
        <section className="build-card">
          <strong>本地测试版本</strong>
          <p>API 配置已嵌入，仅用于当前私用构建。</p>
          <b>{state.versionText}</b>
        </section>
      </aside>

      <section className="content">
        {state.selectedTab === "input" && <InputPage state={state} />}
        {state.selectedTab === "modes" && <ModesPage state={state} />}
        {state.selectedTab === "workflow" && activeWorkflow && <WorkflowPage state={state} workflow={activeWorkflow} />}
        {state.selectedTab === "dictionary" && (
          <DictionaryPage
            state={state}
            terms={filteredTerms}
            onShowAddTerm={() => setShowAddTerm(true)}
          />
        )}
        {state.selectedTab === "permissions" && <PermissionsPage permissions={state.permissions} />}
      </section>

      {showAddTerm && (
        <AddTermDialog
          value={termDraft}
          onChange={setTermDraft}
          onCancel={closeAddTerm}
          onSubmit={() => {
            const phrase = termDraft.trim();
            if (!phrase) return;
            postToNative({ type: "addDictionaryTerm", phrase });
            closeAddTerm();
          }}
        />
      )}
    </main>
  );
}

function InputPage({ state }: { state: SettingsState }) {
  return (
    <div className="page">
      <h1>输入设置</h1>
      <section className="card">
        <div className="card-row interactive-row">
          <div>
            <h2>快捷键</h2>
            <p>短按开始语音输入，长按进入看屏回复。</p>
          </div>
          <div className={`key-field ${state.shortcut.recording ? "recording" : ""}`}>
            {state.shortcut.recording ? "按下新快捷键" : state.shortcut.title}
          </div>
        </div>
        <div className="card-row interactive-row">
          <div>
            <h2>快捷键操作</h2>
            <p>重新录制快捷键，或恢复默认右 Alt。</p>
          </div>
          <div className="button-row">
            <button className="btn primary compact" type="button" onClick={() => postToNative({ type: "beginShortcutRecording" })}>
              录制
            </button>
            <button className="btn compact" type="button" onClick={() => postToNative({ type: "resetShortcut" })}>
              恢复
            </button>
          </div>
        </div>
        <div className="card-row interactive-row">
          <div>
            <h2>输出语言</h2>
            <p>用于语音输入、选中文本指令和看屏回复。</p>
          </div>
          <div className="segmented compact-segmented">
            <button
              type="button"
              className={state.outputLanguage === "simplifiedChinese" ? "active" : ""}
              onClick={() => postToNative({ type: "setOutputLanguage", language: "simplifiedChinese" })}
            >
              中文
            </button>
            <button
              type="button"
              className={state.outputLanguage === "english" ? "active" : ""}
              onClick={() => postToNative({ type: "setOutputLanguage", language: "english" })}
            >
              English
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}

function ModesPage({ state }: { state: SettingsState }) {
  return (
    <div className="page">
      <h1>输出模式</h1>
      <div className="mode-grid">
        {state.modes.map((mode) => {
          const active = state.rewriteStyle === mode.id;
          return (
            <button
              key={mode.id}
              type="button"
              className={`mode-card ${active ? "active" : ""}`}
              onClick={() => postToNative({ type: "setRewriteStyle", style: mode.id })}
            >
              <h2>{mode.title}</h2>
              <p>{mode.description}</p>
              <div className="metric-list">
                {mode.metrics.map((metric) => (
                  <div className="metric" key={metric.label}>
                    <span>{metric.label}</span>
                    <i>
                      <b style={{ width: active ? `${metric.value}%` : `${metric.value}%` }} />
                    </i>
                    <strong>{metric.value}</strong>
                  </div>
                ))}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function WorkflowPage({ state, workflow }: { state: SettingsState; workflow: WorkflowOption }) {
  const [isModeMenuOpen, setIsModeMenuOpen] = useState(false);
  const selectedModeTitle = styleTitles[workflow.mode];

  return (
    <div className="page">
      <h1>工作流</h1>
      <div className="segmented full-tabs workflow-tabs">
        {state.workflows.map((item) => (
          <button
            key={item.id}
            type="button"
            className={state.selectedWorkflow === item.id ? "active" : ""}
            onClick={() => postToNative({ type: "setWorkflow", workflow: item.id })}
          >
            {item.title}
          </button>
        ))}
      </div>
      <section className="card">
        <div className="card-row interactive-row">
          <div>
            <h2>当前应用</h2>
            <p>打开设置时读取前台应用和焦点输入框。</p>
          </div>
          <strong className="value-text">{state.currentAppName}</strong>
        </div>
        <div className="card-row interactive-row">
          <div>
            <h2>识别场景</h2>
            <p>根据当前应用判断你更像在写哪类内容。</p>
          </div>
          <strong className="value-text">{workflow.title}</strong>
        </div>
        <div className="card-row interactive-row">
          <div>
            <h2>输出模式</h2>
            <p>可为当前工作流指定默认改写风格。</p>
          </div>
          <div className="custom-select">
            <button
              type="button"
              className={`select-trigger ${isModeMenuOpen ? "open" : ""}`}
              onClick={() => setIsModeMenuOpen((open) => !open)}
            >
              <span>{selectedModeTitle}</span>
              <i />
            </button>
            {isModeMenuOpen && (
              <div className="select-menu" role="listbox">
                {state.modes.map((mode) => (
                  <button
                    key={mode.id}
                    type="button"
                    className={workflow.mode === mode.id ? "active" : ""}
                    onClick={() => {
                      postToNative({ type: "setWorkflowMode", workflow: workflow.id, style: mode.id });
                      setIsModeMenuOpen(false);
                    }}
                  >
                    <span>{styleTitles[mode.id]}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
        <div className="card-row interactive-row">
          <div>
            <h2>工作流规则</h2>
            <p>{workflow.promptHint}</p>
          </div>
          <strong className="status-text">{workflow.status}</strong>
        </div>
      </section>
    </div>
  );
}

function DictionaryPage({
  state,
  terms,
  onShowAddTerm
}: {
  state: SettingsState;
  terms: DictionaryTerm[];
  onShowAddTerm: () => void;
}) {
  return (
    <div className="page">
      <h1>个人词库</h1>
      <section className="dictionary-panel">
        <div className="dictionary-controls">
          <div className="segmented full-tabs dictionary-tabs">
            {(["all", "automatic", "manual"] as DictionaryFilter[]).map((filter) => (
              <button
                key={filter}
                type="button"
                className={state.dictionaryFilter === filter ? "active" : ""}
                onClick={() => postToNative({ type: "setDictionaryFilter", filter })}
              >
                {dictionaryFilterTitle(filter)}
              </button>
            ))}
          </div>
          <button className="btn primary add-term-button" type="button" onClick={onShowAddTerm}>
            添加词条
          </button>
        </div>
        <div className="dictionary-list">
          {terms.length === 0 ? (
            <div className="empty">暂无词条</div>
          ) : (
            terms.map((term) => (
              <div className="dictionary-entry" key={`${term.source}-${term.phrase}`}>
                <strong>{term.phrase}</strong>
                <span>权重 <b>{term.weight}</b></span>
                <span>场景 <b>{term.scene}</b></span>
                <button
                  type="button"
                  className="ghost-action"
                  onClick={() => postToNative({ type: "deleteDictionaryTerm", phrase: term.phrase })}
                >
                  删除
                </button>
              </div>
            ))
          )}
        </div>
      </section>
    </div>
  );
}

function PermissionsPage({ permissions }: { permissions: PermissionItem[] }) {
  return (
    <div className="page">
      <h1>权限</h1>
      <section className="card permissions-card">
        {permissions.map((item) => (
          <div className="card-row interactive-row" key={item.id}>
            <div>
              <h2>{item.title}</h2>
              <p>{item.detail}</p>
            </div>
            {item.allowed ? (
              <strong className="status-text">{item.status}</strong>
            ) : (
              <button
                type="button"
                className="btn compact"
                onClick={() => postToNative({ type: "requestPermission", permission: item.id })}
              >
                打开
              </button>
            )}
          </div>
        ))}
      </section>
    </div>
  );
}

function AddTermDialog({
  value,
  onChange,
  onCancel,
  onSubmit
}: {
  value: string;
  onChange: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
}) {
  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={onCancel}>
      <section className="dialog" role="dialog" aria-modal="true" onMouseDown={(event) => event.stopPropagation()}>
        <h2>添加词条</h2>
        <p>只添加专有名词、产品名、项目名或高频术语。</p>
        <input
          autoFocus
          value={value}
          onChange={(event) => onChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Escape") onCancel();
            if (event.key === "Enter") onSubmit();
          }}
          placeholder="输入词条"
        />
        <div className="dialog-actions">
          <button type="button" className="btn" onClick={onCancel}>
            取消
          </button>
          <button type="button" className="btn primary" onClick={onSubmit}>
            添加
          </button>
        </div>
      </section>
    </div>
  );
}

function dictionaryFilterTitle(filter: DictionaryFilter) {
  switch (filter) {
    case "automatic":
      return "自动学习";
    case "manual":
      return "手动添加";
    default:
      return "全部";
  }
}

function filterTerms(terms: DictionaryTerm[], filter: DictionaryFilter) {
  if (filter === "all") return terms;
  return terms.filter((term) => term.source === filter);
}

function applyDemoMessage(current: SettingsState, message: any): SettingsState {
  switch (message.type) {
    case "selectTab":
      return { ...current, selectedTab: message.tab };
    case "setOutputLanguage":
      return { ...current, outputLanguage: message.language };
    case "setRewriteStyle":
      return { ...current, rewriteStyle: message.style };
    case "setWorkflow":
      return { ...current, selectedWorkflow: message.workflow };
    case "setWorkflowMode":
      return {
        ...current,
        workflows: current.workflows.map((item) =>
          item.id === message.workflow ? { ...item, mode: message.style } : item
        )
      };
    case "setDictionaryFilter":
      return { ...current, dictionaryFilter: message.filter };
    case "beginShortcutRecording":
      return { ...current, shortcut: { ...current.shortcut, recording: true } };
    case "cancelShortcutRecording":
      return { ...current, shortcut: { ...current.shortcut, recording: false } };
    case "resetShortcut":
      return { ...current, shortcut: { title: "右 Alt", recording: false } };
    case "addDictionaryTerm":
      return {
        ...current,
        dictionaryFilter: "manual",
        dictionaryTerms: [
          { phrase: message.phrase, weight: 8, scene: "全局", source: "manual" },
          ...current.dictionaryTerms.filter((term) => term.phrase.toLowerCase() !== message.phrase.toLowerCase())
        ]
      };
    case "deleteDictionaryTerm":
      return {
        ...current,
        dictionaryTerms: current.dictionaryTerms.filter((term) => term.phrase.toLowerCase() !== message.phrase.toLowerCase())
      };
    default:
      return current;
  }
}

createRoot(document.getElementById("root")!).render(<App />);
