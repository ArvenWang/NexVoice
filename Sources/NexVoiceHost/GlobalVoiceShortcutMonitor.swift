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
    private var onTrigger: (() -> Void)?

    @discardableResult
    func start(
        shortcut: VoiceShortcut,
        onTrigger: @escaping () -> Void
    ) -> Bool {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger

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
        isPressed = false
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
        guard shortcut.matchesKeyEvent(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        ), !isPressed else {
            return
        }
        isPressed = true
        onTrigger?()
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard shortcut.matchesKeyEvent(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        ) else {
            return
        }
        isPressed = false
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = Self.cgFlags(from: event.modifierFlags)
        if shortcut.matchesModifierKeyPress(keyCode: event.keyCode, flags: flags), !isPressed {
            isPressed = true
            onTrigger?()
        } else if shortcut.matchesModifierKeyRelease(keyCode: event.keyCode, flags: flags) {
            isPressed = false
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
}
