import Foundation

public enum VoiceRewriteStyle: String, Codable, CaseIterable, Sendable {
    case faithful
    case clear
    case natural
    case professional
    case expressive
    case creativeWild

    public static let `default`: VoiceRewriteStyle = .faithful

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "automatic", "general":
            self = .faithful
        case "casualFun":
            self = .natural
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
        case .faithful:
            return "忠实整理（默认）"
        case .clear:
            return "清晰优化"
        case .natural:
            return "自然表达"
        case .professional:
            return "专业严谨"
        case .expressive:
            return "增强表达"
        case .creativeWild:
            return "疯狂模式"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .faithful:
            return "忠实整理模式：默认。最大限度保留用户原意、立场、语气强弱和不确定性；只去口头禅/重复/停顿，修错词、同音错字和断句。不要扩写观点、新增事实、增强情绪、拔高文采，也不要省略关键动作、对象或约束。"
        case .clear:
            return "清晰优化模式：忠于原意，让表达更顺更清楚；可合并重复、调整句序、补必要连接词，但不能改变立场、态度、强弱和事实范围。适合工作沟通、邮件和正式说明。"
        case .natural:
            return "自然表达模式：像真人自然写作；中文顺滑，英文偏自然美式表达，避免翻译腔、教材腔和营销腔。可替换生硬措辞，但不改核心意思、语气、立场、频率和严重程度；不强加梗、表情或态度。"
        case .professional:
            return "专业严谨模式：准确、克制、可靠，适合需求说明、技术判断、正式邮件和文档。可减少口语感并理顺逻辑，但不要官腔、公文腔或过度客套；不新增事实或改变结论。"
        case .expressive:
            return "增强表达模式：不新增事实、不改变立场；让观点更有力度、节奏和可读性。可强化重点和句式，但别写成口号；避免羞辱、冒犯、死亡、暴力或粗俗比喻；不要把语气推过用户原意。"
        case .creativeWild:
            return "疯狂模式：最高改写幅度，仅用户手动选择时使用。可明显放大张力、重组句子、制造强节奏和记忆点，让文字更锋利、有画面感、更抓人；可用大胆比喻和更强情绪，但不新增事实、不改核心立场，不做人身攻击、低俗辱骂、仇恨或无关猎奇。仍输出普通纯文本，禁止用 **、#、反引号、引用块等 Markdown 符号。"
        }
    }

    public var rewriteTemperature: Double {
        switch self {
        case .faithful:
            return 0.05
        case .clear:
            return 0.15
        case .professional:
            return 0.2
        case .natural:
            return 0.25
        case .expressive:
            return 0.45
        case .creativeWild:
            return 0.85
        }
    }
}
