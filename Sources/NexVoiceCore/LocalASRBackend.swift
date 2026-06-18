import Foundation

public enum LocalASRBackend: String, CaseIterable, Equatable, Sendable {
    case tencentCloudRealtime
    case senseVoice
    case whisperKit

    public static let `default`: LocalASRBackend = .tencentCloudRealtime

    public var displayTitle: String {
        switch self {
        case .tencentCloudRealtime:
            return "腾讯云实时 ASR 大模型"
        case .senseVoice:
            return "SenseVoice Small"
        case .whisperKit:
            return "WhisperKit large-v3"
        }
    }
}
