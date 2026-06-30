import Foundation

public enum VoiceShortcutQuickCommand: String, Codable, CaseIterable, Equatable, Sendable {
    case quickTranslate = "quick-translate"

    public static let `default`: VoiceShortcutQuickCommand = .quickTranslate

    public var displayTitle: String {
        switch self {
        case .quickTranslate:
            return "快速翻译"
        }
    }

    public var description: String {
        switch self {
        case .quickTranslate:
            return "中文 -> English；非中文 -> 中文"
        }
    }
}

public final class VoiceShortcutQuickCommandStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "voiceShortcutQuickCommand"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> VoiceShortcutQuickCommand {
        guard let rawValue = defaults.string(forKey: key),
              let value = VoiceShortcutQuickCommand(rawValue: rawValue) else {
            return .default
        }
        return value
    }

    public func save(_ command: VoiceShortcutQuickCommand) {
        defaults.setValue(command.rawValue, forKey: key)
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
