import AppKit
import CoreGraphics
import Foundation
import NexVoiceCore
import QuartzCore
import WebKit

final class VoiceWebSettingsWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate {
    enum Tab: String {
        case input
        case modes
        case workflow
        case dictionary
        case permissions
    }

    private enum DictionaryFilter: String {
        case all
        case automatic
        case manual
    }

    private enum WorkflowOption: String, CaseIterable {
        case agentCollaboration = "agent-collaboration"
        case emailReply = "email-reply"
        case social
        case workChat = "work-chat"
        case general

        var title: String {
            switch self {
            case .agentCollaboration: return "开发协作"
            case .emailReply: return "邮件回复"
            case .social: return "社交发布"
            case .workChat: return "即时沟通"
            case .general: return "通用输入"
            }
        }

        var promptHint: String {
            switch self {
            case .agentCollaboration:
                return "保留用户的任务、约束、判断和问题边界；不要把需求改成泛泛建议。"
            case .emailReply:
                return "表达礼貌清楚、有分寸；必要称呼和收尾要克制。"
            case .social:
                return "像真人自然发言，避免翻译腔和过度正式；允许更强网感。"
            case .workChat:
                return "简洁自然，行动明确，少铺垫；不要扩写成正式文档。"
            case .general:
                return "清晰自然，少加工，可直接发送。"
            }
        }

        var likelySources: String {
            switch self {
            case .agentCollaboration:
                return "Codex, Cursor, Xcode, VS Code, ChatGPT, Claude, Windsurf。"
            case .emailReply:
                return "Mail, Outlook, Spark, Airmail, Gmail。"
            case .social:
                return "X, Reddit, YouTube, Threads, 评论框。"
            case .workChat:
                return "Slack, Discord, Telegram, WeChat, Lark, 飞书。"
            case .general:
                return "没有命中其他工作流时使用。"
            }
        }

        init(workflow: VoiceAppWorkflow) {
            self = WorkflowOption(rawValue: workflow.identifier) ?? .general
        }
    }

    private final class ScriptHandler: NSObject, WKScriptMessageHandler {
        weak var owner: VoiceWebSettingsWindowController?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DispatchQueue.main.async { [weak owner] in
                owner?.handleScriptMessage(message.body)
            }
        }
    }

    private final class TitlebarDragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    private final class DraggableSettingsWebView: WKWebView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            guard let window,
                  Self.isTitlebarDragPoint(event.locationInWindow, in: window) else {
                super.mouseDown(with: event)
                return
            }
            window.performDrag(with: event)
        }

        static func isTitlebarDragPoint(_ point: NSPoint, in window: NSWindow) -> Bool {
            let height = window.contentView?.bounds.height ?? window.frame.height
            return point.x >= 84 && point.y >= height - 60
        }
    }

    private struct ModeDescriptor {
        let style: VoiceRewriteStyle
        let title: String
        let description: String
        let fidelity: Int
        let emotion: Int
        let divergence: Int
    }

    private static let modeDescriptors: [ModeDescriptor] = [
        ModeDescriptor(
            style: .standard,
            title: "标准模式",
            description: "修正吞字、断词、重复和口头禅，让表达自然清晰；严格贴合原意。",
            fidelity: 95,
            emotion: 30,
            divergence: 10
        ),
        ModeDescriptor(
            style: .socialExpert,
            title: "社交达人",
            description: "更适合聊天、评论和社交媒体；表达轻松，有网感。",
            fidelity: 78,
            emotion: 58,
            divergence: 42
        ),
        ModeDescriptor(
            style: .amplifiedSpokesperson,
            title: "强化嘴替",
            description: "放大原本情绪和态度，表达更锋利、更有冲击力。",
            fidelity: 62,
            emotion: 96,
            divergence: 76
        ),
        ModeDescriptor(
            style: .calm,
            title: "冷静模式",
            description: "压低攻击性和混乱表达，用更少的字保留核心诉求。",
            fidelity: 88,
            emotion: 18,
            divergence: 14
        )
    ]

    private let webView: WKWebView
    private let loadingView = NSView()
    private let scriptHandler: ScriptHandler
    private var webViewReady = false
    private var shortcut: VoiceShortcut
    private var shortcutCommand: VoiceShortcutQuickCommand
    private var outputLanguage: VoiceOutputLanguage
    private var rewriteStyle: VoiceRewriteStyle
    private var selectedTab: Tab
    private var selectedWorkflow: WorkflowOption = .general
    private var workflowWasManuallySelected = false
    private var dictionaryFilter: DictionaryFilter = .all
    private var localShortcutMonitor: Any?
    private var titlebarDragMonitor: Any?
    private var isRecordingShortcut = false

    private let workflowContextProvider: () -> VoiceRewriteContext
    private let canChangeInputSettings: () -> Bool
    private let onShortcutChanged: (VoiceShortcut) -> Void
    private let onShortcutCommandChanged: (VoiceShortcutQuickCommand) -> Void
    private let onOutputLanguageChanged: (VoiceOutputLanguage) -> Void
    private let onRewriteStyleChanged: (VoiceRewriteStyle) -> Void
    private let workflowRewriteStyleProvider: (String, VoiceRewriteStyle) -> VoiceRewriteStyle
    private let onWorkflowRewriteStyleChanged: (String, VoiceRewriteStyle) -> Void
    private let onShortcutRecordingStateChanged: (Bool) -> Void
    private let onRequestMicrophonePermission: () -> Void
    private let onRequestAccessibilityPermission: () -> Void
    private let onRequestScreenRecordingPermission: () -> Void

    init(
        selectedTab: Tab,
        shortcut: VoiceShortcut,
        shortcutCommand: VoiceShortcutQuickCommand,
        outputLanguage: VoiceOutputLanguage,
        rewriteStyle: VoiceRewriteStyle,
        workflowContextProvider: @escaping () -> VoiceRewriteContext,
        canChangeInputSettings: @escaping () -> Bool,
        onShortcutChanged: @escaping (VoiceShortcut) -> Void,
        onShortcutCommandChanged: @escaping (VoiceShortcutQuickCommand) -> Void,
        onOutputLanguageChanged: @escaping (VoiceOutputLanguage) -> Void,
        onRewriteStyleChanged: @escaping (VoiceRewriteStyle) -> Void,
        workflowRewriteStyleProvider: @escaping (String, VoiceRewriteStyle) -> VoiceRewriteStyle,
        onWorkflowRewriteStyleChanged: @escaping (String, VoiceRewriteStyle) -> Void,
        onShortcutRecordingStateChanged: @escaping (Bool) -> Void,
        onRequestMicrophonePermission: @escaping () -> Void,
        onRequestAccessibilityPermission: @escaping () -> Void,
        onRequestScreenRecordingPermission: @escaping () -> Void
    ) {
        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 472)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "NexVoice 设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = contentRect.size
        window.maxSize = contentRect.size
        window.backgroundColor = Self.windowBackgroundColor

        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let scriptHandler = ScriptHandler()
        userContentController.addUserScript(Self.webErrorReporterScript())
        userContentController.add(scriptHandler, name: "settings")
        configuration.userContentController = userContentController
        self.scriptHandler = scriptHandler
        self.webView = DraggableSettingsWebView(frame: contentRect, configuration: configuration)

        self.selectedTab = selectedTab
        self.shortcut = shortcut
        self.shortcutCommand = shortcutCommand
        self.outputLanguage = outputLanguage
        self.rewriteStyle = rewriteStyle
        self.workflowContextProvider = workflowContextProvider
        self.canChangeInputSettings = canChangeInputSettings
        self.onShortcutChanged = onShortcutChanged
        self.onShortcutCommandChanged = onShortcutCommandChanged
        self.onOutputLanguageChanged = onOutputLanguageChanged
        self.onRewriteStyleChanged = onRewriteStyleChanged
        self.workflowRewriteStyleProvider = workflowRewriteStyleProvider
        self.onWorkflowRewriteStyleChanged = onWorkflowRewriteStyleChanged
        self.onShortcutRecordingStateChanged = onShortcutRecordingStateChanged
        self.onRequestMicrophonePermission = onRequestMicrophonePermission
        self.onRequestAccessibilityPermission = onRequestAccessibilityPermission
        self.onRequestScreenRecordingPermission = onRequestScreenRecordingPermission

        super.init(window: window)

        self.scriptHandler.owner = self
        window.delegate = self
        configureWebView()
        installTitlebarDragMonitor()
        loadSettingsWeb()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        refreshWorkflowIfNeeded()
        sendState()
    }

    func select(tab: Tab) {
        selectedTab = tab
        refreshWorkflowIfNeeded()
        sendState()
    }

    func update(
        shortcut: VoiceShortcut,
        shortcutCommand: VoiceShortcutQuickCommand,
        outputLanguage: VoiceOutputLanguage,
        rewriteStyle: VoiceRewriteStyle
    ) {
        self.shortcut = shortcut
        self.shortcutCommand = shortcutCommand
        self.outputLanguage = outputLanguage
        self.rewriteStyle = rewriteStyle
        refreshWorkflowIfNeeded()
        sendState()
    }

    func windowWillClose(_ notification: Notification) {
        stopShortcutRecording(sendUpdate: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Swift.print("[SettingsWeb] navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Swift.print("[SettingsWeb] provisional navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoadingView(delay: 0.15)
    }

    private func configureWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = Self.windowBackgroundColor.cgColor
        window?.contentView = NSView()
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Self.windowBackgroundColor.cgColor
        contentView.addSubview(webView)
        configureLoadingView(in: contentView, above: webView)
        let titlebarDragView = TitlebarDragView()
        titlebarDragView.translatesAutoresizingMaskIntoConstraints = false
        titlebarDragView.wantsLayer = true
        titlebarDragView.layer?.backgroundColor = NSColor.clear.cgColor
        titlebarDragView.layer?.zPosition = 1000
        contentView.addSubview(titlebarDragView, positioned: .above, relativeTo: webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titlebarDragView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 84),
            titlebarDragView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titlebarDragView.topAnchor.constraint(equalTo: contentView.topAnchor),
            titlebarDragView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func configureLoadingView(in contentView: NSView, above webView: NSView) {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.wantsLayer = true
        loadingView.layer?.backgroundColor = Self.windowBackgroundColor.cgColor
        loadingView.layer?.zPosition = 900

        let titleLabel = NSTextField(labelWithString: "NexVoice")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.92, alpha: 1)

        let messageLabel = NSTextField(labelWithString: "设置加载中...")
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)

        let progress = NSProgressIndicator()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.style = .spinning
        progress.controlSize = .regular
        progress.startAnimation(nil)

        loadingView.addSubview(titleLabel)
        loadingView.addSubview(messageLabel)
        loadingView.addSubview(progress)
        contentView.addSubview(loadingView, positioned: .above, relativeTo: webView)

        NSLayoutConstraint.activate([
            loadingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),
            messageLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            progress.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            progress.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 18)
        ])
    }

    private func hideLoadingView(delay: TimeInterval = 0) {
        guard !loadingView.isHidden else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.loadingView.animator().alphaValue = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.loadingView.isHidden = true
            }
        }
    }

    private func installTitlebarDragMonitor() {
        titlebarDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window,
                  self.isTitlebarDragEvent(event, in: window) else {
                return event
            }
            window.performDrag(with: event)
            return nil
        }
    }

    private func isTitlebarDragEvent(_ event: NSEvent, in window: NSWindow) -> Bool {
        DraggableSettingsWebView.isTitlebarDragPoint(event.locationInWindow, in: window)
    }

    private func loadSettingsWeb() {
        guard let indexURL = settingsWebIndexURL() else {
            webView.loadHTMLString(missingSettingsHTML(), baseURL: nil)
            return
        }
        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    }

    private func settingsWebIndexURL() -> URL? {
        let fileManager = FileManager.default
        let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("SettingsWeb", isDirectory: true)
            .appendingPathComponent("index.html")
        if let resourceURL, fileManager.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDistURL = sourceRoot
            .appendingPathComponent("SettingsWeb", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: sourceDistURL.path) {
            return sourceDistURL
        }

        let cwdDistURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("SettingsWeb", isDirectory: true)
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent("index.html")
        if fileManager.fileExists(atPath: cwdDistURL.path) {
            return cwdDistURL
        }

        return nil
    }

    private func handleScriptMessage(_ body: Any) {
        guard let message = body as? [String: Any],
              let type = message["type"] as? String else {
            return
        }

        switch type {
        case "ready":
            webViewReady = true
            hideLoadingView()
            refreshWorkflowIfNeeded()
            sendState()
        case "selectTab":
            if let tabRaw = message["tab"] as? String,
               let tab = Tab(rawValue: tabRaw) {
                select(tab: tab)
            }
        case "beginShortcutRecording":
            beginShortcutRecording()
        case "cancelShortcutRecording":
            stopShortcutRecording(sendUpdate: true)
        case "resetShortcut":
            applyShortcut(.default)
        case "setOutputLanguage":
            guard canChangeInputSettings(),
                  let rawValue = message["language"] as? String,
                  let language = VoiceOutputLanguage(rawValue: rawValue) else { return }
            outputLanguage = language
            onOutputLanguageChanged(language)
            sendState()
        case "setRewriteStyle":
            guard let rawValue = message["style"] as? String,
                  let style = VoiceRewriteStyle(rawValue: rawValue) else { return }
            applyRewriteStyle(style)
        case "setShortcutCommand":
            guard let rawValue = message["command"] as? String,
                  let command = VoiceShortcutQuickCommand(rawValue: rawValue) else { return }
            shortcutCommand = command
            onShortcutCommandChanged(command)
            sendState()
        case "setWorkflow":
            guard let rawValue = message["workflow"] as? String,
                  let workflow = WorkflowOption(rawValue: rawValue) else { return }
            selectedWorkflow = workflow
            workflowWasManuallySelected = true
            sendState()
        case "setWorkflowMode":
            guard let workflowIdentifier = message["workflow"] as? String,
                  let rawValue = message["style"] as? String,
                  let style = VoiceRewriteStyle(rawValue: rawValue) else { return }
            onWorkflowRewriteStyleChanged(workflowIdentifier, style)
            sendState()
        case "setDictionaryFilter":
            guard let rawValue = message["filter"] as? String,
                  let filter = DictionaryFilter(rawValue: rawValue) else { return }
            dictionaryFilter = filter
            sendState()
        case "addDictionaryTerm":
            guard let phrase = message["phrase"] as? String else { return }
            addDictionaryTerm(phrase)
        case "deleteDictionaryTerm":
            guard let phrase = message["phrase"] as? String else { return }
            deleteDictionaryTerm(phrase)
        case "requestPermission":
            guard let permission = message["permission"] as? String else { return }
            requestPermission(permission)
        case "refresh":
            refreshWorkflowIfNeeded(force: true)
            sendState()
        case "webError":
            let text = message["message"] as? String ?? "unknown frontend error"
            Swift.print("[SettingsWeb] \(text)")
        default:
            break
        }
    }

    private func refreshWorkflowIfNeeded(force: Bool = false) {
        guard force || !workflowWasManuallySelected else { return }
        selectedWorkflow = WorkflowOption(workflow: workflowContextProvider().applicationWorkflow)
    }

    private func applyRewriteStyle(_ style: VoiceRewriteStyle) {
        rewriteStyle = style
        onRewriteStyleChanged(style)
        sendState()
    }

    private func addDictionaryTerm(_ phrase: String) {
        let normalizedPhrase = normalizeManualTerm(phrase)
        guard VoiceDictionaryLearningPolicy.isValidDictionaryTerm(normalizedPhrase) else {
            sendState()
            return
        }
        _ = try? VoicePersonalDictionaryStore.upsert(
            VoicePersonalDictionaryTerm(
                phrase: normalizedPhrase,
                weight: 8,
                note: "手动添加",
                contextWeights: workflowContextProvider().sourceApplicationBundleIdentifier.map {
                    ["bundle:\($0.lowercased())": 1]
                } ?? [:]
            )
        )
        dictionaryFilter = .manual
        sendState()
    }

    private func deleteDictionaryTerm(_ phrase: String) {
        _ = try? VoicePersonalDictionaryStore.delete(phrase: phrase)
        sendState()
    }

    private func requestPermission(_ permission: String) {
        switch permission {
        case "microphone":
            onRequestMicrophonePermission()
        case "accessibility":
            onRequestAccessibilityPermission()
        case "screenRecording":
            onRequestScreenRecordingPermission()
        default:
            break
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.sendState()
        }
    }

    private func beginShortcutRecording() {
        guard canChangeInputSettings() else { return }
        stopShortcutRecording(sendUpdate: false)
        isRecordingShortcut = true
        onShortcutRecordingStateChanged(true)
        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handleShortcutRecordingEvent(event)
        }
        sendState()
    }

    private func handleShortcutRecordingEvent(_ event: NSEvent) -> NSEvent? {
        guard isRecordingShortcut else { return event }
        if event.type == .keyDown, event.keyCode == 53 {
            stopShortcutRecording(sendUpdate: true)
            return nil
        }
        let eventType: VoiceShortcutRecordingEventType = event.type == .flagsChanged ? .flagsChanged : .keyDown
        let flags = event.cgEvent?.flags ?? CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        guard let recordedShortcut = VoiceShortcutRecordingPolicy.shortcut(
            for: eventType,
            keyCode: event.keyCode,
            flags: flags
        ) else {
            return event
        }
        applyShortcut(recordedShortcut)
        return nil
    }

    private func applyShortcut(_ nextShortcut: VoiceShortcut) {
        shortcut = nextShortcut
        onShortcutChanged(nextShortcut)
        stopShortcutRecording(sendUpdate: false)
        sendState()
    }

    private func stopShortcutRecording(sendUpdate: Bool) {
        if let localShortcutMonitor {
            NSEvent.removeMonitor(localShortcutMonitor)
            self.localShortcutMonitor = nil
        }
        guard isRecordingShortcut else {
            if sendUpdate { sendState() }
            return
        }
        isRecordingShortcut = false
        onShortcutRecordingStateChanged(false)
        if sendUpdate { sendState() }
    }

    private func sendState() {
        guard webViewReady else { return }
        let state = makeState()
        guard JSONSerialization.isValidJSONObject(state),
              let data = try? JSONSerialization.data(withJSONObject: state),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        webView.evaluateJavaScript("window.NexVoiceSettings && window.NexVoiceSettings.receiveState(\(json));")
    }

    private func makeState() -> [String: Any] {
        let context = workflowContextProvider()
        let dictionary = VoicePersonalDictionaryStore.load()
        let currentWorkflow = WorkflowOption(workflow: context.applicationWorkflow)
        if !workflowWasManuallySelected {
            selectedWorkflow = currentWorkflow
        }

        return [
            "selectedTab": selectedTab.rawValue,
            "versionText": appVersionText(),
            "shortcutCommand": [
                "title": shortcutCommand.displayTitle,
                "value": shortcutCommand.rawValue
            ],
            "shortcut": [
                "title": shortcut.displayTitle,
                "recording": isRecordingShortcut
            ],
            "outputLanguage": outputLanguage.rawValue,
            "rewriteStyle": rewriteStyle.rawValue,
            "modes": Self.modeDescriptors.map(modeState),
            "workflows": WorkflowOption.allCases.map { workflowState($0, currentWorkflow: currentWorkflow) },
            "selectedWorkflow": selectedWorkflow.rawValue,
            "currentAppName": context.sourceApplicationName ?? "未知应用",
            "dictionaryFilter": dictionaryFilter.rawValue,
            "dictionaryTerms": filteredTerms(dictionary.terms).map(dictionaryTermState),
            "permissions": permissionState()
        ]
    }

    private func modeState(_ descriptor: ModeDescriptor) -> [String: Any] {
        [
            "id": descriptor.style.rawValue,
            "title": descriptor.title,
            "description": descriptor.description,
            "metrics": [
                ["label": "原意", "value": descriptor.fidelity],
                ["label": "情绪", "value": descriptor.emotion],
                ["label": "发散", "value": descriptor.divergence]
            ]
        ]
    }

    private func workflowState(_ workflow: WorkflowOption, currentWorkflow: WorkflowOption) -> [String: Any] {
        [
            "id": workflow.rawValue,
            "title": workflow.title,
            "promptHint": workflow.promptHint,
            "sources": workflow.likelySources,
            "status": workflow == currentWorkflow ? "已识别" : "未命中",
            "mode": workflowRewriteStyleProvider(workflow.rawValue, rewriteStyle).rawValue
        ]
    }

    private func filteredTerms(_ terms: [VoicePersonalDictionaryTerm]) -> [VoicePersonalDictionaryTerm] {
        switch dictionaryFilter {
        case .all:
            return terms
        case .automatic:
            return terms.filter { !isManualTerm($0) }
        case .manual:
            return terms.filter { isManualTerm($0) }
        }
    }

    private func dictionaryTermState(_ term: VoicePersonalDictionaryTerm) -> [String: Any] {
        [
            "phrase": term.phrase,
            "weight": term.weight,
            "scene": contextDisplay(term.contextWeights),
            "source": isManualTerm(term) ? "manual" : "automatic"
        ]
    }

    private func permissionState() -> [[String: Any]] {
        let microphoneStatus = MicrophonePermissionService().authorizationStatus()
        return [
            [
                "id": "microphone",
                "title": "麦克风",
                "detail": "用于录音和语音指令识别。",
                "allowed": microphoneStatus == .authorized,
                "status": microphoneStatus == .authorized ? "已允许" : "未允许"
            ],
            [
                "id": "accessibility",
                "title": "辅助功能",
                "detail": "把最终文本写入当前输入框。",
                "allowed": SystemPermissionRequester.hasAccessibilityPermission,
                "status": SystemPermissionRequester.hasAccessibilityPermission ? "已允许" : "未允许"
            ],
            [
                "id": "screenRecording",
                "title": "屏幕录制",
                "detail": "看屏回复只读取当前屏幕可见内容。",
                "allowed": SystemPermissionRequester.hasScreenRecordingPermission,
                "status": SystemPermissionRequester.hasScreenRecordingPermission ? "已允许" : "未允许"
            ]
        ]
    }

    private func isManualTerm(_ term: VoicePersonalDictionaryTerm) -> Bool {
        term.note?.localizedCaseInsensitiveContains("手动") == true
    }

    private func contextDisplay(_ contextWeights: [String: Int]) -> String {
        guard !contextWeights.isEmpty else { return "全局" }
        let first = contextWeights.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }.first?.key ?? ""
        if first.contains("com.openai.codex") { return "Codex" }
        if first.contains("agent-collaboration") { return "开发协作" }
        if first.hasPrefix("bundle:") {
            return first.replacingOccurrences(of: "bundle:", with: "")
        }
        if first.hasPrefix("workflow:") {
            return first.replacingOccurrences(of: "workflow:", with: "")
        }
        return first
    }

    private func normalizeManualTerm(_ phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let compactedLetters = trimmed
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: " ", with: "")
        if compactedLetters.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{1,63}$"#, options: .regularExpression) != nil,
           trimmed.contains("'") || trimmed.contains("’") {
            return compactedLetters
        }
        return trimmed
    }

    private func appVersionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func missingSettingsHTML() -> String {
        """
        <!doctype html>
        <html><body style="margin:0;background:#101011;color:#eee;font:13px -apple-system;display:grid;place-items:center;height:100vh;">
        <div>设置页资源缺失。请先运行 <code>npm run build</code> 或重新打包。</div>
        </body></html>
        """
    }

    private static func webErrorReporterScript() -> WKUserScript {
        let source = """
        (function () {
          function report(message) {
            try {
              window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.settings &&
                window.webkit.messageHandlers.settings.postMessage({ type: "webError", message: String(message) });
            } catch (_) {}
          }
          window.addEventListener("error", function (event) {
            report((event.message || "script error") + (event.filename ? " @ " + event.filename + ":" + event.lineno : ""));
          });
          window.addEventListener("unhandledrejection", function (event) {
            report("unhandled rejection: " + (event.reason && event.reason.message ? event.reason.message : event.reason));
          });
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private static var windowBackgroundColor: NSColor {
        NSColor(calibratedRed: 16.0 / 255.0, green: 16.0 / 255.0, blue: 17.0 / 255.0, alpha: 1)
    }

}
