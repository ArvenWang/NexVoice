import Foundation

public enum VoiceRealtimeEvent: Equatable, Sendable {
    case sessionStarted
    case partialTranscript(String, isStable: Bool)
    case finalTranscript(String)
    case partialTranslation(sourceText: String, targetText: String)
    case finalTranslation(sourceText: String, targetText: String)
    case latencyUpdated(milliseconds: Int)
    case audioLevelUpdated(Double)
    case sessionEnded
    case failed(message: String)
}
