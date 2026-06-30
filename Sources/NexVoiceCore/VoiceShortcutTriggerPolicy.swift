import Foundation

public enum VoiceShortcutSessionState: Equatable, Sendable {
    case idle
    case running
    case finishing
}

public enum VoiceShortcutTriggerAction: Equatable, Sendable {
    case begin
    case beginContextQuestion
    case beginQuickCommand
    case finish
    case ignore
}

public enum VoiceShortcutTriggerKind: Equatable, Sendable {
    case single
    case double
    case triple
}

public enum VoiceShortcutTriggerPolicy {
    public static func action(
        for state: VoiceShortcutSessionState,
        trigger: VoiceShortcutTriggerKind = .single
    ) -> VoiceShortcutTriggerAction {
        if trigger == .double {
            return state == .idle ? .beginContextQuestion : .ignore
        }
        if trigger == .triple {
            return state == .idle ? .beginQuickCommand : .ignore
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
