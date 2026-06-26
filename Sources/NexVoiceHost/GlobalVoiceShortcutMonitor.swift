import AppKit
import Carbon
import CoreGraphics
import NexVoiceCore

@MainActor
final class GlobalVoiceShortcutMonitor {
    private var globalKeyMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localEventMonitor: Any?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonEventHandlerRef: EventHandlerRef?
    private let keyboardEventTap = GlobalKeyboardEventTap()
    private var shortcut: VoiceShortcut = .default
    private var usesRegisteredHotKey = false
    private var allowsEventMonitorFallback = false
    private var usesLowLevelKeyboardTapFallback = false
    private var isPressed = false
    private var isCancelPressed = false
    private var didTriggerLongPress = false
    private var longPressWorkItem: DispatchWorkItem?
    private var pendingShortPressWorkItem: DispatchWorkItem?
    private var isSecondPressForDoubleTrigger = false
    private var onTrigger: (() -> Void)?
    private var onDoubleTrigger: (() -> Void)?
    private var shouldDelayShortPressForDoubleTrigger: (() -> Bool)?
    private var onLongPress: (() -> Void)?
    private var onLongPressEnded: (() -> Void)?
    private var onCancel: (() -> Void)?
    private var isSuspended = false

    @discardableResult
    func start(
        shortcut: VoiceShortcut,
        onTrigger: @escaping () -> Void,
        onDoubleTrigger: @escaping () -> Void,
        shouldDelayShortPressForDoubleTrigger: @escaping () -> Bool,
        onLongPress: @escaping () -> Void,
        onLongPressEnded: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        self.onDoubleTrigger = onDoubleTrigger
        self.shouldDelayShortPressForDoubleTrigger = shouldDelayShortPressForDoubleTrigger
        self.onLongPress = onLongPress
        self.onLongPressEnded = onLongPressEnded
        self.onCancel = onCancel

        usesRegisteredHotKey = VoiceShortcutGlobalCapturePolicy.strategy(for: shortcut) == .registeredHotKey
        allowsEventMonitorFallback = VoiceShortcutGlobalCapturePolicy.allowsEventMonitorFallback(for: shortcut)
        usesLowLevelKeyboardTapFallback = VoiceShortcutGlobalCapturePolicy
            .usesLowLevelKeyboardTapFallback(for: shortcut)
        let didRegisterHotKey = usesRegisteredHotKey
            ? registerCarbonHotKey(for: shortcut)
            : true
        let didStartKeyboardEventTap = usesLowLevelKeyboardTapFallback
            ? startKeyboardEventTap()
            : true

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

        return didRegisterHotKey && didStartKeyboardEventTap
    }

    func updateShortcut(_ shortcut: VoiceShortcut) {
        self.shortcut = shortcut
        pendingShortPressWorkItem?.cancel()
        pendingShortPressWorkItem = nil
        isPressed = false
        isSecondPressForDoubleTrigger = false
    }

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        if suspended {
            longPressWorkItem?.cancel()
            longPressWorkItem = nil
            pendingShortPressWorkItem?.cancel()
            pendingShortPressWorkItem = nil
            isPressed = false
            didTriggerLongPress = false
            isSecondPressForDoubleTrigger = false
            isCancelPressed = false
        }
    }

    func stop() {
        unregisterCarbonHotKey()
        keyboardEventTap.stop()
        removeMonitor(&globalKeyMonitor)
        removeMonitor(&globalFlagsMonitor)
        removeMonitor(&localEventMonitor)
        onTrigger = nil
        onDoubleTrigger = nil
        shouldDelayShortPressForDoubleTrigger = nil
        onLongPress = nil
        onLongPressEnded = nil
        onCancel = nil
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        pendingShortPressWorkItem?.cancel()
        pendingShortPressWorkItem = nil
        isPressed = false
        didTriggerLongPress = false
        isSecondPressForDoubleTrigger = false
        isCancelPressed = false
        usesRegisteredHotKey = false
        allowsEventMonitorFallback = false
        usesLowLevelKeyboardTapFallback = false
    }

    private func removeMonitor(_ monitor: inout Any?) {
        guard let currentMonitor = monitor else { return }
        NSEvent.removeMonitor(currentMonitor)
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard !isSuspended else { return }
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

    private func handleKeyboardTap(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) {
        switch type {
        case .keyDown:
            handleKeyDown(keyCode: keyCode, flags: flags)
        case .keyUp:
            handleKeyUp(keyCode: keyCode)
        case .flagsChanged:
            handleFlagsChanged(keyCode: keyCode, flags: flags)
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
        guard allowsEventMonitorFallback else { return }

        handleKeyDown(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        )
    }

    private func handleKeyUp(_ event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            isCancelPressed = false
            return
        }
        guard allowsEventMonitorFallback else { return }

        handleKeyUp(keyCode: event.keyCode)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard allowsEventMonitorFallback else { return }
        handleFlagsChanged(
            keyCode: event.keyCode,
            flags: Self.cgFlags(from: event.modifierFlags)
        )
    }

    private func handleKeyDown(keyCode: UInt16, flags: CGEventFlags) {
        guard shortcut.matchesKeyEvent(keyCode: keyCode, flags: flags), !isPressed else {
            return
        }
        beginShortcutPress()
    }

    private func handleKeyUp(keyCode: UInt16) {
        guard isPressed, shortcut.matchesKeyReleaseEvent(keyCode: keyCode) else {
            return
        }
        endShortcutPress()
    }

    private func handleFlagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        if shortcut.matchesModifierKeyPress(keyCode: keyCode, flags: flags), !isPressed {
            beginShortcutPress()
        } else if shortcut.matchesModifierKeyRelease(keyCode: keyCode, flags: flags) {
            endShortcutPress()
        }
    }

    private func handleRegisteredHotKeyPressed() {
        guard !isPressed else { return }
        beginShortcutPress()
    }

    private func handleRegisteredHotKeyReleased() {
        guard isPressed else { return }
        endShortcutPress()
    }

    private func registerCarbonHotKey(for shortcut: VoiceShortcut) -> Bool {
        guard case .keyCombo(let keyCode, let modifiers) = shortcut else { return false }
        unregisterCarbonHotKey()

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.carbonHotKeyHandler,
            eventTypes.count,
            &eventTypes,
            selfPointer,
            &carbonEventHandlerRef
        )
        guard handlerStatus == noErr else {
            return false
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.carbonHotKeySignature,
            id: Self.carbonHotKeyID
        )
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            Self.carbonModifierFlags(from: modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &carbonHotKeyRef
        )
        if registerStatus != noErr {
            unregisterCarbonHotKey()
            return false
        }
        return true
    }

    private func startKeyboardEventTap() -> Bool {
        keyboardEventTap.start { [weak self] type, keyCode, flags in
            self?.handleKeyboardTap(type: type, keyCode: keyCode, flags: flags)
        }
    }

    private func unregisterCarbonHotKey() {
        if let carbonHotKeyRef {
            UnregisterEventHotKey(carbonHotKeyRef)
            self.carbonHotKeyRef = nil
        }
        if let carbonEventHandlerRef {
            RemoveEventHandler(carbonEventHandlerRef)
            self.carbonEventHandlerRef = nil
        }
    }

    private func beginShortcutPress() {
        isPressed = true
        didTriggerLongPress = false
        if pendingShortPressWorkItem != nil {
            pendingShortPressWorkItem?.cancel()
            pendingShortPressWorkItem = nil
            isSecondPressForDoubleTrigger = true
        } else {
            isSecondPressForDoubleTrigger = false
        }
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
        let shouldEndLongPress = isPressed && didTriggerLongPress
        isPressed = false
        didTriggerLongPress = false
        let isDoubleTrigger = isSecondPressForDoubleTrigger
        isSecondPressForDoubleTrigger = false
        if shouldTriggerShortPress {
            handleShortPressEnded(isDoubleTrigger: isDoubleTrigger)
        } else if shouldEndLongPress {
            onLongPressEnded?()
        }
    }

    private func handleShortPressEnded(isDoubleTrigger: Bool) {
        if isDoubleTrigger {
            onDoubleTrigger?()
            return
        }

        guard shouldDelayShortPressForDoubleTrigger?() == true else {
            onTrigger?()
            return
        }

        pendingShortPressWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.pendingShortPressWorkItem != nil else { return }
                self.pendingShortPressWorkItem = nil
                self.onTrigger?()
            }
        }
        pendingShortPressWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTriggerInterval, execute: workItem)
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

    private static func carbonModifierFlags(from modifiers: Set<VoiceShortcutModifier>) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    private static let carbonHotKeySignature: OSType = 0x4E585653
    private static let carbonHotKeyID: UInt32 = 1
    private static let carbonHotKeyHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }
        let monitor = Unmanaged<GlobalVoiceShortcutMonitor>
            .fromOpaque(userData)
            .takeUnretainedValue()
        let eventKind = GetEventKind(event)
        Task { @MainActor in
            if eventKind == UInt32(kEventHotKeyPressed) {
                monitor.handleRegisteredHotKeyPressed()
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                monitor.handleRegisteredHotKeyReleased()
            }
        }
        return noErr
    }

    private static let escapeKeyCode: UInt16 = 53
    private static let longPressThreshold: TimeInterval = 0.55
    private static let doubleTriggerInterval: TimeInterval = 0.50

    private static func isEscapeCancel(_ event: NSEvent) -> Bool {
        guard event.keyCode == escapeKeyCode else { return false }
        return event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty
    }
}
