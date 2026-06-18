import Foundation

public struct VoiceLiveTranscript: Equatable, Sendable {
    public private(set) var sourceSegments: [String]
    public private(set) var targetSegments: [String]
    public private(set) var sourceDraft: String
    public private(set) var targetDraft: String
    public private(set) var lastLatencyMilliseconds: Int?
    public private(set) var lastErrorMessage: String?

    public init(
        sourceSegments: [String] = [],
        targetSegments: [String] = [],
        sourceDraft: String = "",
        targetDraft: String = "",
        lastLatencyMilliseconds: Int? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.sourceSegments = sourceSegments
        self.targetSegments = targetSegments
        self.sourceDraft = sourceDraft
        self.targetDraft = targetDraft
        self.lastLatencyMilliseconds = lastLatencyMilliseconds
        self.lastErrorMessage = lastErrorMessage
    }

    public var sourceText: String {
        sourceSegments.joined(separator: "\n")
    }

    public var targetText: String {
        targetSegments.joined(separator: "\n")
    }

    public mutating func apply(_ event: VoiceRealtimeEvent) {
        switch event {
        case .sessionStarted:
            sourceSegments.removeAll()
            targetSegments.removeAll()
            sourceDraft = ""
            targetDraft = ""
            lastLatencyMilliseconds = nil
            lastErrorMessage = nil
        case .partialTranscript(let text, _):
            sourceDraft = text
        case .finalTranscript(let text):
            append(text, to: &sourceSegments)
            sourceDraft = ""
        case .partialTranslation(let sourceText, let targetText):
            sourceDraft = sourceText
            targetDraft = targetText
        case .finalTranslation(let sourceText, let targetText):
            append(sourceText, to: &sourceSegments)
            append(targetText, to: &targetSegments)
            sourceDraft = ""
            targetDraft = ""
        case .latencyUpdated(let milliseconds):
            lastLatencyMilliseconds = milliseconds
        case .audioLevelUpdated:
            break
        case .sessionEnded:
            sourceDraft = ""
            targetDraft = ""
        case .failed(let message):
            lastErrorMessage = message
        }
    }

    private func append(_ text: String, to segments: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        segments.append(trimmed)
    }
}
