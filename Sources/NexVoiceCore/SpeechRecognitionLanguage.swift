import Foundation

public enum SpeechRecognitionLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese
    case englishUS

    public var localeIdentifier: String {
        switch self {
        case .simplifiedChinese:
            return "zh_CN"
        case .englishUS:
            return "en_US"
        }
    }

    public var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    public var menuTitle: String {
        switch self {
        case .simplifiedChinese:
            return "中文"
        case .englishUS:
            return "English"
        }
    }
}
