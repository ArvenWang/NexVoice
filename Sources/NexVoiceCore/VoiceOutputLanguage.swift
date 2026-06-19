import Foundation

public enum VoiceOutputLanguage: String, Codable, CaseIterable, Sendable {
    case simplifiedChinese
    case english

    public var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "中文"
        case .english:
            return "English"
        }
    }
}
