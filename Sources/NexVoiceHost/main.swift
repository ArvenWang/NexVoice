import AppKit
import Foundation
import NexVoiceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct FailedTranscriptionRetry {
        let originalText: String
        let rewriteContext: VoiceRewriteContext
        let targetApplication: NSRunningApplication?
    }

    private var statusItem: NSStatusItem?
    private var shortcutMenuItem: NSMenuItem?
    private var shortcutSettingsMenuItem: NSMenuItem?
    private var outputLanguageMenuItem: NSMenuItem?
    private var chineseOutputMenuItem: NSMenuItem?
    private var englishOutputMenuItem: NSMenuItem?
    private var outputStyleMenuItem: NSMenuItem?
    private var outputStyleMenuItems: [VoiceRewriteStyle: NSMenuItem] = [:]
    private var personalDictionaryMenuItem: NSMenuItem?
    private var microphoneMenuItem: NSMenuItem?
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
    private let workflowRewriteStyleStore = VoiceWorkflowRewriteStyleStore()
    private let shortcutMonitor = GlobalVoiceShortcutMonitor()
    private var settingsWindowController: VoiceWebSettingsWindowController?
    private var settingsPreviewApplication: NSRunningApplication?
    private var selectedOutputLanguage = VoiceOutputLanguage.simplifiedChinese
    private var selectedRewriteStyle = VoiceRewriteStyle.default
    private var voiceShortcut: VoiceShortcut = .default
    private var targetApplicationForCurrentSession: NSRunningApplication?
    private var selectedTextContextForCurrentSession: SelectedTextContext?
    private var rewriteContextForCurrentSession: VoiceRewriteContext?
    private var focusedDraftForCurrentSession: String?
    private var focusedDraftReadMethodForCurrentSession: FocusedTextAccessMethod?
    private var hasEditableSelectionForCurrentSession = false
    private var screenReplyCapturedContextForCurrentSession: ScreenReplyCapturedContext?
    private var pendingScreenReplyVoiceInstruction: String?
    private var didInsertCurrentSession = false
    private var isCurrentSessionCancelled = false
    private var insertedTextPreview: String?
    private var latestRecoverableASRText: String?
    private var pendingFailedTranscriptionRetry: FailedTranscriptionRetry?
    private var isRewritingCurrentSession = false
    private var isScreenReplyInstructionSession = false
    private var didDetectScreenReplyVoiceInstruction = false
    private var beginSessionTask: Task<Void, Never>?
    private var rewriteTask: Task<Void, Never>?
    private var permissionRefreshWorkItem: DispatchWorkItem?
    private var activeDictionaryLearningTasks = 0
    private var dictionaryLearningResetWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        voiceShortcut = shortcutStore.load()
        selectedOutputLanguage = Self.loadOutputLanguage()
        selectedRewriteStyle = Self.loadRewriteStyle()
        configureStatusItem()
        captionPanel.reset()
        startShortcutMonitor()
        prewarmSettingsWindow()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "NexVoice"

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "打开设置...", action: #selector(openSettingsMenu), keyEquivalent: "")
        let shortcutItem = NSMenuItem(title: "快捷键：\(voiceShortcut.displayTitle)", action: nil, keyEquivalent: "")
        let outputLanguageItem = NSMenuItem(title: "输出语言：中文", action: nil, keyEquivalent: "")
        let chineseOutputItem = NSMenuItem(title: "输出：中文", action: #selector(selectChineseOutput), keyEquivalent: "")
        let englishOutputItem = NSMenuItem(title: "输出：English", action: #selector(selectEnglishOutput), keyEquivalent: "")
        let outputStyleItem = NSMenuItem(title: "输出模式：\(selectedRewriteStyle.menuTitle)", action: nil, keyEquivalent: "")
        let personalDictionaryItem = NSMenuItem(title: "个人词库...", action: #selector(openPersonalDictionary), keyEquivalent: "")
        let microphoneItem = NSMenuItem(title: "申请麦克风权限", action: #selector(requestMicrophonePermission), keyEquivalent: "")
        let accessibilityItem = NSMenuItem(title: VoicePermissionGuidance.accessibility.actionTitle, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        let inputMonitoringItem = NSMenuItem(title: "申请输入监控权限", action: #selector(openInputMonitoringSettings), keyEquivalent: "")
        let screenRecordingItem = NSMenuItem(title: "申请屏幕录制权限", action: #selector(openScreenRecordingSettings), keyEquivalent: "")
        let outputLanguageMenu = NSMenu()
        let permissionsMenu = NSMenu()
        let outputStyleMenu = NSMenu()
        let permissionsGroupItem = NSMenuItem(title: "权限", action: nil, keyEquivalent: "")

        shortcutItem.isEnabled = false
        configureOutputStyleMenu(outputStyleMenu)
        outputLanguageItem.submenu = outputLanguageMenu
        outputStyleItem.submenu = outputStyleMenu
        permissionsGroupItem.submenu = permissionsMenu

        outputLanguageMenu.addItem(chineseOutputItem)
        outputLanguageMenu.addItem(englishOutputItem)

        permissionsMenu.addItem(microphoneItem)
        permissionsMenu.addItem(accessibilityItem)
        permissionsMenu.addItem(inputMonitoringItem)
        permissionsMenu.addItem(screenRecordingItem)

        menu.addItem(settingsItem)
        menu.addItem(shortcutItem)
        menu.addItem(.separator())
        menu.addItem(outputLanguageItem)
        menu.addItem(outputStyleItem)
        menu.addItem(personalDictionaryItem)
        menu.addItem(permissionsGroupItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 NexVoice", action: #selector(quit), keyEquivalent: "q"))
        assignTargets(in: menu)

        shortcutMenuItem = shortcutItem
        shortcutSettingsMenuItem = settingsItem
        outputLanguageMenuItem = outputLanguageItem
        chineseOutputMenuItem = chineseOutputItem
        englishOutputMenuItem = englishOutputItem
        outputStyleMenuItem = outputStyleItem
        personalDictionaryMenuItem = personalDictionaryItem
        microphoneMenuItem = microphoneItem
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

    private func assignTargets(in menu: NSMenu) {
        for item in menu.items {
            if item.action != nil {
                item.target = self
            }
            if let submenu = item.submenu {
                assignTargets(in: submenu)
            }
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
        Self.saveOutputLanguage(selectedOutputLanguage)
        captionPanel.reset()
        refreshMenuState()
    }

    @objc private func selectEnglishOutput() {
        guard transcriptionService.state == .idle else { return }
        selectedOutputLanguage = .english
        Self.saveOutputLanguage(selectedOutputLanguage)
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
        Self.saveRewriteStyle(style)
        captionPanel.reset()
        refreshMenuState()
    }

    @objc private func openSettingsMenu() {
        openSettings(tab: .input)
    }

    private func prewarmSettingsWindow() {
        DispatchQueue.main.async { [weak self] in
            _ = self?.settingsController(selectedTab: .input)
        }
    }

    private func openSettings(tab: VoiceWebSettingsWindowController.Tab) {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            settingsPreviewApplication = frontmostApplication
        }

        let controller = settingsController(selectedTab: tab)
        controller.update(
            shortcut: voiceShortcut,
            outputLanguage: selectedOutputLanguage,
            rewriteStyle: selectedRewriteStyle
        )
        controller.select(tab: tab)
        controller.showWindow(nil)
    }

    private func settingsController(selectedTab tab: VoiceWebSettingsWindowController.Tab) -> VoiceWebSettingsWindowController {
        if let settingsWindowController {
            return settingsWindowController
        }

        let controller = VoiceWebSettingsWindowController(
            selectedTab: tab,
            shortcut: voiceShortcut,
            outputLanguage: selectedOutputLanguage,
            rewriteStyle: selectedRewriteStyle,
            workflowContextProvider: { [weak self] in
                guard let self else { return VoiceRewriteContext() }
                return self.textInserter.rewriteContext(
                    in: self.settingsPreviewTargetApplication(),
                    selectedTextMode: false,
                    personalDictionary: VoicePersonalDictionaryStore.load()
                )
            },
            canChangeInputSettings: { true },
            onShortcutChanged: { [weak self] shortcut in
                guard let self else { return }
                self.voiceShortcut = shortcut
                self.shortcutStore.save(shortcut)
                self.shortcutMonitor.updateShortcut(shortcut)
                self.captionPanel.reset()
                self.refreshMenuState()
            },
            onOutputLanguageChanged: { [weak self] language in
                guard let self else { return }
                self.selectedOutputLanguage = language
                Self.saveOutputLanguage(language)
                self.captionPanel.reset()
                self.refreshMenuState()
            },
            onRewriteStyleChanged: { [weak self] style in
                guard let self else { return }
                self.selectedRewriteStyle = style
                Self.saveRewriteStyle(style)
                self.captionPanel.reset()
                self.refreshMenuState()
            },
            workflowRewriteStyleProvider: { [weak self] workflowIdentifier, defaultStyle in
                guard let self else { return defaultStyle }
                return self.workflowRewriteStyleStore.style(
                    for: workflowIdentifier,
                    defaultStyle: defaultStyle
                )
            },
            onWorkflowRewriteStyleChanged: { [weak self] workflowIdentifier, style in
                guard let self else { return }
                self.workflowRewriteStyleStore.save(style, for: workflowIdentifier)
                self.captionPanel.reset()
                self.refreshMenuState()
            },
            onShortcutRecordingStateChanged: { [weak self] isRecording in
                guard let self else { return }
                self.shortcutMonitor.setSuspended(isRecording)
                self.refreshMenuState()
            },
            onRequestMicrophonePermission: { [weak self] in
                self?.requestMicrophonePermission()
            },
            onRequestAccessibilityPermission: { [weak self] in
                self?.openAccessibilitySettings()
            },
            onRequestScreenRecordingPermission: { [weak self] in
                self?.openScreenRecordingSettings()
            }
        )
        settingsWindowController = controller
        return controller
    }

    private func settingsPreviewTargetApplication() -> NSRunningApplication? {
        if let targetApplicationForCurrentSession {
            return targetApplicationForCurrentSession
        }
        if let settingsPreviewApplication {
            return settingsPreviewApplication
        }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        guard frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return frontmostApplication
    }

    @objc private func openPersonalDictionary() {
        openSettings(tab: .dictionary)
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
        focusedDraftForCurrentSession = nil
        focusedDraftReadMethodForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        insertedTextPreview = nil
        latestRecoverableASRText = nil
        pendingFailedTranscriptionRetry = nil
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
                let focusedInputFrame = self.textInserter.focusedInputFrame(in: targetApplication)
                capturedContext = try await self.screenReplyCaptureService.capture(
                    from: targetApplication,
                    focusedInputFrame: focusedInputFrame
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
        focusedDraftForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
        screenReplyCapturedContextForCurrentSession = nil
        pendingScreenReplyVoiceInstruction = nil
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        insertedTextPreview = nil
        latestRecoverableASRText = nil
        pendingFailedTranscriptionRetry = nil
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
        hasEditableSelectionForCurrentSession = textInserter.hasEditableSelection(
            in: targetApplicationForCurrentSession
        )
        if hasEditableSelectionForCurrentSession {
            focusedDraftForCurrentSession = nil
            focusedDraftReadMethodForCurrentSession = nil
        } else if let snapshot = await textInserter.focusedDraftSnapshotResult(
            in: targetApplicationForCurrentSession
        ) {
            focusedDraftForCurrentSession = snapshot.text
            focusedDraftReadMethodForCurrentSession = snapshot.method
        }
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

        switch event {
        case .partialTranscript(let text, _), .finalTranscript(let text):
            latestRecoverableASRText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
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
        let continuousRewriteDecision = VoiceContinuousRewritePolicy.decision(
            focusedDraft: focusedDraftForCurrentSession,
            newTranscript: originalText,
            hasEditableSelection: hasEditableSelectionForCurrentSession
        )
        Task {
            await ContinuousRewriteDiagnosticsLogger.shared.log(
                ContinuousRewriteDiagnosticEvent(
                    event: "decision",
                    appName: targetApplicationForCurrentSession?.localizedName,
                    bundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
                    hasEditableSelection: hasEditableSelectionForCurrentSession,
                    focusedDraft: focusedDraftForCurrentSession,
                    newTranscript: originalText,
                    insertionMode: continuousRewriteDecision.insertionMode,
                    draftReadMethod: focusedDraftReadMethodForCurrentSession
                )
            )
        }
        let outputLanguage = selectedOutputLanguage
        let selectedTextContext = selectedTextContextForCurrentSession
        let rewriteContext = rewriteContextForCurrentSession ?? VoiceRewriteContext(
            sourceApplicationName: targetApplicationForCurrentSession?.localizedName,
            sourceApplicationBundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
            selectedTextMode: selectedTextContext?.text.isEmpty == false,
            personalDictionary: VoicePersonalDictionaryStore.load()
        )
        let rewriteStyle = rewriteStyle(for: rewriteContext)
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
                var insertionMode = continuousRewriteDecision.insertionMode
                do {
                    textForInsertion = try await self.finalRewriteService.rewrite(
                        continuousRewriteDecision.rewriteSource,
                        outputLanguage: outputLanguage,
                        style: rewriteStyle,
                        context: rewriteContext
                    )
                } catch is CancellationError {
                    return
                } catch {
                    insertionMode = .insertAtCursor
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
                        into: targetApplication,
                        insertionMode: insertionMode
                    )
                }
            }
        }
    }

    private func showContextualResult(_ text: String, anchorRect: CGRect?) {
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        focusedDraftForCurrentSession = nil
        focusedDraftReadMethodForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
        latestRecoverableASRText = nil
        pendingFailedTranscriptionRetry = nil
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
        into targetApplication: NSRunningApplication?,
        insertionMode: VoiceContinuousRewriteInsertionMode = .insertAtCursor
    ) {
        guard !isCurrentSessionCancelled else { return }
        insertedTextPreview = text
        isRewritingCurrentSession = false
        rewriteTask = nil
        rewriteContextForCurrentSession = nil
        focusedDraftForCurrentSession = nil
        let draftReadMethod = focusedDraftReadMethodForCurrentSession
        focusedDraftReadMethodForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
        latestRecoverableASRText = nil
        pendingFailedTranscriptionRetry = nil

        do {
            switch insertionMode {
            case .insertAtCursor:
                try textInserter.insert(text, into: targetApplication)
            case .replaceFocusedDraft:
                try textInserter.replaceFocusedDraft(text, into: targetApplication)
            }
            Task {
                await ContinuousRewriteDiagnosticsLogger.shared.log(
                    ContinuousRewriteDiagnosticEvent(
                        event: "inserted",
                        appName: targetApplication?.localizedName,
                        bundleIdentifier: targetApplication?.bundleIdentifier,
                        hasEditableSelection: false,
                        focusedDraft: nil,
                        newTranscript: originalASRText,
                        insertionMode: insertionMode,
                        draftReadMethod: draftReadMethod,
                        actualInsertionMethod: textInserter.latestInsertionMethod,
                        insertedText: text
                    )
                )
            }
            schedulePostInsertionReadbackDiagnostic(
                insertedText: text,
                originalASRText: originalASRText,
                targetApplication: targetApplication,
                insertionMode: insertionMode,
                draftReadMethod: draftReadMethod,
                actualInsertionMethod: textInserter.latestInsertionMethod
            )
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

    private func schedulePostInsertionReadbackDiagnostic(
        insertedText: String,
        originalASRText: String,
        targetApplication: NSRunningApplication?,
        insertionMode: VoiceContinuousRewriteInsertionMode,
        draftReadMethod: FocusedTextAccessMethod?,
        actualInsertionMethod: FocusedTextAccessMethod?
    ) {
        // Temporary diagnostic for Codex/Electron newline handling. Remove once
        // we know whether AX writeback preserves paragraph breaks in practice.
        Task { @MainActor [weak self, targetApplication] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            let readbackSnapshot = await self.textInserter.focusedDraftSnapshotResult(in: targetApplication)
            await ContinuousRewriteDiagnosticsLogger.shared.log(
                ContinuousRewriteDiagnosticEvent(
                    event: "post_insert_readback",
                    appName: targetApplication?.localizedName,
                    bundleIdentifier: targetApplication?.bundleIdentifier,
                    hasEditableSelection: false,
                    focusedDraft: nil,
                    newTranscript: originalASRText,
                    insertionMode: insertionMode,
                    draftReadMethod: draftReadMethod,
                    actualInsertionMethod: actualInsertionMethod,
                    insertedText: insertedText,
                    readbackText: readbackSnapshot?.text,
                    readbackMethod: readbackSnapshot?.method,
                    expectedReadbackText: insertedText,
                    includeTextPreviews: false
                )
            )
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
        let rewriteContext = rewriteContextForCurrentSession ?? VoiceRewriteContext(
            sourceApplicationName: targetApplicationForCurrentSession?.localizedName,
            sourceApplicationBundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
            personalDictionary: VoicePersonalDictionaryStore.load()
        )
        let rewriteStyle = rewriteStyle(for: rewriteContext)
        let targetApplication = targetApplicationForCurrentSession

        rewriteTask?.cancel()
        rewriteTask = Task { [weak self] in
            guard let self else { return }
            await ScreenReplyDiagnosticsLogger.shared.log(
                ScreenReplyDiagnosticEvent(
                    captureID: capturedContext.captureID,
                    event: "generating",
                    appName: capturedContext.appName,
                    bundleIdentifier: capturedContext.bundleIdentifier,
                    windowTitle: capturedContext.windowTitle,
                    inputFrame: capturedContext.inputFrameInWindow,
                    replyRegion: capturedContext.replyRegionInWindow,
                    lineCount: capturedContext.lineCount,
                    visibleText: capturedContext.visibleText,
                    structuredMessages: capturedContext.structuredMessages,
                    lines: capturedContext.lines,
                    voiceInstruction: trimmedInstruction
                )
            )
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
                await ScreenReplyDiagnosticsLogger.shared.log(
                    ScreenReplyDiagnosticEvent(
                        captureID: capturedContext.captureID,
                        event: "failed",
                        appName: capturedContext.appName,
                        bundleIdentifier: capturedContext.bundleIdentifier,
                        windowTitle: capturedContext.windowTitle,
                        inputFrame: capturedContext.inputFrameInWindow,
                        replyRegion: capturedContext.replyRegionInWindow,
                        lineCount: capturedContext.lineCount,
                        visibleText: capturedContext.visibleText,
                        structuredMessages: capturedContext.structuredMessages,
                        lines: capturedContext.lines,
                        voiceInstruction: trimmedInstruction,
                        errorMessage: error.localizedDescription
                    )
                )
                await MainActor.run {
                    guard !self.isCurrentSessionCancelled else { return }
                    self.finishScreenReplyWithError(error)
                }
                return
            }
            guard !Task.isCancelled else { return }
            await ScreenReplyDiagnosticsLogger.shared.log(
                ScreenReplyDiagnosticEvent(
                    captureID: capturedContext.captureID,
                    event: "succeeded",
                    appName: capturedContext.appName,
                    bundleIdentifier: capturedContext.bundleIdentifier,
                    windowTitle: capturedContext.windowTitle,
                    inputFrame: capturedContext.inputFrameInWindow,
                    replyRegion: capturedContext.replyRegionInWindow,
                    lineCount: capturedContext.lineCount,
                    visibleText: capturedContext.visibleText,
                    structuredMessages: capturedContext.structuredMessages,
                    lines: capturedContext.lines,
                    voiceInstruction: trimmedInstruction,
                    reply: reply
                )
            )

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
        focusedDraftForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
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
        focusedDraftForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
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
        latestRecoverableASRText = nil
        pendingFailedTranscriptionRetry = nil
        selectedTextContextForCurrentSession = nil
        rewriteContextForCurrentSession = nil
        focusedDraftForCurrentSession = nil
        hasEditableSelectionForCurrentSession = false
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
            focusedDraftForCurrentSession = nil
            hasEditableSelectionForCurrentSession = false
            captionPanel.showStatus("未识别到语音", isError: false, autoHideDelay: 0.9)
            statusItem?.button?.title = "NexVoice"
            refreshMenuState()
            return
        }

        let wasScreenReplyInstructionSession = isScreenReplyInstructionSession
        isRewritingCurrentSession = false
        finishScreenReplyInstructionSession()
        rewriteTask?.cancel()
        rewriteTask = nil
        if !wasScreenReplyInstructionSession,
           let retry = failedTranscriptionRetrySnapshot() {
            pendingFailedTranscriptionRetry = retry
            captionPanel.showRetryStatus("转写失败", actionTitle: "重试", autoHideDelay: 10) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.retryFailedTranscription()
                }
            }
        } else {
            captionPanel.showStatus("转写失败", isError: true, autoHideDelay: 1.8)
        }
        statusItem?.button?.title = "NexVoice 出错"
        refreshMenuState()
    }

    private func failedTranscriptionRetrySnapshot() -> FailedTranscriptionRetry? {
        guard let text = latestRecoverableASRText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        let rewriteContext = rewriteContextForCurrentSession ?? VoiceRewriteContext(
            sourceApplicationName: targetApplicationForCurrentSession?.localizedName,
            sourceApplicationBundleIdentifier: targetApplicationForCurrentSession?.bundleIdentifier,
            selectedTextMode: selectedTextContextForCurrentSession?.text.isEmpty == false,
            personalDictionary: VoicePersonalDictionaryStore.load()
        )
        return FailedTranscriptionRetry(
            originalText: text,
            rewriteContext: rewriteContext,
            targetApplication: targetApplicationForCurrentSession
        )
    }

    private func retryFailedTranscription() {
        guard let retry = pendingFailedTranscriptionRetry else { return }
        pendingFailedTranscriptionRetry = nil
        latestRecoverableASRText = retry.originalText
        rewriteContextForCurrentSession = retry.rewriteContext
        targetApplicationForCurrentSession = retry.targetApplication
        didInsertCurrentSession = false
        isCurrentSessionCancelled = false
        isRewritingCurrentSession = false
        rewriteTask?.cancel()
        rewriteTask = nil
        captionPanel.showLoading(
            selectedTextContextForCurrentSession?.text.isEmpty == false ? "AI 处理中" : "AI 整理中",
            anchorRect: selectedTextContextForCurrentSession?.anchorRect
        )
        statusItem?.button?.title = "NexVoice 整理中"
        refreshMenuState()
        insertFinalTextIfNeeded(from: .finalTranscript(retry.originalText))
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
        outputLanguageMenuItem?.title = selectedOutputLanguage == .simplifiedChinese
            ? "输出语言：中文"
            : "输出语言：English"
        outputLanguageMenuItem?.isEnabled = canChangeMode
        chineseOutputMenuItem?.isEnabled = canChangeMode
        englishOutputMenuItem?.isEnabled = canChangeMode
        outputStyleMenuItem?.title = "输出模式：\(selectedRewriteStyle.menuTitle)"
        outputStyleMenuItem?.isEnabled = canChangeMode
        for (style, item) in outputStyleMenuItems {
            item.state = style == selectedRewriteStyle ? .on : .off
            item.isEnabled = canChangeMode
        }
        personalDictionaryMenuItem?.isEnabled = true

        let microphoneAuthorized = permissionService.authorizationStatus() == .authorized
        microphoneMenuItem?.title = microphoneAuthorized ? "麦克风权限已允许" : "申请麦克风权限"
        microphoneMenuItem?.isEnabled = !microphoneAuthorized

        let accessibilityAllowed = textInserter.canPostKeyboardEvents
        accessibilityMenuItem?.title = accessibilityAllowed
            ? "辅助功能权限已允许"
            : VoicePermissionGuidance.accessibility.actionTitle
        accessibilityMenuItem?.isEnabled = !accessibilityAllowed

        let inputMonitoringAllowed = SystemPermissionRequester.hasInputMonitoringPermission
        inputMonitoringMenuItem?.title = inputMonitoringAllowed
            ? "输入监控权限已允许"
            : "申请输入监控权限"
        inputMonitoringMenuItem?.isEnabled = !inputMonitoringAllowed

        let screenRecordingAllowed = SystemPermissionRequester.hasScreenRecordingPermission
        screenRecordingMenuItem?.title = screenRecordingAllowed
            ? "屏幕录制权限已允许"
            : "申请屏幕录制权限"
        screenRecordingMenuItem?.isEnabled = !screenRecordingAllowed
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

    private func rewriteStyle(for context: VoiceRewriteContext) -> VoiceRewriteStyle {
        workflowRewriteStyleStore.style(
            for: context.applicationWorkflow.identifier,
            defaultStyle: selectedRewriteStyle
        )
    }

    private static func loadOutputLanguage() -> VoiceOutputLanguage {
        let rawValue = UserDefaults.standard.string(forKey: "selectedOutputLanguage") ?? ""
        return VoiceOutputLanguage(rawValue: rawValue) ?? .simplifiedChinese
    }

    private static func saveOutputLanguage(_ language: VoiceOutputLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: "selectedOutputLanguage")
    }

    private static func loadRewriteStyle() -> VoiceRewriteStyle {
        let rawValue = UserDefaults.standard.string(forKey: "selectedRewriteStyle") ?? ""
        return VoiceRewriteStyle(rawValue: rawValue) ?? .default
    }

    private static func saveRewriteStyle(_ style: VoiceRewriteStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: "selectedRewriteStyle")
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
