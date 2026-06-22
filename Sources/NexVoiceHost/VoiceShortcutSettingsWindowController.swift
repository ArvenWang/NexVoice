import AppKit
import CoreGraphics
import NexVoiceCore

@MainActor
final class VoiceShortcutSettingsWindowController: NSWindowController {
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "点击录制后，按右 Alt 或带修饰键的快捷键。")
    private let recordButton = NSButton(title: "录制新快捷键", target: nil, action: nil)
    private let resetButton = NSButton(title: "恢复右 Alt", target: nil, action: nil)
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var isRecording = false
    private var shortcut: VoiceShortcut
    private let onShortcutChanged: (VoiceShortcut) -> Void
    private let onRecordingStateChanged: (Bool) -> Void

    init(
        shortcut: VoiceShortcut,
        onShortcutChanged: @escaping (VoiceShortcut) -> Void,
        onRecordingStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.shortcut = shortcut
        self.onShortcutChanged = onShortcutChanged
        self.onRecordingStateChanged = onRecordingStateChanged
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NexVoice 快捷键"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "语音输入快捷键")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        shortcutLabel.font = .monospacedSystemFont(ofSize: 24, weight: .semibold)
        shortcutLabel.textColor = .labelColor

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabelColor

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        recordButton.target = self
        recordButton.action = #selector(beginRecording)
        resetButton.target = self
        resetButton.action = #selector(resetShortcut)
        buttonRow.addArrangedSubview(recordButton)
        buttonRow.addArrangedSubview(resetButton)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(shortcutLabel)
        stack.addArrangedSubview(hintLabel)
        stack.addArrangedSubview(buttonRow)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])
    }

    @objc private func beginRecording() {
        stopRecording()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hintLabel.stringValue = "正在录制：按右 Alt，或按 Control / Option / Command / Shift + 一个按键。"
        recordButton.isEnabled = false
        isRecording = true
        onRecordingStateChanged(true)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if self.applyRecordingEvent(event) {
                return nil
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.applyRecordingEvent(event)
            }
        }
    }

    @objc private func resetShortcut() {
        applyShortcut(.default)
    }

    private func applyShortcut(_ shortcut: VoiceShortcut) {
        self.shortcut = shortcut
        onShortcutChanged(shortcut)
        stopRecording()
        refresh()
    }

    private func stopRecording() {
        let wasRecording = isRecording
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil
        isRecording = false
        recordButton.isEnabled = true
        if wasRecording {
            onRecordingStateChanged(false)
        }
    }

    @discardableResult
    private func applyRecordingEvent(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        guard let eventType = Self.recordingEventType(from: event.type),
              let shortcut = VoiceShortcutRecordingPolicy.shortcut(
                for: eventType,
                keyCode: event.keyCode,
                flags: Self.cgFlags(from: event.modifierFlags)
              ) else {
            return false
        }
        applyShortcut(shortcut)
        return true
    }

    private func refresh() {
        shortcutLabel.stringValue = shortcut.displayTitle
        hintLabel.stringValue = "当前快捷键：\(shortcut.displayTitle)。按一次开始，再按一次结束。"
    }

    private static func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private static func recordingEventType(from eventType: NSEvent.EventType) -> VoiceShortcutRecordingEventType? {
        switch eventType {
        case .keyDown:
            return .keyDown
        case .flagsChanged:
            return .flagsChanged
        default:
            return nil
        }
    }
}

extension VoiceShortcutSettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopRecording()
    }
}
