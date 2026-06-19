import Foundation

public enum VoiceFinalTextPolicy {
    public static let noRecognizedSpeechMessage = "没有识别到语音，请确认麦克风输入后再试。"

    public static func isNoRecognizedSpeechMessage(_ message: String) -> Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines) == noRecognizedSpeechMessage
    }

    public static func insertionText(from event: VoiceRealtimeEvent) -> String? {
        guard case .finalTranscript(let text) = event else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func fallbackInsertionText(fromPartialTranscript text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
