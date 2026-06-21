import AppKit
import CoreGraphics
import NexVoiceCore

@MainActor
final class GlobalVoiceShortcutMonitor {
    private var globalKeyMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localEventMonitor: Any?
    private var shortcut: VoiceShortcut = .default
    private var isPressed = false
    private var isCancelPressed = false
    private var didTriggerLongPress = false
    private var longPressWorkItem: DispatchWorkItem?
    private var onTrigger: (() -> Void)?
    private var onLongPress: (() -> Void)?
    private var onCancel: (() -> Void)?

    @discardableResult
    func start(
        shortcut: VoiceShortcut,
        onTrigger: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        self.onLongPress = onLongPress
        self.onCancel = onCancel

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
            return event
        }

        return true
    }

    func updateShortcut(_ shortcut: VoiceShortcut) {
        self.shortcut = shortcut
        isPressed = false
    }

    func stop() {
        removeMonitor(&globalKeyMonitor)
        removeMonitor(&globalFlagsMonitor)
        removeMonitor(&localEventMonitor)
        onTrigger = nil
        onLongPress = nil
        onCancel = nil
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        isPressed = false
        didTriggerLongPress = false
        isCancelPressed = false
    }

    private func removeMonitor(_ monitor: inout Any?) {
        guard let currentMonitor = monitor else { return }
        NSEvent.removeMonitor(currentMonitor)
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            handleKeyDown(event)
        case .keyUp:
            handleKeyUp(event)
        case .flagsChanged:
            handleFlagsChanged(event)
        default:
            break
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if Self.isEscapeCancel(event), !isCancelPressed {
            isCancelPressed = true
            onCancel?()
            return
        }

        guard shortcut.matchesKeyEvent(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        ), !isPressed else {
            return
        }
        beginShortcutPress()
    }

    private func handleKeyUp(_ event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            isCancelPressed = false
            return
        }

        guard shortcut.matchesKeyEvent(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        ) else {
            return
        }
        endShortcutPress()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = Self.cgFlags(from: event.modifierFlags)
        if shortcut.matchesModifierKeyPress(keyCode: event.keyCode, flags: flags), !isPressed {
            beginShortcutPress()
        } else if shortcut.matchesModifierKeyRelease(keyCode: event.keyCode, flags: flags) {
            endShortcutPress()
        }
    }

    private func beginShortcutPress() {
        isPressed = true
        didTriggerLongPress = false
        longPressWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isPressed, !self.didTriggerLongPress else { return }
                self.didTriggerLongPress = true
                self.onLongPress?()
            }
        }
        longPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.longPressThreshold, execute: workItem)
    }

    private func endShortcutPress() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        let shouldTriggerShortPress = isPressed && !didTriggerLongPress
        isPressed = false
        didTriggerLongPress = false
        if shouldTriggerShortPress {
            onTrigger?()
        }
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

    private static let escapeKeyCode: UInt16 = 53
    private static let longPressThreshold: TimeInterval = 0.55

    private static func isEscapeCancel(_ event: NSEvent) -> Bool {
        guard event.keyCode == escapeKeyCode else { return false }
        return event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty
    }
}
