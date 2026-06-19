import Foundation

public enum VoiceSessionCancellationPolicy {
    public static func shouldCancel(
        transcriptionState: VoiceShortcutSessionState,
        isRewriting: Bool,
        hasRewriteTask: Bool
    ) -> Bool {
        transcriptionState != .idle || isRewriting || hasRewriteTask
    }
}
