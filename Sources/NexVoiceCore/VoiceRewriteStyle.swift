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
            return "使用忠实整理模式：这是默认模式。最大限度保留用户原意、立场、语气强弱和不确定性；只删除口头禅、重复、无意义停顿，修正明显错词、同音错字和断句，让文本能直接发送。不要扩写观点，不要新增事实，不要主动增强情绪，不要把普通表达改得更高级或更有文采；也不要省略关键动作、对象或约束。"
        case .clear:
            return "使用清晰优化模式：在忠于原意的基础上，让表达更顺、更清楚。可以适度合并重复内容、调整句序、补足必要连接词，但不能改变用户立场、态度、强弱和事实范围。适合工作沟通、邮件和较正式说明。"
        case .natural:
            return "使用自然表达模式：让文本更像真人自然写出来。中文要顺滑自然，英文要偏自然美式表达，避免翻译腔、教材腔和营销腔。可以替换生硬措辞，但不能改变核心意思、语气、立场、频率和严重程度；不要强行加梗、表情或额外态度。"
        case .professional:
            return "使用专业严谨模式：表达要准确、克制、可靠，适合需求说明、技术判断、正式邮件和文档。可以减少口语感并理顺逻辑，但不要写成官腔、公文腔或过度客套；不能新增事实或改变结论。"
        case .expressive:
            return "使用增强表达模式：在不新增事实、不改变立场的前提下，让观点更有力度、更有节奏、更容易被读懂。可以强化表达重点和句子节奏，但不要写成口号，不要使用羞辱性、冒犯性、死亡、暴力或粗俗比喻，不要把语气推到用户没有表达的程度。"
        case .creativeWild:
            return "使用疯狂模式：这是最高改写幅度，只在用户手动选择时使用。允许明显放大表达张力、重组句子、制造更强的节奏和记忆点，让文字更锋利、更有画面感、更抓人；可以使用大胆比喻和更强情绪，但仍然不能新增事实、不能改变核心立场，不能做人身攻击、低俗辱骂、仇恨表达或无关猎奇。即使风格更强，也必须输出普通纯文本，禁止用 **、#、反引号、引用块等 Markdown 符号来制造强调。"
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
