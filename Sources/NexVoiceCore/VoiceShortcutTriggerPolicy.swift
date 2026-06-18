import Foundation

public enum VoiceShortcutSessionState: Equatable, Sendable {
    case idle
    case running
    case finishing
}

public enum VoiceShortcutTriggerAction: Equatable, Sendable {
    case begin
    case finish
    case ignore
}

public enum VoiceShortcutTriggerPolicy {
    public static func action(for state: VoiceShortcutSessionState) -> VoiceShortcutTriggerAction {
        switch state {
        case .idle:
            return .begin
        case .running:
            return .finish
        case .finishing:
            return .ignore
        }
    }
}
