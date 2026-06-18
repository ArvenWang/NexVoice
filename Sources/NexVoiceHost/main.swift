import AppKit
import Foundation
import NexVoiceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var shortcutMenuItem: NSMenuItem?
    private var shortcutSettingsMenuItem: NSMenuItem?
    private var asrMenuItem: NSMenuItem?
    private var chineseMenuItem: NSMenuItem?
    private var englishMenuItem: NSMenuItem?
    private var accessibilityMenuItem: NSMenuItem?
    private let permissionService = MicrophonePermissionService()
    private let transcriptionService = TencentCloudRealtimeTranscriptionService()
    private let captionPanel = VoiceCaptionPanelController()
    private let textInserter = FocusedTextInserter()
    private let shortcutStore = VoiceShortcutStore()
    private let shortcutMonitor = GlobalVoiceShortcutMonitor()
    private var shortcutSettingsWindowController: VoiceShortcutSettingsWindowController?
    private var selectedLanguage = SpeechRecognitionLanguage.simplifiedChinese
    private var voiceShortcut: VoiceShortcut = .default
    private var targetApplicationForCurrentSession: NSRunningApplication?
    private var didInsertCurrentSession = false
    private var insertedTextPreview: String?
    private var permissionRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        voiceShortcut = shortcutStore.load()
        configureStatusItem()
        captionPanel.reset(language: selectedLanguage, shortcut: voiceShortcut)
        startShortcutMonitor()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "NexVoice"

        let menu = NSMenu()
        let shortcutItem = NSMenuItem(title: "快捷键：\(voiceShortcut.displayTitle)", action: nil, keyEquivalent: "")
        let settingsItem = NSMenuItem(title: "设置快捷键...", action: #selector(openShortcutSettings), keyEquivalent: "")
        let chineseItem = NSMenuItem(title: "语言：中文", action: #selector(selectChinese), keyEquivalent: "")
        let englishItem = NSMenuItem(title: "语言：English", action: #selector(selectEnglish), keyEquivalent: "")
        let accessibilityItem = NSMenuItem(title: VoicePermissionGuidance.accessibility.actionTitle, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        let localASRItem = NSMenuItem(title: "ASR：腾讯云实时 ASR 大模型", action: nil, keyEquivalent: "")

        shortcutItem.isEnabled = false
        localASRItem.isEnabled = false

        menu.addItem(shortcutItem)
        menu.addItem(localASRItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(chineseItem)
        menu.addItem(englishItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "申请麦克风权限", action: #selector(requestMicrophonePermission), keyEquivalent: ""))
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 NexVoice", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        shortcutMenuItem = shortcutItem
        shortcutSettingsMenuItem = settingsItem
        asrMenuItem = localASRItem
        chineseMenuItem = chineseItem
        englishMenuItem = englishItem
        accessibilityMenuItem = accessibilityItem

        item.menu = menu
        statusItem = item
        refreshMenuState()
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
            }
        )
        refreshMenuState()
    }

    @objc private func selectChinese() {
        guard transcriptionService.state == .idle else { return }
        selectedLanguage = .simplifiedChinese
        captionPanel.reset(language: selectedLanguage, shortcut: voiceShortcut)
        refreshMenuState()
    }

    @objc private func selectEnglish() {
        guard transcriptionService.state == .idle else { return }
        selectedLanguage = .englishUS
        captionPanel.reset(language: selectedLanguage, shortcut: voiceShortcut)
        refreshMenuState()
    }

    @objc private func openShortcutSettings() {
        let controller = VoiceShortcutSettingsWindowController(shortcut: voiceShortcut) { [weak self] shortcut in
            guard let self else { return }
            self.voiceShortcut = shortcut
            self.shortcutStore.save(shortcut)
            self.shortcutMonitor.updateShortcut(shortcut)
            self.captionPanel.reset(language: self.selectedLanguage, shortcut: shortcut)
            self.refreshMenuState()
        }
        shortcutSettingsWindowController = controller
        controller.showWindow(nil)
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
        targetApplicationForCurrentSession = NSWorkspace.shared.frontmostApplication
        didInsertCurrentSession = false
        insertedTextPreview = nil

        guard permissionService.authorizationStatus() == .authorized else {
            captionPanel.showPreparing(language: selectedLanguage, shortcut: voiceShortcut)
            requestMicrophonePermission()
            return
        }
        captionPanel.reset(language: selectedLanguage, shortcut: voiceShortcut)
        captionPanel.showOverlay(language: selectedLanguage, shortcut: voiceShortcut)
        do {
            try transcriptionService.start(
                configuration: LocalWhisperTranscriptionConfiguration(language: selectedLanguage)
            ) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleTranscriptionEvent(event)
                }
            }
            statusItem?.button?.title = "NexVoice 听写中"
            refreshMenuState()
        } catch {
            captionPanel.apply(.failed(message: error.localizedDescription))
            showNotification(title: "语音输入启动失败", body: error.localizedDescription)
        }
    }

    private func handleTranscriptionEvent(_ event: VoiceRealtimeEvent) {
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
            statusItem?.button?.title = "NexVoice 出错"
            refreshMenuState()
            showNotification(title: "腾讯云转写失败", body: messageForFailedEvent(event))
        case .partialTranslation, .finalTranslation, .latencyUpdated, .audioLevelUpdated:
            break
        }
    }

    private func insertFinalTextIfNeeded(from event: VoiceRealtimeEvent) {
        guard !didInsertCurrentSession, let text = VoiceFinalTextPolicy.insertionText(from: event) else { return }
        didInsertCurrentSession = true
        insertedTextPreview = text

        do {
            try textInserter.insert(text, into: targetApplicationForCurrentSession)
            captionPanel.showInsertedText(text)
        } catch {
            captionPanel.showOutputFailed(error.localizedDescription)
            showNotification(title: "输入失败", body: error.localizedDescription)
        }
    }

    private func stopTranscription() {
        captionPanel.hideRecordingOverlay()
        transcriptionService.finish()
        statusItem?.button?.title = "NexVoice 等待腾讯云结果"
        refreshMenuState()
    }

    private func messageForFailedEvent(_ event: VoiceRealtimeEvent) -> String {
        if case .failed(let message) = event {
            return message
        }
        return "请稍后再试。"
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

        chineseMenuItem?.state = selectedLanguage == .simplifiedChinese ? .on : .off
        englishMenuItem?.state = selectedLanguage == .englishUS ? .on : .off
        chineseMenuItem?.isEnabled = transcriptionService.state == .idle
        englishMenuItem?.isEnabled = transcriptionService.state == .idle

        accessibilityMenuItem?.title = textInserter.canPostKeyboardEvents
            ? "辅助功能权限已允许"
            : VoicePermissionGuidance.accessibility.actionTitle
    }

    private func cloudASRMenuTitle() -> String {
        do {
            let credentials = try TencentCloudASRCredentialStore.load()
            if credentials.isComplete {
                return "ASR：腾讯云实时 ASR 大模型"
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
