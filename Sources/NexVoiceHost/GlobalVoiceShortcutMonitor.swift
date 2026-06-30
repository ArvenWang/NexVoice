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
    private var pendingShortPressWorkItemID = 0
    private var shortPressTapCount = 0
    private var onTrigger: (() -> Void)?
    private var onDoubleTrigger: (() -> Void)?
    private var onTripleTrigger: (() -> Void)?
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
        onTripleTrigger: @escaping () -> Void,
        shouldDelayShortPressForDoubleTrigger: @escaping () -> Bool,
        onLongPress: @escaping () -> Void,
        onLongPressEnded: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        stop()
        self.shortcut = shortcut
        self.onTrigger = onTrigger
        self.onDoubleTrigger = onDoubleTrigger
        self.onTripleTrigger = onTripleTrigger
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
        logShortcutEvent(
            "monitor_started",
            usesRegisteredHotKey: usesRegisteredHotKey,
            allowsEventMonitorFallback: allowsEventMonitorFallback,
            usesLowLevelKeyboardTapFallback: usesLowLevelKeyboardTapFallback,
            didRegisterHotKey: didRegisterHotKey,
            didStartKeyboardEventTap: didStartKeyboardEventTap
        )

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event, source: "nsevent_global_key")
            }
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event, source: "nsevent_global_flags")
            }
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event, source: "nsevent_local")
            }
            return event
        }

        return didRegisterHotKey && didStartKeyboardEventTap
    }

    func updateShortcut(_ shortcut: VoiceShortcut) {
        self.shortcut = shortcut
        pendingShortPressWorkItem?.cancel()
        pendingShortPressWorkItem = nil
        pendingShortPressWorkItemID = 0
        isPressed = false
        shortPressTapCount = 0
    }

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        if suspended {
            longPressWorkItem?.cancel()
            longPressWorkItem = nil
            pendingShortPressWorkItem?.cancel()
            pendingShortPressWorkItem = nil
            pendingShortPressWorkItemID = 0
            isPressed = false
            didTriggerLongPress = false
            shortPressTapCount = 0
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
        onTripleTrigger = nil
        shouldDelayShortPressForDoubleTrigger = nil
        onLongPress = nil
        onLongPressEnded = nil
        onCancel = nil
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
        pendingShortPressWorkItem?.cancel()
        pendingShortPressWorkItem = nil
        pendingShortPressWorkItemID = 0
        isPressed = false
        didTriggerLongPress = false
        shortPressTapCount = 0
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

    private func handle(_ event: NSEvent, source: String) {
        if shouldLog(event) {
            logKeyboardEvent(event, source: source, matched: shortcutMatches(event))
        }
        guard !isSuspended else {
            if shouldLog(event) {
                logKeyboardEvent(event, source: source, eventName: "keyboard_event_ignored_suspended", matched: false)
            }
            return
        }
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
        if shouldLog(type: type, keyCode: keyCode, flags: flags) {
            logShortcutEvent(
                "keyboard_event_received",
                source: "cg_event_tap",
                keyCode: keyCode,
                eventType: Self.eventTypeName(type),
                flagsRawValue: flags.rawValue,
                matched: shortcutMatches(type: type, keyCode: keyCode, flags: flags)
            )
        }
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
        logShortcutEvent("registered_hotkey_pressed", source: "carbon_hotkey", matched: true)
        beginShortcutPress()
    }

    private func handleRegisteredHotKeyReleased() {
        guard isPressed else { return }
        logShortcutEvent("registered_hotkey_released", source: "carbon_hotkey", matched: true)
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
            pendingShortPressWorkItemID &+= 1
            shortPressTapCount += 1
            if shortPressTapCount > 3 {
                shortPressTapCount = 3
            }
        } else {
            shortPressTapCount = 1
        }
        logShortcutEvent(
            "press_begin",
            isSecondPressForDoubleTrigger: shortPressTapCount > 1,
            didTriggerLongPress: didTriggerLongPress
        )
        longPressWorkItem?.cancel()
        if shortPressTapCount > 1 {
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isPressed, !self.didTriggerLongPress else { return }
                self.didTriggerLongPress = true
                self.logShortcutEvent("long_press_triggered", triggerKind: "long")
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
        let currentPressCount = max(shortPressTapCount, 1)
        isPressed = false
        didTriggerLongPress = false
        logShortcutEvent(
            "press_end",
            isSecondPressForDoubleTrigger: currentPressCount > 1,
            triggerKind: shouldTriggerShortPress
                ? (currentPressCount > 1 ? "double_or_more" : "single")
                : (shouldEndLongPress ? "long_end" : "none")
        )
        if shouldTriggerShortPress {
            handleShortPressEnded(pressCount: currentPressCount)
        } else if shouldEndLongPress {
            logShortcutEvent("long_press_ended", triggerKind: "long_end")
            onLongPressEnded?()
        }
    }

    private func handleShortPressEnded(pressCount: Int) {
        if pressCount >= 3 {
            shortPressTapCount = 0
            logShortcutEvent("triple_trigger_fired", triggerKind: "triple")
            onTripleTrigger?()
            return
        }

        guard shouldDelayShortPressForDoubleTrigger?() == true else {
            if pressCount >= 2 {
                logShortcutEvent("double_trigger_fired", triggerKind: "double")
                onDoubleTrigger?()
            } else {
                logShortcutEvent("single_trigger_fired", shouldDelayShortPress: false, triggerKind: "single")
                onTrigger?()
            }
            shortPressTapCount = 0
            return
        }

        if pressCount == 2 {
            logShortcutEvent("double_or_triple_candidate", shouldDelayShortPress: true, triggerKind: "double_or_more")
        } else {
            logShortcutEvent("single_trigger_deferred", shouldDelayShortPress: true, triggerKind: "single")
        }
        let scheduledShortPressWorkItemID = pendingShortPressWorkItemID &+ 1
        pendingShortPressWorkItemID = scheduledShortPressWorkItemID
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.pendingShortPressWorkItem != nil,
                      scheduledShortPressWorkItemID == self.pendingShortPressWorkItemID else {
                    return
                }
                self.pendingShortPressWorkItem = nil
                let finalPressCount = self.shortPressTapCount
                self.shortPressTapCount = 0
                if finalPressCount >= 3 {
                    self.logShortcutEvent("triple_trigger_fired", triggerKind: "triple")
                    self.onTripleTrigger?()
                } else if finalPressCount == 2 {
                    self.logShortcutEvent("double_trigger_deferred_fired", triggerKind: "double")
                    self.onDoubleTrigger?()
                } else {
                    self.logShortcutEvent("single_trigger_deferred_fired", shouldDelayShortPress: true, triggerKind: "single")
                    self.onTrigger?()
                }
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

    private func shouldLog(_ event: NSEvent) -> Bool {
        if event.keyCode == Self.escapeKeyCode { return true }
        switch shortcut {
        case .rightOptionKey:
            return event.keyCode == VoiceShortcut.rightOptionKeyCode || event.modifierFlags.contains(.option)
        case .functionKey:
            return event.type == .flagsChanged && event.modifierFlags.contains(.function)
        case .keyCombo(let keyCode, _):
            return event.keyCode == keyCode
        }
    }

    private func shouldLog(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch shortcut {
        case .rightOptionKey:
            return keyCode == VoiceShortcut.rightOptionKeyCode || flags.contains(.maskAlternate)
        case .functionKey:
            return type == .flagsChanged && flags.contains(.maskSecondaryFn)
        case .keyCombo(let expectedKeyCode, _):
            return keyCode == expectedKeyCode
        }
    }

    private func shortcutMatches(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            return shortcut.matchesKeyEvent(
                keyCode: event.keyCode,
                flags: Self.cgFlags(from: event.modifierFlags)
            )
        case .keyUp:
            return shortcut.matchesKeyReleaseEvent(keyCode: event.keyCode)
        case .flagsChanged:
            let flags = Self.cgFlags(from: event.modifierFlags)
            return shortcut.matchesModifierKeyPress(keyCode: event.keyCode, flags: flags)
                || shortcut.matchesModifierKeyRelease(keyCode: event.keyCode, flags: flags)
        default:
            return false
        }
    }

    private func shortcutMatches(type: CGEventType, keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch type {
        case .keyDown:
            return shortcut.matchesKeyEvent(keyCode: keyCode, flags: flags)
        case .keyUp:
            return shortcut.matchesKeyReleaseEvent(keyCode: keyCode)
        case .flagsChanged:
            return shortcut.matchesModifierKeyPress(keyCode: keyCode, flags: flags)
                || shortcut.matchesModifierKeyRelease(keyCode: keyCode, flags: flags)
        default:
            return false
        }
    }

    private func logKeyboardEvent(
        _ event: NSEvent,
        source: String,
        eventName: String = "keyboard_event_received",
        matched: Bool
    ) {
        let delayMs = Int(max(0, (ProcessInfo.processInfo.systemUptime - event.timestamp) * 1_000).rounded())
        logShortcutEvent(
            eventName,
            source: source,
            keyCode: event.keyCode,
            eventType: Self.eventTypeName(event.type),
            flagsRawValue: Self.cgFlags(from: event.modifierFlags).rawValue,
            eventTimestampSeconds: event.timestamp,
            deliveryDelayMs: delayMs,
            matched: matched
        )
    }

    private func logShortcutEvent(
        _ event: String,
        source: String? = nil,
        keyCode: UInt16? = nil,
        eventType: String? = nil,
        flagsRawValue: UInt64? = nil,
        eventTimestampSeconds: Double? = nil,
        deliveryDelayMs: Int? = nil,
        matched: Bool? = nil,
        isSecondPressForDoubleTrigger: Bool? = nil,
        didTriggerLongPress: Bool? = nil,
        shouldDelayShortPress: Bool? = nil,
        triggerKind: String? = nil,
        usesRegisteredHotKey: Bool? = nil,
        allowsEventMonitorFallback: Bool? = nil,
        usesLowLevelKeyboardTapFallback: Bool? = nil,
        didRegisterHotKey: Bool? = nil,
        didStartKeyboardEventTap: Bool? = nil
    ) {
        let application = NSWorkspace.shared.frontmostApplication
        Task {
            await ShortcutDiagnosticsLogger.shared.log(
                ShortcutDiagnosticEvent(
                    event: event,
                    source: source,
                    shortcut: shortcut,
                    keyCode: keyCode,
                    eventType: eventType,
                    flagsRawValue: flagsRawValue,
                    eventTimestampSeconds: eventTimestampSeconds,
                    deliveryDelayMs: deliveryDelayMs,
                    matched: matched,
                    isPressed: isPressed,
                    isSuspended: isSuspended,
                    isSecondPressForDoubleTrigger: isSecondPressForDoubleTrigger,
                    didTriggerLongPress: didTriggerLongPress,
                    shouldDelayShortPress: shouldDelayShortPress,
                    triggerKind: triggerKind,
                    appName: application?.localizedName,
                    bundleIdentifier: application?.bundleIdentifier,
                    mouseLocation: NSEvent.mouseLocation,
                    usesRegisteredHotKey: usesRegisteredHotKey,
                    allowsEventMonitorFallback: allowsEventMonitorFallback,
                    usesLowLevelKeyboardTapFallback: usesLowLevelKeyboardTapFallback,
                    didRegisterHotKey: didRegisterHotKey,
                    didStartKeyboardEventTap: didStartKeyboardEventTap
                )
            )
        }
    }

    private static func eventTypeName(_ type: NSEvent.EventType) -> String {
        switch type {
        case .keyDown: return "key_down"
        case .keyUp: return "key_up"
        case .flagsChanged: return "flags_changed"
        default: return String(describing: type)
        }
    }

    private static func eventTypeName(_ type: CGEventType) -> String {
        switch type {
        case .keyDown: return "key_down"
        case .keyUp: return "key_up"
        case .flagsChanged: return "flags_changed"
        default: return String(describing: type)
        }
    }
}
