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

@Test func toggleShortcutStartsWhenIdleAndFinishesWhenRunning() {
    #expect(VoiceShortcutTriggerPolicy.action(for: .idle) == .begin)
    #expect(VoiceShortcutTriggerPolicy.action(for: .running) == .finish)
    #expect(VoiceShortcutTriggerPolicy.action(for: .finishing) == .ignore)
}
