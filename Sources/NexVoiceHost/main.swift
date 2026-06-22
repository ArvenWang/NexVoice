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
    private var personalDictionaryMenuItem: NSMenuItem?
    private var rewriteEvaluationMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private var inputMonitoringMenuItem: NSMenuItem?
    private var screenRecordingMenuItem: NSMenuItem?
    private let permissionService = MicrophonePermissionService()
    private let transcriptionService = TencentCloudRealtimeTranscriptionService()
    private let finalRewriteService = DeepSeekFinalRewriteService()
    private let screenReplyCaptureService = ScreenReplyContextCaptureService()
    private let captionPanel = VoiceCaptionPanelController()
    private let textInserter = FocusedTextInserter()
    private lazy var dictionaryLearningMonitor = VoiceDictionaryAutoLearningMonitor(
        textReader: textInserter,
        onLearningStarted: { [weak self] in
            self?.showDictionaryLearningStarted()
        },
        onLearningFinished: { [weak self] result in
            self?.showDictionaryLearningFinished(result)
        }
    )
    private let shortcutStore = VoiceShortcutStore()
    private let shortcutMonitor = GlobalVoiceShortcutMonitor()
    private var shortcutSettingsWindowController: VoiceShortcutSettingsWindowController?
    private var personalDictionaryWindowController: VoicePersonalDictionaryWindowController?
    private var selectedOutputLanguage = VoiceOutputLanguage.simplifiedChinese
    private var selectedRewriteStyle = VoiceRewriteStyle.default
    private var voiceShortcut: VoiceShortcut = .default
    private var targetApplicationForCurrentSession: NSRunningApplication?
    private var selectedTextContextForCurrentSession: SelectedTextContext?
    private var rewriteContextForCurrentSession: VoiceRewriteContext?
    private var screenReplyCapturedContextForCurrentSession: ScreenReplyCapturedContext?
    private var pendingScreenReplyVoiceInstruction: String?
    private var didInsertCurrentSession = false
    private var isCurrentSessionCancelled = false
    private var insertedTextPreview: String?
    private var isRewritingCurrentSession = false
    private var isScreenReplyInstructionSession = false
    private var didDetectScreenReplyVoiceInstruction = false
    private var beginSessionTask: Task<Void, Never>?
    private var rewriteTask: Task<Void, Never>?
    private var permissionRefreshWorkItem: DispatchWorkItem?
    private var activeDictionaryLearningTasks = 0
    private var dictionaryLearningResetWorkItem: DispatchWorkItem?

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
        let personalDictionaryItem = NSMenuItem(title: "个人词库...", action: #selector(openPersonalDictionary), keyEquivalent: "")
        let rewriteEvaluationItem = NSMenuItem(title: "运行 DeepSeek 评测", action: #selector(runRewriteEvaluation), keyEquivalent: "")
        let accessibilityItem = NSMenuItem(title: VoicePermissionGuidance.accessibility.actionTitle, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        let inputMonitoringItem = NSMenuItem(title: "申请输入监控权限", action: #selector(openInputMonitoringSettings), keyEquivalent: "")
        let screenRecordingItem = NSMenuItem(title: "申请屏幕录制权限", action: #selector(openScreenRecordingSettings), keyEquivalent: "")
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
        menu.addItem(personalDictionaryItem)
        menu.addItem(.separator())
        menu.addItem(rewriteEvaluationItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "申请麦克风权限", action: #selector(requestMicrophonePermission), keyEquivalent: ""))
        menu.addItem(accessibilityItem)
        menu.addItem(inputMonitoringItem)
        menu.addItem(screenRecordingItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 NexVoice", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        shortcutMenuItem = shortcutItem
        shortcutSettingsMenuItem = settingsItem
        asrMenuItem = localASRItem
        chineseOutputMenuItem = chineseOutputItem
        englishOutputMenuItem = englishOutputItem
        outputStyleMenuItem = outputStyleItem
        personalDictionaryMenuItem = personalDictionaryItem
        rewriteEvaluationMenuItem = rewriteEvaluationItem
        accessibilityMenuItem = accessibilityItem
        inputMonitoringMenuItem = inputMonitoringItem
        screenRecordingMenuItem = screenRecordingItem

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
        guard !isRewritingCurrentSession, rewriteTask == nil else { return }
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
        let didStart = shortcutMonitor.start(
            shortcut: voiceShortcut,
            onTrigger: { [weak self] in
                self?.handleShortcutTriggered()
            },
            onLongPress: { [weak self] in
                self?.handleShortcutLongPressed()
            },
            onLongPressEnded: { [weak self] in
                self?.handleShortcutLongPressEnded()
            },
            onCancel: { [weak self] in
                self?.cancelCurrentSessionFromEscape()
            }
        )
        if !didStart {
            let message = SystemPermissionRequester.hasInputMonitoringPermission
                ? "快捷键被占用"
                : "需要输入监控权限"
            captionPanel.showStatus(message, isError: true, autoHideDelay: 1.8)
        }
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
        let controller = VoiceShortcutSettingsWindowController(
            shortcut: voiceShortcut,
            onShortcutChanged: { [weak self] shortcut in
                guard let self else { return }
                self.voiceShortcut = shortcut
                self.shortcutStore.save(shortcut)
                self.shortcutMonitor.updateShortcut(shortcut)
                self.captionPanel.reset()
                self.refreshMenuState()
            },
            onRecordingStateChanged: { [weak self] isRecording in
                guard let self else { return }
                if isRecording {
                    self.shortcutMonitor.stop()
                } else {
                    self.startShortcutMonitor()
                }
                self.refreshMenuState()
            }
        )
        shortcutSettingsWindowController = controller
        controller.showWindow(nil)
    }

    @objc private func openPersonalDictionary() {
        let controller = personalDictionaryWindowController ?? VoicePersonalDictionaryWindowController()
        personalDictionaryWindowController = controller
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

    @objc private func openInputMonitoringSettings() {
        if !SystemPermissionRequester.requestInputMonitoringPermission() {
            SystemPermissionRequester.openInputMonitoringSettings()
        }
        captionPanel.showStatus("请允许输入监控", isError: false, autoHideDelay: 1.8)
        schedulePermissionRefresh()
    }

    @objc private func openScreenRecordingSettings() {
        ScreenReplyContextCaptureService.requestScreenRecordingPermission()
        captionPanel.showStatus("请允许屏幕录制", isError: false, autoHideDelay: 1.8)
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

    private func handleShortcutLongPressed() {
        guard transcriptionService.state == .idle,
              beginSessionTask == nil,
              rewriteTask == nil,
              !isRewritingCurrentSession else {
            return
        }
        beginScreenReply()
    }

    private func handleShortcutLongPressEnded() {
        guard isScreenReplyInstructionSession else { return }
        switch transcriptionService.state {
        case .running:
            stopTranscription()
        case .finishing:
            break
        case .idle:
            generateScreenReply(voiceInstruction: "")
        }
    }

    private func beginScreenReply() {
        targetApplicationForCurrentSession = NSWorkspace.shared.frontmostApplication
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        insertedTextPreview = nil
        isRewritingCurrentSession = true
        isScreenReplyInstructionSession = true
        didDetectScreenReplyVoiceInstruction = false
        dictionaryLearningMonitor.cancel()
        rewriteTask?.cancel()
        captionPanel.showPassiveMessage("识别中")
        statusItem?.button?.title = "NexVoice 识别中"
        refreshMenuState()

        let targetApplication = targetApplicationForCurrentSession
        let personalDictionary = VoicePersonalDictionaryStore.load()
        let rewriteContext = textInserter.rewriteContext(
            in: targetApplication,
            selectedTextMode: false,
            personalDictionary: personalDictionary
        )
        rewriteContextForCurrentSession = rewriteContext

        startScreenReplyInstructionCapture(
            personalDictionary: personalDictionary,
            rewriteContext: rewriteContext
        )

        rewriteTask = Task { [weak self] in
            guard let self else { return }
            let capturedContext: ScreenReplyCapturedContext
            do {
                capturedContext = try await self.screenReplyCaptureService.capture(from: targetApplication)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.finishScreenReplyWithError(error)
                }
                return
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !self.isCurrentSessionCancelled,
                      self.isScreenReplyInstructionSession else { return }
                self.screenReplyCapturedContextForCurrentSession = capturedContext
                self.rewriteTask = nil
                if let instruction = self.pendingScreenReplyVoiceInstruction {
                    self.pendingScreenReplyVoiceInstruction = nil
                    self.generateScreenReply(voiceInstruction: instruction)
                } else {
                    self.isRewritingCurrentSession = false
                    self.statusItem?.button?.title = "NexVoice 识别中"
                    self.refreshMenuState()
                }
            }
        }
    }

    private func startScreenReplyInstructionCapture(
        personalDictionary: VoicePersonalDictionary,
        rewriteContext: VoiceRewriteContext
    ) {
        guard permissionService.authorizationStatus() == .authorized else {
            captionPanel.showPreparing()
            requestMicrophonePermission()
            finishScreenReplyInstructionSession()
            return
        }
        captionPanel.showPassiveMessage("识别中")
        do {
            try transcriptionService.start(
                personalDictionary: personalDictionary,
                rewriteContext: rewriteContext
            ) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptionEvent(event)
                }
            }
            statusItem?.button?.title = "NexVoice 识别中"
            refreshMenuState()
        } catch {
            generateScreenReply(voiceInstruction: "")
        }
    }

    private func beginTranscriptionAfterSelectionCapture() async {
        targetApplicationForCurrentSession = NSWorkspace.shared.frontmostApplication
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        insertedTextPreview = nil
        isRewritingCurrentSession = false
        isScreenReplyInstructionSession = false
        didDetectScreenReplyVoiceInstruction = false
        dictionaryLearningMonitor.cancel()
        activeDictionaryLearningTasks = 0
        dictionaryLearningResetWorkItem?.cancel()
        dictionaryLearningResetWorkItem = nil
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
            try transcriptionService.start(
                personalDictionary: personalDictionary,
                rewriteContext: rewriteContextForCurrentSession
            ) { [weak self] event in
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

        if case .finalTranscript(let instruction) = event, isScreenReplyInstructionSession {
            generateScreenReply(voiceInstruction: instruction)
            return
        }

        if isScreenReplyInstructionSession {
            handleScreenReplyInstructionEvent(event)
            return
        }

        if case .finalTranscript = event, !didInsertCurrentSession {
            insertFinalTextIfNeeded(from: event)
            return
        }

        if case .sessionEnded = event, isRewritingCurrentSession {
            statusItem?.button?.title = isScreenReplyInstructionSession
                ? "NexVoice 回复中"
                : "NexVoice 整理中"
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

    private func handleScreenReplyInstructionEvent(_ event: VoiceRealtimeEvent) {
        switch event {
        case .partialTranscript:
            guard !didDetectScreenReplyVoiceInstruction else { return }
            didDetectScreenReplyVoiceInstruction = true
            captionPanel.showPassiveMessage("识别到指令")
            statusItem?.button?.title = "NexVoice 识别到指令"
        case .sessionStarted, .audioLevelUpdated, .latencyUpdated:
            statusItem?.button?.title = didDetectScreenReplyVoiceInstruction
                ? "NexVoice 识别到指令"
                : "NexVoice 识别中"
        case .sessionEnded:
            if isRewritingCurrentSession {
                statusItem?.button?.title = "NexVoice AI 输入中"
            }
        case .finalTranscript, .failed, .partialTranslation, .finalTranslation:
            break
        }
        refreshMenuState()
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
                    textForInsertion = VoicePersonalDictionaryTextProtector.protect(
                        VoiceRewriteFallbackPolicy.fallbackText(for: originalText),
                        dictionary: rewriteContext.personalDictionary
                    )
                }
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.insertRewrittenText(
                        textForInsertion,
                        originalASRText: originalText,
                        rewriteContext: rewriteContext,
                        into: targetApplication
                    )
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

    private func insertRewrittenText(
        _ text: String,
        originalASRText: String,
        rewriteContext: VoiceRewriteContext,
        into targetApplication: NSRunningApplication?
    ) {
        guard !isCurrentSessionCancelled else { return }
        insertedTextPreview = text
        isRewritingCurrentSession = false
        rewriteTask = nil
        rewriteContextForCurrentSession = nil

        do {
            try textInserter.insert(text, into: targetApplication)
            dictionaryLearningMonitor.observePossibleEdit(
                insertedText: text,
                originalASRText: originalASRText,
                rewrittenText: text,
                context: rewriteContext,
                targetApplication: targetApplication
            )
            captionPanel.showInsertedText(text)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
        } catch {
            captionPanel.showStatus("输入失败", isError: true, autoHideDelay: 1.4)
            statusItem?.button?.title = "NexVoice 出错"
            refreshMenuState()
        }
    }

    private func generateScreenReply(voiceInstruction: String) {
        guard !isCurrentSessionCancelled else { return }
        guard isScreenReplyInstructionSession else {
            finishScreenReplyWithError(ScreenReplyCaptureError.captureFailed)
            return
        }
        let trimmedInstruction = voiceInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let capturedContext = screenReplyCapturedContextForCurrentSession else {
            pendingScreenReplyVoiceInstruction = trimmedInstruction
            isRewritingCurrentSession = true
            captionPanel.showLoading("AI 输入中")
            statusItem?.button?.title = "NexVoice AI 输入中"
            refreshMenuState()
            return
        }
        guard !didInsertCurrentSession else { return }
        didInsertCurrentSession = true
        isRewritingCurrentSession = true
        captionPanel.showLoading("AI 输入中")
        statusItem?.button?.title = "NexVoice AI 输入中"
        refreshMenuState()

        let outputLanguage = selectedOutputLanguage
        let rewriteStyle = selectedRewriteStyle
        let rewriteContext = rewriteContextForCurrentSession ?? VoiceRewriteContext(
            sourceApplicationName: targetApplicationForCurrentSession?.localizedName,
            sourceApplicationBundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
            personalDictionary: VoicePersonalDictionaryStore.load()
        )
        let targetApplication = targetApplicationForCurrentSession

        rewriteTask?.cancel()
        rewriteTask = Task { [weak self] in
            guard let self else { return }
            let reply: String
            do {
                reply = try await self.finalRewriteService.handleScreenReply(
                    visibleText: capturedContext.visibleText,
                    structuredMessages: capturedContext.structuredMessages,
                    voiceInstruction: trimmedInstruction,
                    outputLanguage: outputLanguage,
                    style: rewriteStyle,
                    context: rewriteContext
                )
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.finishScreenReplyWithError(error)
                }
                return
            }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !self.isCurrentSessionCancelled else { return }
                self.insertScreenReply(reply, into: targetApplication)
            }
        }
    }

    private func insertScreenReply(_ reply: String, into targetApplication: NSRunningApplication?) {
        insertedTextPreview = reply
        isRewritingCurrentSession = false
        finishScreenReplyInstructionSession()
        rewriteTask = nil
        rewriteContextForCurrentSession = nil
        do {
            try textInserter.insert(reply, into: targetApplication)
            captionPanel.showInsertedText(reply)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
        } catch {
            finishScreenReplyWithError(error)
        }
    }

    private func finishScreenReplyWithError(_ error: Error) {
        isRewritingCurrentSession = false
        finishScreenReplyInstructionSession()
        rewriteTask = nil
        rewriteContextForCurrentSession = nil
        let message: String
        if case ScreenReplyCaptureError.screenRecordingPermissionRequired = error {
            ScreenReplyContextCaptureService.requestScreenRecordingPermission()
            message = "需要屏幕录制权限"
        } else if case ScreenReplyCaptureError.noRecognizedText = error {
            message = "未识别到文字"
        } else {
            message = "看屏回复失败"
        }
        captionPanel.showStatus(message, isError: true, autoHideDelay: 1.6)
        statusItem?.button?.title = "NexVoice 出错"
        refreshMenuState()
    }

    private func finishScreenReplyInstructionSession() {
        isScreenReplyInstructionSession = false
        didDetectScreenReplyVoiceInstruction = false
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
    }

    private func stopTranscription() {
        if isScreenReplyInstructionSession {
            captionPanel.showLoading("AI 输入中")
        } else {
            captionPanel.showLoading("正在处理")
        }
        transcriptionService.finish()
        statusItem?.button?.title = isScreenReplyInstructionSession
            ? "NexVoice AI 输入中"
            : "NexVoice 等待腾讯云结果"
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
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
        targetApplicationForCurrentSession = nil
        isRewritingCurrentSession = false
        isScreenReplyInstructionSession = false
        didDetectScreenReplyVoiceInstruction = false
        dictionaryLearningMonitor.cancel()
        activeDictionaryLearningTasks = 0
        dictionaryLearningResetWorkItem?.cancel()
        dictionaryLearningResetWorkItem = nil
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
            if isScreenReplyInstructionSession {
                generateScreenReply(voiceInstruction: "")
                return
            }
            isRewritingCurrentSession = false
            rewriteTask?.cancel()
            rewriteTask = nil
            captionPanel.showStatus("未识别到语音", isError: false, autoHideDelay: 0.9)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
            return
        }

        isRewritingCurrentSession = false
        finishScreenReplyInstructionSession()
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
        dictionaryLearningMonitor.cancel()
        activeDictionaryLearningTasks = 0
        dictionaryLearningResetWorkItem?.cancel()
        dictionaryLearningResetWorkItem = nil
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
        let canChangeMode = transcriptionService.state == .idle && !isRewritingCurrentSession
        chineseOutputMenuItem?.isEnabled = canChangeMode
        englishOutputMenuItem?.isEnabled = canChangeMode
        outputStyleMenuItem?.title = "输出模式：\(selectedRewriteStyle.menuTitle)"
        outputStyleMenuItem?.isEnabled = canChangeMode
        for (style, item) in outputStyleMenuItems {
            item.state = style == selectedRewriteStyle ? .on : .off
            item.isEnabled = canChangeMode
        }
        rewriteEvaluationMenuItem?.isEnabled = transcriptionService.state == .idle && rewriteTask == nil
        personalDictionaryMenuItem?.isEnabled = true

        accessibilityMenuItem?.title = textInserter.canPostKeyboardEvents
            ? "辅助功能权限已允许"
            : VoicePermissionGuidance.accessibility.actionTitle
        inputMonitoringMenuItem?.title = SystemPermissionRequester.hasInputMonitoringPermission
            ? "输入监控权限已允许"
            : "申请输入监控权限"
        screenRecordingMenuItem?.title = SystemPermissionRequester.hasScreenRecordingPermission
            ? "屏幕录制权限已允许"
            : "申请屏幕录制权限"
        if activeDictionaryLearningTasks > 0, transcriptionService.state == .idle, !isRewritingCurrentSession {
            statusItem?.button?.title = "NexVoice 学习中"
        }
    }

    private func showDictionaryLearningStarted() {
        dictionaryLearningResetWorkItem?.cancel()
        dictionaryLearningResetWorkItem = nil
        activeDictionaryLearningTasks += 1
        if transcriptionService.state == .idle, !isRewritingCurrentSession {
            statusItem?.button?.title = "NexVoice 学习中"
        }
    }

    private func showDictionaryLearningFinished(_ result: VoiceDictionaryLearningResult?) {
        activeDictionaryLearningTasks = max(0, activeDictionaryLearningTasks - 1)
        if activeDictionaryLearningTasks == 0,
           transcriptionService.state == .idle,
           !isRewritingCurrentSession {
            let resetWorkItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.activeDictionaryLearningTasks == 0,
                          self.transcriptionService.state == .idle,
                          !self.isRewritingCurrentSession else {
                        return
                    }
                    self.statusItem?.button?.title = "NexVoice"
                    self.dictionaryLearningResetWorkItem = nil
                }
            }
            dictionaryLearningResetWorkItem = resetWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: resetWorkItem)
        }
        guard let result else { return }
        let action = result.wasInserted ? "已加入词库" : "已更新词库"
        captionPanel.showStatus(
            "\(result.term) \(action)",
            isError: false,
            autoHideDelay: 2.2
        )
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
