import Foundation

public enum VoiceApplicationRewriteProfile: String, Codable, Sendable {
    case general
    case agentCollaboration
    case socialConversation
    case emailReply
    case workChat

    public var promptHint: String {
        switch self {
        case .general:
            return "通用：清晰自然，少加工，可直接发送。"
        case .agentCollaboration:
            return "Agent/开发协作：保留提问、判断、任务和约束；仅真实清单才编号。"
        case .socialConversation:
            return "社交评论：像真人自然发言，避免翻译腔、营销腔和过度正式。"
        case .emailReply:
            return "邮件回复：礼貌清楚、有分寸，不模板化。"
        case .workChat:
            return "即时沟通：简洁自然，行动明确，少铺垫。"
        }
    }
}

public struct VoiceRewriteContext: Equatable, Sendable {
    public let sourceApplicationName: String?
    public let sourceApplicationBundleIdentifier: String?
    public let focusedElementRole: String?
    public let focusedElementDescription: String?
    public let focusedTextPreview: String?
    public let selectedTextMode: Bool
    public let personalDictionary: VoicePersonalDictionary

    public init(
        sourceApplicationName: String? = nil,
        sourceApplicationBundleIdentifier: String? = nil,
        focusedElementRole: String? = nil,
        focusedElementDescription: String? = nil,
        focusedTextPreview: String? = nil,
        selectedTextMode: Bool = false,
        personalDictionary: VoicePersonalDictionary = VoicePersonalDictionary()
    ) {
        self.sourceApplicationName = Self.cleaned(sourceApplicationName)
        self.sourceApplicationBundleIdentifier = Self.cleaned(sourceApplicationBundleIdentifier)
        self.focusedElementRole = Self.cleaned(focusedElementRole)
        self.focusedElementDescription = Self.cleaned(focusedElementDescription)
        self.focusedTextPreview = Self.preview(focusedTextPreview, limit: 700)
        self.selectedTextMode = selectedTextMode
        self.personalDictionary = personalDictionary
    }

    public var applicationProfile: VoiceApplicationRewriteProfile {
        let haystack = [
            sourceApplicationName,
            sourceApplicationBundleIdentifier,
            focusedElementDescription,
            focusedTextPreview
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let appName = sourceApplicationName?.lowercased()

        if haystack.contains("mail")
            || haystack.contains("outlook")
            || haystack.contains("spark")
            || haystack.contains("airmail")
            || haystack.contains("gmail") {
            return .emailReply
        }

        if haystack.contains("slack")
            || haystack.contains("discord")
            || haystack.contains("telegram")
            || haystack.contains("wechat")
            || haystack.contains("weixin")
            || haystack.contains("lark")
            || haystack.contains("feishu") {
            return .workChat
        }

        if haystack.contains("twitter")
            || appName == "x"
            || haystack.contains("x.com")
            || haystack.contains("tweet")
            || haystack.contains("reddit")
            || haystack.contains("youtube")
            || haystack.contains("threads")
            || haystack.contains("post composer")
            || haystack.contains("comment box") {
            return .socialConversation
        }

        if haystack.contains("cursor")
            || haystack.contains("xcode")
            || haystack.contains("vscode")
            || haystack.contains("visual studio code")
            || haystack.contains("chatgpt")
            || haystack.contains("claude")
            || haystack.contains("codex")
            || haystack.contains("windsurf") {
            return .agentCollaboration
        }

        return .general
    }

    public var promptBlock: String {
        var lines = [
            "当前上下文：",
            "- 应用：\(sourceApplicationName ?? "未知")",
            "- 类型：\(applicationProfile.promptHint)",
            "- 模式：\(selectedTextMode ? "选中文本+语音指令" : "普通语音输入")"
        ]

        if let focusedElementRole {
            lines.append("- 焦点：\(focusedElementRole)")
        }
        if let focusedElementDescription {
            lines.append("- 说明：\(focusedElementDescription)")
        }
        if let focusedTextPreview, !focusedTextPreview.isEmpty {
            lines.append("""
            - 输入框片段（只作上下文，除非原文要求引用/续写，否则不要写入结果）：
            \(focusedTextPreview)
            """)
        }
        return lines.joined(separator: "\n")
    }

    public var diagnosticsSummary: String {
        [
            sourceApplicationName ?? "unknown_app",
            sourceApplicationBundleIdentifier ?? "unknown_bundle",
            applicationProfile.rawValue,
            selectedTextMode ? "selected_text" : "normal_input",
            personalDictionary.isEmpty ? "no_dictionary" : "dictionary_terms_\(personalDictionary.terms.count)"
        ]
        .joined(separator: "|")
    }

    public var hotwordContextKey: String {
        if let bundleIdentifier = sourceApplicationBundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        if let applicationName = sourceApplicationName, !applicationName.isEmpty {
            return "app:\(applicationName.lowercased())"
        }
        return "profile:\(applicationProfile.rawValue)"
    }

    private static func cleaned(_ value: String?) -> String? {
        let cleanedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedValue?.isEmpty == false ? cleanedValue : nil
    }

    private static func preview(_ value: String?, limit: Int) -> String? {
        guard let cleanedValue = cleaned(value) else { return nil }
        let normalized = cleanedValue
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "..." : prefix
    }
}

public enum VoiceRewritePromptMode: String, Codable, Sendable {
    case fast
    case full
}

public struct VoiceRewritePromptPlan: Equatable, Sendable {
    public let mode: VoiceRewritePromptMode
    public let systemPrompt: String
    public let userPrompt: String

    public init(mode: VoiceRewritePromptMode, systemPrompt: String, userPrompt: String) {
        self.mode = mode
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
    }
}

public enum VoiceRewritePromptRoutingPolicy {
    public static func mode(
        for text: String,
        operation: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle,
        context: VoiceRewriteContext
    ) -> VoiceRewritePromptMode {
        .full
    }

    private static func isFastCompatibleDictionary(_ dictionary: VoicePersonalDictionary) -> Bool {
        dictionary.terms.count <= 8
            && dictionary.terms.allSatisfy { term in
                term.phrase.count <= 32 && (term.note?.count ?? 0) <= 80
            }
    }

    private static func sourceLooksFragmented(_ text: String) -> Bool {
        guard text.count >= 40 else { return false }

        let stopWords = ["呃", "嗯", "啊", "就是", "那个"]
        let stopWordCount = stopWords.reduce(0) { count, word in
            count + text.components(separatedBy: word).count - 1
        }
        let shortSentenceCount = text
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 4 }
            .count

        return stopWordCount >= 2 || shortSentenceCount >= 3
    }
}

public enum VoiceRewriteTimeoutPolicy {
    public static func timeoutSeconds(
        operation: String,
        promptCharacters: Int,
        selectedTextCharacters: Int?,
        sourceTextCharacters: Int? = nil,
        sourceText: String? = nil,
        style: VoiceRewriteStyle = .default,
        promptMode: VoiceRewritePromptMode = .full
    ) -> TimeInterval {
        if promptMode == .fast {
            return sourceLooksFragmented(sourceText) ? 8 : 6
        }

        if operation == "selected_text_command" {
            return selectedTextCharacters ?? 0 > 600 || promptCharacters > 1_600 ? 12 : 9
        }

        if style == .amplifiedSpokesperson {
            return promptCharacters > 1_200 ? 12 : 8
        }

        if let sourceTextCharacters {
            if sourceLooksFragmented(sourceText) {
                return 12
            }
            if sourceTextCharacters > 260 {
                return 12
            }
            if sourceTextCharacters > 160 {
                return 12
            }
            if sourceTextCharacters > 90 {
                return 10
            }
            return 10
        }

        if promptCharacters > 1_200 {
            return 12
        }
        if promptCharacters > 600 {
            return 10
        }
        return 10
    }

    private static func sourceLooksFragmented(_ sourceText: String?) -> Bool {
        guard let sourceText else { return false }
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 40 else { return false }

        let stopWords = ["呃", "嗯", "啊", "就是", "那个"]
        let stopWordCount = stopWords.reduce(0) { count, word in
            count + text.components(separatedBy: word).count - 1
        }
        let shortSentenceCount = text
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 4 }
            .count

        return stopWordCount >= 2 || shortSentenceCount >= 3
    }
}

public enum VoiceRewriteQualityPolicy {
    public static func qualityIssue(
        output: String,
        operation: String,
        outputLanguage: VoiceOutputLanguage
    ) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "empty_output"
        }

        let forbiddenMarkdownMarkers = ["```", "**", "__", "~~"]
        if forbiddenMarkdownMarkers.contains(where: { trimmed.contains($0) }) {
            return "markdown_marker"
        }

        let forbiddenPrefixes = [
            "根据你的指令",
            "以下是",
            "Here is",
            "Sure,",
            "Certainly,"
        ]
        if forbiddenPrefixes.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return "assistant_meta_prefix"
        }

        if operation == "selected_text_command",
           trimmed.localizedCaseInsensitiveContains("用户选中的文本") {
            return "leaked_instruction"
        }

        return nil
    }
}

public enum VoicePromptInjectionPolicy {
    public static func shouldUseSafeFallback(
        sourceText: String?,
        output: String,
        operation: String
    ) -> Bool {
        guard operation == "final_rewrite",
              let sourceText,
              sourceLooksLikePromptInjection(sourceText)
        else {
            return false
        }
        return outputLooksLikeModelLeak(output)
    }

    public static func sourceLooksLikePromptInjection(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let lowercased = normalized.lowercased()

        let authorityMarkers = [
            "系统级", "系统指令", "管理员", "管理员级", "开发者指令", "system", "developer", "admin"
        ]
        let overrideMarkers = [
            "忽略", "ignore", "覆盖", "override", "无视", "前置条件", "上面所有", "所有上下文", "原始指令", "以本条", "以这条", "为准"
        ]
        let leakRequestMarkers = [
            "模型", "型号", "版本", "model", "version", "系统提示", "system prompt", "prompt", "内部指令", "打印", "输出", "透露", "泄露"
        ]

        let hasAuthority = authorityMarkers.contains { lowercased.contains($0.lowercased()) }
        let hasOverride = overrideMarkers.contains { lowercased.contains($0.lowercased()) }
        let hasLeakRequest = leakRequestMarkers.contains { lowercased.contains($0.lowercased()) }

        return (hasAuthority && hasOverride) || (hasOverride && hasLeakRequest) || (hasAuthority && hasLeakRequest)
    }

    public static func outputLooksLikeModelLeak(_ output: String) -> Bool {
        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let lowercased = normalized.lowercased()

        let leakMarkers = [
            "deepseek",
            "deepseek-v",
            "deepseek chat",
            "gpt",
            "chatgpt",
            "claude",
            "gemini",
            "我是一个ai",
            "我是 ai",
            "我是deepseek",
            "我是 deepseek",
            "大语言模型",
            "模型型号",
            "当前模型",
            "系统提示",
            "system prompt",
            "as an ai",
            "i am an ai",
            "i'm an ai",
            "model version"
        ]

        return leakMarkers.contains { lowercased.contains($0.lowercased()) }
    }
}
