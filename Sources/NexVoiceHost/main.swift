import AppKit
import Foundation
import NexVoiceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var shortcutMenuItem: NSMenuItem?
    private var shortcutSettingsMenuItem: NSMenuItem?
    private var asrMenuItem: NSMenuItem?
    private var chineseOutputMenuItem: NSMenuItem?
    private var englishOutputMenuItem: NSMenuItem?
    private var outputStyleMenuItem: NSMenuItem?
    private var outputStyleMenuItems: [VoiceRewriteStyle: NSMenuItem] = [:]
    private var rewriteEvaluationMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private let permissionService = MicrophonePermissionService()
    private let transcriptionService = TencentCloudRealtimeTranscriptionService()
    private let finalRewriteService = DeepSeekFinalRewriteService()
    private let captionPanel = VoiceCaptionPanelController()
    private let textInserter = FocusedTextInserter()
    private let shortcutStore = VoiceShortcutStore()
    private let shortcutMonitor = GlobalVoiceShortcutMonitor()
    private var shortcutSettingsWindowController: VoiceShortcutSettingsWindowController?
    private var selectedOutputLanguage = VoiceOutputLanguage.simplifiedChinese
    private var selectedRewriteStyle = VoiceRewriteStyle.default
    private var voiceShortcut: VoiceShortcut = .default
    private var targetApplicationForCurrentSession: NSRunningApplication?
    private var selectedTextContextForCurrentSession: SelectedTextContext?
    private var rewriteContextForCurrentSession: VoiceRewriteContext?
    private var didInsertCurrentSession = false
    private var isCurrentSessionCancelled = false
    private var insertedTextPreview: String?
    private var isRewritingCurrentSession = false
    private var beginSessionTask: Task<Void, Never>?
    private var rewriteTask: Task<Void, Never>?
    private var permissionRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if shouldRunRewriteEvaluationOnly {
            NSApp.setActivationPolicy(.accessory)
            Task {
                let reportURL = await VoiceRewriteEvaluationRunner.runAndWriteReport()
                print("NexVoice rewrite evaluation report: \(reportURL.path)")
                NSApp.terminate(nil)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
        voiceShortcut = shortcutStore.load()
        configureStatusItem()
        captionPanel.reset()
        startShortcutMonitor()
    }

    private var shouldRunRewriteEvaluationOnly: Bool {
        Bundle.main.bundleIdentifier == "com.nexvoice.mac.rewrite-eval-runner"
            || ProcessInfo.processInfo.arguments.contains("--run-rewrite-eval")
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "NexVoice"

        let menu = NSMenu()
        let shortcutItem = NSMenuItem(title: "快捷键：\(voiceShortcut.displayTitle)", action: nil, keyEquivalent: "")
        let settingsItem = NSMenuItem(title: "设置快捷键...", action: #selector(openShortcutSettings), keyEquivalent: "")
        let chineseOutputItem = NSMenuItem(title: "输出：中文", action: #selector(selectChineseOutput), keyEquivalent: "")
        let englishOutputItem = NSMenuItem(title: "输出：English", action: #selector(selectEnglishOutput), keyEquivalent: "")
        let outputStyleItem = NSMenuItem(title: "输出模式：\(selectedRewriteStyle.menuTitle)", action: nil, keyEquivalent: "")
        let rewriteEvaluationItem = NSMenuItem(title: "运行 DeepSeek 评测", action: #selector(runRewriteEvaluation), keyEquivalent: "")
        let accessibilityItem = NSMenuItem(title: VoicePermissionGuidance.accessibility.actionTitle, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        let localASRItem = NSMenuItem(title: "ASR：腾讯云实时 ASR（中英自动）", action: nil, keyEquivalent: "")
        let outputStyleMenu = NSMenu()

        shortcutItem.isEnabled = false
        localASRItem.isEnabled = false
        configureOutputStyleMenu(outputStyleMenu)
        outputStyleItem.submenu = outputStyleMenu

        menu.addItem(shortcutItem)
        menu.addItem(localASRItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(chineseOutputItem)
        menu.addItem(englishOutputItem)
        menu.addItem(outputStyleItem)
        menu.addItem(.separator())
        menu.addItem(rewriteEvaluationItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "申请麦克风权限", action: #selector(requestMicrophonePermission), keyEquivalent: ""))
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 NexVoice", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        shortcutMenuItem = shortcutItem
        shortcutSettingsMenuItem = settingsItem
        asrMenuItem = localASRItem
        chineseOutputMenuItem = chineseOutputItem
        englishOutputMenuItem = englishOutputItem
        outputStyleMenuItem = outputStyleItem
        rewriteEvaluationMenuItem = rewriteEvaluationItem
        accessibilityMenuItem = accessibilityItem

        item.menu = menu
        statusItem = item
        refreshMenuState()
    }

    private func configureOutputStyleMenu(_ menu: NSMenu) {
        outputStyleMenuItems = [:]
        for style in VoiceRewriteStyle.allCases {
            let item = NSMenuItem(
                title: style.menuTitle,
                action: #selector(selectOutputStyle(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = style.rawValue
            outputStyleMenuItems[style] = item
            menu.addItem(item)
        }
    }

    private func handleShortcutTriggered() {
        switch VoiceShortcutTriggerPolicy.action(for: shortcutSessionState) {
        case .begin:
            beginTranscription()
        case .finish:
            stopTranscription()
        case .ignore:
            break
        }
    }

    private func startShortcutMonitor() {
        shortcutMonitor.start(
            shortcut: voiceShortcut,
            onTrigger: { [weak self] in
                self?.handleShortcutTriggered()
            },
            onCancel: { [weak self] in
                self?.cancelCurrentSessionFromEscape()
            }
        )
        refreshMenuState()
    }

    @objc private func selectChineseOutput() {
        guard transcriptionService.state == .idle else { return }
        selectedOutputLanguage = .simplifiedChinese
        captionPanel.reset()
        refreshMenuState()
    }

    @objc private func selectEnglishOutput() {
        guard transcriptionService.state == .idle else { return }
        selectedOutputLanguage = .english
        captionPanel.reset()
        refreshMenuState()
    }

    @objc private func selectOutputStyle(_ sender: NSMenuItem) {
        guard transcriptionService.state == .idle else { return }
        guard let rawValue = sender.representedObject as? String,
              let style = VoiceRewriteStyle(rawValue: rawValue) else {
            return
        }
        selectedRewriteStyle = style
        captionPanel.reset()
        refreshMenuState()
    }

    @objc private func openShortcutSettings() {
        let controller = VoiceShortcutSettingsWindowController(shortcut: voiceShortcut) { [weak self] shortcut in
            guard let self else { return }
            self.voiceShortcut = shortcut
            self.shortcutStore.save(shortcut)
            self.shortcutMonitor.updateShortcut(shortcut)
            self.captionPanel.reset()
            self.refreshMenuState()
        }
        shortcutSettingsWindowController = controller
        controller.showWindow(nil)
    }

    @objc private func runRewriteEvaluation() {
        guard transcriptionService.state == .idle, rewriteTask == nil else { return }
        rewriteEvaluationMenuItem?.isEnabled = false
        statusItem?.button?.title = "NexVoice 评测中"
        captionPanel.showLoading("DeepSeek 评测中")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let reportURL = await VoiceRewriteEvaluationRunner.runAndWriteReport()
            self.captionPanel.showStatus("评测完成", isError: false, autoHideDelay: 1.4)
            self.statusItem?.button?.title = "NexVoice"
            self.rewriteEvaluationMenuItem?.isEnabled = true
            self.showNotification(
                title: "DeepSeek 评测完成",
                body: "报告已写入：\(reportURL.path)"
            )
            self.refreshMenuState()
        }
    }

    @objc private func openAccessibilitySettings() {
        _ = FocusedTextInserter.requestAccessibilityPermission()
        captionPanel.showPermissionNotice(.accessibility)
        schedulePermissionRefresh()
    }

    @objc private func requestMicrophonePermission() {
        switch permissionService.authorizationStatus() {
        case .authorized:
            showNotification(title: "麦克风已授权", body: "NexVoice 可以开始采集语音。")
        case .notDetermined:
            permissionService.requestAccess { [weak self] granted in
                DispatchQueue.main.async {
                    self?.showNotification(
                        title: granted ? "麦克风已授权" : "麦克风未授权",
                        body: granted ? "现在可以开始录音。" : "请在系统设置里允许 NexVoice 使用麦克风。"
                    )
                }
            }
        case .denied, .restricted, .unknown:
            _ = permissionService.openMicrophonePrivacySettings()
        }
    }

    private func beginTranscription() {
        guard beginSessionTask == nil else { return }
        beginSessionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.beginTranscriptionAfterSelectionCapture()
        }
    }

    private func beginTranscriptionAfterSelectionCapture() async {
        targetApplicationForCurrentSession = NSWorkspace.shared.frontmostApplication
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        insertedTextPreview = nil
        isRewritingCurrentSession = false
        rewriteTask?.cancel()
        rewriteTask = nil

        guard permissionService.authorizationStatus() == .authorized else {
            captionPanel.showPreparing()
            requestMicrophonePermission()
            beginSessionTask = nil
            return
        }
        selectedTextContextForCurrentSession = await textInserter.selectedTextContext(
            in: targetApplicationForCurrentSession
        )
        let personalDictionary = VoicePersonalDictionaryStore.load()
        rewriteContextForCurrentSession = textInserter.rewriteContext(
            in: targetApplicationForCurrentSession,
            selectedTextMode: selectedTextContextForCurrentSession?.text.isEmpty == false,
            personalDictionary: personalDictionary
        )
        guard !isCurrentSessionCancelled, !Task.isCancelled else {
            beginSessionTask = nil
            return
        }
        captionPanel.reset()
        captionPanel.showOverlay()
        do {
            try transcriptionService.start(personalDictionary: personalDictionary) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptionEvent(event)
                }
            }
            statusItem?.button?.title = "NexVoice 听写中"
            refreshMenuState()
        } catch {
            captionPanel.showStatus("启动失败", isError: true, autoHideDelay: 1.4)
            statusItem?.button?.title = "NexVoice 出错"
            refreshMenuState()
        }
        beginSessionTask = nil
    }

    private func handleTranscriptionEvent(_ event: VoiceRealtimeEvent) {
        guard !isCurrentSessionCancelled else { return }

        if case .failed(let message) = event {
            handleTranscriptionFailure(message)
            return
        }

        if case .finalTranscript = event, !didInsertCurrentSession {
            insertFinalTextIfNeeded(from: event)
            return
        }

        if case .sessionEnded = event, isRewritingCurrentSession {
            statusItem?.button?.title = "NexVoice 整理中"
            refreshMenuState()
            return
        }

        if case .sessionEnded = event, let insertedTextPreview {
            statusItem?.button?.title = "NexVoice"
            captionPanel.showInsertedText(insertedTextPreview)
            refreshMenuState()
            return
        }

        captionPanel.apply(event)
        insertFinalTextIfNeeded(from: event)
        switch event {
        case .sessionStarted:
            statusItem?.button?.title = "NexVoice 听写中"
        case .partialTranscript:
            statusItem?.button?.title = "NexVoice 转写中"
        case .finalTranscript, .sessionEnded:
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
        case .failed:
            break
        case .partialTranslation, .finalTranslation, .latencyUpdated, .audioLevelUpdated:
            break
        }
    }

    private func insertFinalTextIfNeeded(from event: VoiceRealtimeEvent) {
        guard !isCurrentSessionCancelled else { return }
        guard !didInsertCurrentSession, let text = VoiceFinalTextPolicy.insertionText(from: event) else { return }
        didInsertCurrentSession = true
        isRewritingCurrentSession = true
        let isContextualCommand = selectedTextContextForCurrentSession?.text.isEmpty == false
        captionPanel.showLoading(
            isContextualCommand ? "AI 处理中" : "AI 整理中",
            anchorRect: selectedTextContextForCurrentSession?.anchorRect
        )
        statusItem?.button?.title = "NexVoice 整理中"
        refreshMenuState()

        let originalText = text
        let outputLanguage = selectedOutputLanguage
        let rewriteStyle = selectedRewriteStyle
        let selectedTextContext = selectedTextContextForCurrentSession
        let rewriteContext = rewriteContextForCurrentSession ?? VoiceRewriteContext(
            sourceApplicationName: targetApplicationForCurrentSession?.localizedName,
            sourceApplicationBundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
            selectedTextMode: selectedTextContext?.text.isEmpty == false,
            personalDictionary: VoicePersonalDictionaryStore.load()
        )
        let targetApplication = targetApplicationForCurrentSession
        rewriteTask?.cancel()
        rewriteTask = Task { [weak self] in
            guard let self else { return }
            if let selectedTextContext, !selectedTextContext.text.isEmpty {
                let result: String
                do {
                    result = try await self.finalRewriteService.handleSelectedTextCommand(
                        selectedText: selectedTextContext.text,
                        instruction: originalText,
                        outputLanguage: outputLanguage,
                        style: rewriteStyle,
                        context: rewriteContext
                    )
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        guard !self.isCurrentSessionCancelled else { return }
                        self.selectedTextContextForCurrentSession = nil
                        self.isRewritingCurrentSession = false
                        self.rewriteTask = nil
                        self.captionPanel.showStatus("处理失败", isError: true, autoHideDelay: 1.4)
                        self.statusItem?.button?.title = "NexVoice 出错"
                        self.refreshMenuState()
                    }
                    return
                }
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.showContextualResult(result, anchorRect: selectedTextContext.anchorRect)
                }
            } else {
                let textForInsertion: String
                do {
                    textForInsertion = try await self.finalRewriteService.rewrite(
                        originalText,
                        outputLanguage: outputLanguage,
                        style: rewriteStyle,
                        context: rewriteContext
                    )
                } catch is CancellationError {
                    return
                } catch {
                    textForInsertion = VoiceRewriteFallbackPolicy.fallbackText(for: originalText)
                }
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.insertRewrittenText(textForInsertion, into: targetApplication)
                }
            }
        }
    }

    private func showContextualResult(_ text: String, anchorRect: CGRect?) {
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        insertedTextPreview = nil
        isRewritingCurrentSession = false
        rewriteTask = nil
        captionPanel.showContextualResult(text, anchorRect: anchorRect)
        statusItem?.button?.title = "NexVoice"
        refreshMenuState()
    }

    private func insertRewrittenText(_ text: String, into targetApplication: NSRunningApplication?) {
        guard !isCurrentSessionCancelled else { return }
        insertedTextPreview = text
        isRewritingCurrentSession = false
        rewriteTask = nil
        rewriteContextForCurrentSession = nil

        do {
            try textInserter.insert(text, into: targetApplication)
            captionPanel.showInsertedText(text)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
        } catch {
            captionPanel.showStatus("输入失败", isError: true, autoHideDelay: 1.4)
            statusItem?.button?.title = "NexVoice 出错"
            refreshMenuState()
        }
    }

    private func stopTranscription() {
        captionPanel.showLoading("正在处理")
        transcriptionService.finish()
        statusItem?.button?.title = "NexVoice 等待腾讯云结果"
        refreshMenuState()
    }

    private func cancelCurrentSessionFromEscape() {
        guard VoiceSessionCancellationPolicy.shouldCancel(
            transcriptionState: shortcutSessionState,
            isRewriting: isRewritingCurrentSession,
            hasRewriteTask: rewriteTask != nil
        ) || beginSessionTask != nil else {
            return
        }
        isCurrentSessionCancelled = true
        didInsertCurrentSession = true
        insertedTextPreview = nil
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        targetApplicationForCurrentSession = nil
        isRewritingCurrentSession = false
        beginSessionTask?.cancel()
        beginSessionTask = nil
        rewriteTask?.cancel()
        rewriteTask = nil
        transcriptionService.stop()
        captionPanel.showStatus("已取消", isError: false, autoHideDelay: 0.8)
        statusItem?.button?.title = "NexVoice"
        refreshMenuState()
    }

    private func handleTranscriptionFailure(_ message: String) {
        guard !isCurrentSessionCancelled else { return }

        if VoiceFinalTextPolicy.isNoRecognizedSpeechMessage(message) {
            isRewritingCurrentSession = false
            rewriteTask?.cancel()
            rewriteTask = nil
            captionPanel.showStatus("未识别到语音", isError: false, autoHideDelay: 0.9)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
            return
        }

        isRewritingCurrentSession = false
        rewriteTask?.cancel()
        rewriteTask = nil
        captionPanel.showStatus("转写失败", isError: true, autoHideDelay: 1.4)
        statusItem?.button?.title = "NexVoice 出错"
        refreshMenuState()
    }

    private var shortcutSessionState: VoiceShortcutSessionState {
        switch transcriptionService.state {
        case .idle:
            return .idle
        case .running:
            return .running
        case .finishing:
            return .finishing
        }
    }

    @objc private func quit() {
        beginSessionTask?.cancel()
        rewriteTask?.cancel()
        transcriptionService.stop()
        NSApp.terminate(nil)
    }

    private func schedulePermissionRefresh() {
        permissionRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.startShortcutMonitor()
                self?.refreshMenuState()
            }
        }
        permissionRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
    }

    private func refreshMenuState() {
        shortcutMenuItem?.title = "快捷键：\(voiceShortcut.displayTitle)"
        asrMenuItem?.title = cloudASRMenuTitle()

        switch transcriptionService.state {
        case .idle:
            shortcutSettingsMenuItem?.isEnabled = true
        case .running:
            shortcutSettingsMenuItem?.isEnabled = false
        case .finishing:
            shortcutSettingsMenuItem?.isEnabled = false
        }

        chineseOutputMenuItem?.state = selectedOutputLanguage == .simplifiedChinese ? .on : .off
        englishOutputMenuItem?.state = selectedOutputLanguage == .english ? .on : .off
        chineseOutputMenuItem?.isEnabled = transcriptionService.state == .idle
        englishOutputMenuItem?.isEnabled = transcriptionService.state == .idle
        outputStyleMenuItem?.title = "输出模式：\(selectedRewriteStyle.menuTitle)"
        outputStyleMenuItem?.isEnabled = transcriptionService.state == .idle
        for (style, item) in outputStyleMenuItems {
            item.state = style == selectedRewriteStyle ? .on : .off
            item.isEnabled = transcriptionService.state == .idle
        }
        rewriteEvaluationMenuItem?.isEnabled = transcriptionService.state == .idle && rewriteTask == nil

        accessibilityMenuItem?.title = textInserter.canPostKeyboardEvents
            ? "辅助功能权限已允许"
            : VoicePermissionGuidance.accessibility.actionTitle
    }

    private func cloudASRMenuTitle() -> String {
        do {
            let credentials = try TencentCloudASRCredentialStore.load()
            if credentials.isComplete {
                return "ASR：腾讯云实时 ASR（中英自动）"
            }
            return "ASR：腾讯云实时 ASR（缺少 \(credentials.missingFieldNames.joined(separator: "、"))）"
        } catch {
            return "ASR：腾讯云实时 ASR（配置读取失败）"
        }
    }

    private func showNotification(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
