import Foundation

public enum VoiceContinuousRewriteInsertionMode: Equatable, Sendable {
    case insertAtCursor
    case replaceFocusedDraft
}

public struct VoiceContinuousRewriteDecision: Equatable, Sendable {
    public let rewriteSource: String
    public let insertionMode: VoiceContinuousRewriteInsertionMode
    public let focusedDraft: String?

    public init(
        rewriteSource: String,
        insertionMode: VoiceContinuousRewriteInsertionMode,
        focusedDraft: String? = nil
    ) {
        self.rewriteSource = rewriteSource
        self.insertionMode = insertionMode
        self.focusedDraft = focusedDraft
    }
}

public enum VoiceContinuousRewritePolicy {
    public static let defaultMaximumFocusedDraftCharacters = 2_000

    public static func decision(
        focusedDraft: String?,
        newTranscript: String,
        hasEditableSelection: Bool,
        maximumFocusedDraftCharacters: Int = defaultMaximumFocusedDraftCharacters
    ) -> VoiceContinuousRewriteDecision {
        let transcript = newTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = focusedDraft?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let draft, !draft.isEmpty else {
            return VoiceContinuousRewriteDecision(
                rewriteSource: transcript,
                insertionMode: .insertAtCursor
            )
        }

        guard !hasEditableSelection else {
            return VoiceContinuousRewriteDecision(
                rewriteSource: transcript,
                insertionMode: .insertAtCursor
            )
        }

        guard draft.count <= maximumFocusedDraftCharacters else {
            return VoiceContinuousRewriteDecision(
                rewriteSource: transcript,
                insertionMode: .insertAtCursor
            )
        }

        return VoiceContinuousRewriteDecision(
            rewriteSource: """
            连续改写输入：

            已有输入框草稿：
            \(draft)

            本轮新增语音：
            \(transcript)
            """,
            insertionMode: .replaceFocusedDraft,
            focusedDraft: draft
        )
    }
}
