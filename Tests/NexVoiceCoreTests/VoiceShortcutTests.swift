import CoreGraphics
import Foundation
import Testing
@testable import NexVoiceCore

@Test func defaultVoiceShortcutIsFunctionKey() {
    #expect(VoiceShortcut.default == .rightOptionKey)
    #expect(VoiceShortcut.default.displayTitle == "右 Alt")
}

@Test func rightOptionShortcutRecognizesOnlyRightOptionPress() {
    #expect(VoiceShortcut.rightOptionKey.matchesModifierKeyPress(keyCode: 0x3D, flags: [.maskAlternate]))
    #expect(!VoiceShortcut.rightOptionKey.matchesModifierKeyPress(keyCode: 0x3A, flags: [.maskAlternate]))
    #expect(!VoiceShortcut.rightOptionKey.matchesModifierKeyPress(keyCode: 0x3D, flags: []))
}

@Test func rightOptionShortcutRecognizesOnlyRightOptionRelease() {
    #expect(VoiceShortcut.rightOptionKey.matchesModifierKeyRelease(keyCode: 0x3D, flags: []))
    #expect(!VoiceShortcut.rightOptionKey.matchesModifierKeyRelease(keyCode: 0x3A, flags: []))
    #expect(!VoiceShortcut.rightOptionKey.matchesModifierKeyRelease(keyCode: 0x3D, flags: [.maskAlternate]))
}

@Test func voiceShortcutDisplayTitleIncludesModifiersAndKeyCode() {
    let shortcut = VoiceShortcut.keyCombo(
        keyCode: 49,
        modifiers: [.command, .shift]
    )

    #expect(shortcut.displayTitle == "⇧⌘ Space")
}

@Test func voiceShortcutDisplayTitleOmitsLeadingSpaceForBareKey() {
    let shortcut = VoiceShortcut.keyCombo(keyCode: 40, modifiers: [])

    #expect(shortcut.displayTitle == "K")
}

@Test func voiceShortcutDisplayTitleNamesFunctionKeys() {
    let shortcut = VoiceShortcut.keyCombo(keyCode: 64, modifiers: [])

    #expect(shortcut.displayTitle == "F17")
}

@Test func voiceShortcutRoundTripsThroughUserDefaultsPayload() throws {
    let shortcut = VoiceShortcut.keyCombo(keyCode: 0, modifiers: [.option, .control])

    let data = try JSONEncoder().encode(shortcut)
    let decoded = try JSONDecoder().decode(VoiceShortcut.self, from: data)

    #expect(decoded == shortcut)
}

@Test func storeMigratesLegacyFunctionDefaultToRightOption() {
    let suiteName = "VoiceShortcutTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    let store = VoiceShortcutStore(defaults: defaults)
    let legacyData = try! JSONEncoder().encode(VoiceShortcut.functionKey)
    defaults.set(legacyData, forKey: "voiceShortcut")

    #expect(store.load() == .rightOptionKey)
}

@Test func functionShortcutRecognizesSecondaryFunctionFlag() {
    #expect(VoiceShortcut.functionKey.matchesModifierKeyPress(keyCode: 0, flags: [.maskSecondaryFn]))
    #expect(!VoiceShortcut.functionKey.matchesModifierKeyPress(keyCode: 0, flags: []))
}

@Test func keyComboRequiresExactModifierSet() {
    let shortcut = VoiceShortcut.keyCombo(keyCode: 49, modifiers: [.control])

    #expect(shortcut.matchesKeyEvent(keyCode: 49, flags: [.maskControl]))
    #expect(!shortcut.matchesKeyEvent(keyCode: 49, flags: [.maskControl, .maskShift]))
    #expect(!shortcut.matchesKeyEvent(keyCode: 49, flags: []))
}

@Test func keyComboReleaseMatchesKeyCodeWithoutRequiringModifierFlags() {
    let shortcut = VoiceShortcut.keyCombo(keyCode: 49, modifiers: [.control])

    #expect(shortcut.matchesKeyReleaseEvent(keyCode: 49))
    #expect(!shortcut.matchesKeyReleaseEvent(keyCode: 36))
}

@Test func recordingPolicyCapturesRightOptionOnModifierPress() {
    let shortcut = VoiceShortcutRecordingPolicy.shortcut(
        for: .flagsChanged,
        keyCode: VoiceShortcut.rightOptionKeyCode,
        flags: [.maskAlternate]
    )

    #expect(shortcut == .rightOptionKey)
}

@Test func recordingPolicyIgnoresRightOptionRelease() {
    let shortcut = VoiceShortcutRecordingPolicy.shortcut(
        for: .flagsChanged,
        keyCode: VoiceShortcut.rightOptionKeyCode,
        flags: []
    )

    #expect(shortcut == nil)
}

@Test func recordingPolicyCapturesKeyComboFromKeyDown() {
    let shortcut = VoiceShortcutRecordingPolicy.shortcut(
        for: .keyDown,
        keyCode: 49,
        flags: [.maskControl, .maskShift]
    )

    #expect(shortcut == .keyCombo(keyCode: 49, modifiers: [.control, .shift]))
}

@Test func recordingPolicyCapturesBareExternalKeyFromKeyDown() {
    let shortcut = VoiceShortcutRecordingPolicy.shortcut(
        for: .keyDown,
        keyCode: 40,
        flags: []
    )

    #expect(shortcut == .keyCombo(keyCode: 40, modifiers: []))
}

@Test func keyCombosUseRegisteredGlobalHotKeyStrategy() {
    #expect(VoiceShortcutGlobalCapturePolicy.strategy(for: .rightOptionKey) == .eventMonitor)
    #expect(
        VoiceShortcutGlobalCapturePolicy.strategy(
            for: .keyCombo(keyCode: 49, modifiers: [.control])
        ) == .registeredHotKey
    )
    #expect(
        VoiceShortcutGlobalCapturePolicy.strategy(
            for: .keyCombo(keyCode: 40, modifiers: [])
        ) == .registeredHotKey
    )
}

@Test func registeredHotKeyShortcutsKeepEventMonitorFallback() {
    #expect(VoiceShortcutGlobalCapturePolicy.allowsEventMonitorFallback(for: .rightOptionKey))
    #expect(
        VoiceShortcutGlobalCapturePolicy.allowsEventMonitorFallback(
            for: .keyCombo(keyCode: 64, modifiers: [])
        )
    )
}

@Test func keyCombosUseLowLevelKeyboardTapFallback() {
    #expect(!VoiceShortcutGlobalCapturePolicy.usesLowLevelKeyboardTapFallback(for: .rightOptionKey))
    #expect(
        VoiceShortcutGlobalCapturePolicy.usesLowLevelKeyboardTapFallback(
            for: .keyCombo(keyCode: 64, modifiers: [])
        )
    )
}

@Test func toggleShortcutStartsWhenIdleAndFinishesWhenRunning() {
    #expect(VoiceShortcutTriggerPolicy.action(for: .idle) == .begin)
    #expect(VoiceShortcutTriggerPolicy.action(for: .running) == .finish)
    #expect(VoiceShortcutTriggerPolicy.action(for: .finishing) == .ignore)
}

@Test func doubleShortcutStartsContextQuestionOnlyWhenIdle() {
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .idle, trigger: .double) == .beginContextQuestion
    )
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .running, trigger: .double) == .ignore
    )
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .finishing, trigger: .double) == .ignore
    )
}

@Test func tripleShortcutStartsQuickCommandOnlyWhenIdle() {
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .idle, trigger: .triple) == .beginQuickCommand
    )
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .running, trigger: .triple) == .ignore
    )
    #expect(
        VoiceShortcutTriggerPolicy.action(for: .finishing, trigger: .triple) == .ignore
    )
}
