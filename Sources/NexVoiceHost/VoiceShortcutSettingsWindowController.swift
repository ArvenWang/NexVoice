import AppKit
import CoreGraphics
import NexVoiceCore

@MainActor
final class VoiceShortcutSettingsWindowController: NSWindowController {
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "点击录制后，按右 Alt 或任意快捷键。")
    private let recordButton = NSButton(title: "录制新快捷键", target: nil, action: nil)
    private let resetButton = NSButton(title: "恢复右 Alt", target: nil, action: nil)
    private var localMonitor: Any?
    private var shortcut: VoiceShortcut
    private let onShortcutChanged: (VoiceShortcut) -> Void

    init(shortcut: VoiceShortcut, onShortcutChanged: @escaping (VoiceShortcut) -> Void) {
        self.shortcut = shortcut
        self.onShortcutChanged = onShortcutChanged
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NexVoice 快捷键"
        window.isReleasedWhenClosed = false
        super.init(window: window)
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
        hintLabel.stringValue = "正在录制：按右 Alt，或按下一个快捷键组合。"
        recordButton.isEnabled = false
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged,
               event.keyCode == VoiceShortcut.rightOptionKeyCode,
               event.modifierFlags.contains(.option) {
                self.applyShortcut(.rightOptionKey)
                return nil
            }
            if event.type == .keyDown {
                let modifiers = Self.modifiers(from: event.modifierFlags)
                self.applyShortcut(.keyCombo(keyCode: event.keyCode, modifiers: modifiers))
                return nil
            }
            return event
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
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        recordButton.isEnabled = true
    }

    private func refresh() {
        shortcutLabel.stringValue = shortcut.displayTitle
        hintLabel.stringValue = "当前快捷键：\(shortcut.displayTitle)。按一次开始，再按一次结束。"
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<VoiceShortcutModifier> {
        var modifiers: Set<VoiceShortcutModifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }
}
