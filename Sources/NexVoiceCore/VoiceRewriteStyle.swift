import Foundation

public enum VoiceRewriteStyle: String, Codable, CaseIterable, Sendable {
    case standard
    case socialExpert
    case amplifiedSpokesperson
    case calm

    public static let `default`: VoiceRewriteStyle = .standard

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "automatic", "general", "faithful", "clear", "professional":
            self = .standard
        case "casualFun", "natural":
            self = .socialExpert
        case "expressive", "creativeWild":
            self = .amplifiedSpokesperson
        default:
            self = VoiceRewriteStyle(rawValue: rawValue) ?? .default
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var menuTitle: String {
        switch self {
        case .standard:
            return "标准模式（默认）"
        case .socialExpert:
            return "社交达人"
        case .amplifiedSpokesperson:
            return "强化嘴替"
        case .calm:
            return "冷静模式"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .standard:
            return "标准模式：默认。修正吞字、断词、重复、口头禅、明显错词和断句，让表达自然、清晰、顺畅。严格贴合原意、事实、立场和语气强弱，不添加新观点。"
        case .socialExpert:
            return "社交达人：适合聊天、评论和社交媒体。表达更轻松、有网感、像真人发言；中文更自然有趣，英文可使用常见缩写、短句和 X、Reddit 等语境里更地道的说法。保留核心意思和态度，可以轻微幽默，但不硬加梗。"
        case .amplifiedSpokesperson:
            return "强化嘴替：把用户原本的情绪和攻击性明显放大，不要为了礼貌降温。用户激动，就写得更炸、更有冲击力；用户愤怒，就写得更狠、更锋利、更不客气。允许使用脏话、骂人和冒犯性表达，也可以直接攻击具体对象的行为、方案、表现或观点。可以补充贴合语境的态度和措辞，让输出强于原文一个档位以上；但不要编造事实、不要威胁现实伤害、不要把攻击转向种族、性别、宗教等身份群体。"
        case .calm:
            return "冷静模式：把强情绪、脏话、攻击性和混乱表达压成平和、克制、可沟通的文字。用尽量少的字表达清楚原意，保留核心诉求和事实，语气冷静、简洁、正常。"
        }
    }

    public var rewriteTemperature: Double {
        switch self {
        case .standard:
            return 0.1
        case .socialExpert:
            return 0.35
        case .amplifiedSpokesperson:
            return 0.95
        case .calm:
            return 0.15
        }
    }
}
