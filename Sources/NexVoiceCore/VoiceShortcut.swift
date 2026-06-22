import CoreGraphics
import Foundation

public enum VoiceShortcutModifier: String, Codable, CaseIterable, Sendable {
    case command
    case shift
    case option
    case control

    public static let displayOrder: [VoiceShortcutModifier] = [
        .control,
        .option,
        .shift,
        .command
    ]

    public var cgFlag: CGEventFlags {
        switch self {
        case .command:
            return .maskCommand
        case .shift:
            return .maskShift
        case .option:
            return .maskAlternate
        case .control:
            return .maskControl
        }
    }

    public var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .shift:
            return "⇧"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        }
    }
}

public enum VoiceShortcut: Codable, Equatable, Sendable {
    case functionKey
    case rightOptionKey
    case keyCombo(keyCode: UInt16, modifiers: Set<VoiceShortcutModifier>)

    public static let `default`: VoiceShortcut = .rightOptionKey
    public static let rightOptionKeyCode: UInt16 = 0x3D

    public var displayTitle: String {
        switch self {
        case .functionKey:
            return "Fn"
        case .rightOptionKey:
            return "右 Alt"
        case .keyCombo(let keyCode, let modifiers):
            let ordered = VoiceShortcutModifier.displayOrder
                .filter { modifiers.contains($0) }
                .map(\.symbol)
                .joined()
            return "\(ordered) \(Self.keyName(for: keyCode))"
        }
    }

    public func matchesModifierKeyPress(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch self {
        case .functionKey:
            return flags.contains(.maskSecondaryFn)
        case .rightOptionKey:
            return keyCode == Self.rightOptionKeyCode && flags.contains(.maskAlternate)
        case .keyCombo:
            return false
        }
    }

    public func matchesModifierKeyRelease(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        switch self {
        case .functionKey:
            return !flags.contains(.maskSecondaryFn)
        case .rightOptionKey:
            return keyCode == Self.rightOptionKeyCode && !flags.contains(.maskAlternate)
        case .keyCombo:
            return false
        }
    }

    public func matchesKeyEvent(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard case .keyCombo(let expectedKeyCode, let modifiers) = self,
              expectedKeyCode == keyCode else {
            return false
        }
        return Self.modifiers(from: flags) == modifiers
    }

    public func matchesKeyReleaseEvent(keyCode: UInt16) -> Bool {
        guard case .keyCombo(let expectedKeyCode, _) = self else {
            return false
        }
        return expectedKeyCode == keyCode
    }

    public static func modifiers(from flags: CGEventFlags) -> Set<VoiceShortcutModifier> {
        Set(VoiceShortcutModifier.allCases.filter { flags.contains($0.cgFlag) })
    }

    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 49: return "Space"
        case 53: return "Esc"
        default: return "Key \(keyCode)"
        }
    }
}

public enum VoiceShortcutRecordingEventType: Sendable {
    case keyDown
    case flagsChanged
}

public enum VoiceShortcutRecordingPolicy {
    public static func shortcut(
        for eventType: VoiceShortcutRecordingEventType,
        keyCode: UInt16,
        flags: CGEventFlags
    ) -> VoiceShortcut? {
        switch eventType {
        case .flagsChanged:
            guard keyCode == VoiceShortcut.rightOptionKeyCode,
                  flags.contains(.maskAlternate) else {
                return nil
            }
            return .rightOptionKey
        case .keyDown:
            return .keyCombo(
                keyCode: keyCode,
                modifiers: VoiceShortcut.modifiers(from: flags)
            )
        }
    }
}

public final class VoiceShortcutStore {
    private let defaults: UserDefaults
    private let key: String
    private let legacyDefaultMigrationKey: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "voiceShortcut",
        legacyDefaultMigrationKey: String = "voiceShortcutMigratedFromFunctionDefault"
    ) {
        self.defaults = defaults
        self.key = key
        self.legacyDefaultMigrationKey = legacyDefaultMigrationKey
    }

    public func load() -> VoiceShortcut {
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(VoiceShortcut.self, from: data) else {
            return .default
        }
        if shortcut == .functionKey, !defaults.bool(forKey: legacyDefaultMigrationKey) {
            save(.default)
            defaults.set(true, forKey: legacyDefaultMigrationKey)
            return .default
        }
        return shortcut
    }

    public func save(_ shortcut: VoiceShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
