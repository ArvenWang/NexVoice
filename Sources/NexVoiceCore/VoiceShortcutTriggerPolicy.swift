import Foundation

public enum VoiceShortcutSessionState: Equatable, Sendable {
    case idle
    case running
    case finishing
}

public enum VoiceShortcutTriggerAction: Equatable, Sendable {
    case begin
    case beginContextQuestion
    case finish
    case ignore
}

public enum VoiceShortcutTriggerKind: Equatable, Sendable {
    case single
    case double
}

public enum VoiceShortcutTriggerPolicy {
    public static func action(
        for state: VoiceShortcutSessionState,
        trigger: VoiceShortcutTriggerKind = .single
    ) -> VoiceShortcutTriggerAction {
        if trigger == .double {
            return state == .idle ? .beginContextQuestion : .ignore
        }

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
