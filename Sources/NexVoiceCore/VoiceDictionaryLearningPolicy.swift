import Foundation

public struct VoiceDictionaryCorrectionCandidate: Equatable, Sendable {
    public let incorrectText: String
    public let correctedText: String
    public let baselineText: String
    public let editedText: String
    public let originalASRText: String
    public let rewrittenText: String
    public let contextSummary: String
    public let contextKey: String

    public init(
        incorrectText: String,
        correctedText: String,
        baselineText: String,
        editedText: String,
        originalASRText: String,
        rewrittenText: String,
        contextSummary: String,
        contextKey: String
    ) {
        self.incorrectText = incorrectText
        self.correctedText = correctedText
        self.baselineText = baselineText
        self.editedText = editedText
        self.originalASRText = originalASRText
        self.rewrittenText = rewrittenText
        self.contextSummary = contextSummary
        self.contextKey = contextKey
    }
}

public enum VoiceDictionaryLearningPolicy {
    public static func candidate(
        baselineText: String,
        editedText: String,
        originalASRText: String,
        rewrittenText: String,
        context: VoiceRewriteContext
    ) -> VoiceDictionaryCorrectionCandidate? {
        let baseline = normalizeWhitespace(baselineText)
        let edited = normalizeWhitespace(editedText)
        guard baseline != edited else { return nil }

        guard let replacement = singleReplacement(from: baseline, to: edited) else {
            return nil
        }

        let incorrect = replacement.old.trimmingCharacters(in: .whitespacesAndNewlines)
        let corrected = replacement.new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldAskModel(incorrectText: incorrect, correctedText: corrected) else {
            return nil
        }

        return VoiceDictionaryCorrectionCandidate(
            incorrectText: incorrect,
            correctedText: corrected,
            baselineText: baseline,
            editedText: edited,
            originalASRText: originalASRText,
            rewrittenText: rewrittenText,
            contextSummary: context.diagnosticsSummary,
            contextKey: context.hotwordContextKey
        )
    }

    public static func shouldAskModel(incorrectText: String, correctedText: String) -> Bool {
        let incorrect = incorrectText.trimmingCharacters(in: .whitespacesAndNewlines)
        let corrected = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incorrect.isEmpty, !corrected.isEmpty else { return false }
        guard incorrect != corrected else { return false }
        guard incorrect.count <= 64 else { return false }
        guard !isOnlyPunctuationOrWhitespace(incorrect),
              !isOnlyPunctuationOrWhitespace(corrected) else {
            return false
        }
        guard !looksLikeSentence(incorrect) else { return false }
        guard isValidDictionaryTerm(corrected) else { return false }

        return true
    }

    public static func isValidDictionaryTerm(_ text: String) -> Bool {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              term.count <= 32,
              !term.contains("|"),
              !term.contains("\n"),
              !term.contains("\r"),
              !isOnlyPunctuationOrWhitespace(term),
              !looksLikeSentence(term),
              !isGenericCommonWord(term) else {
            return false
        }

        let tokens = term.split { $0.isWhitespace }
        guard tokens.count <= 4 else { return false }

        if containsCJK(term), looksLikeChineseSentenceFragment(term) {
            return false
        }

        if containsCJK(term), tokens.count > 1, !containsLatinLetterOrDigit(term) {
            return false
        }

        return true
    }

    private static func singleReplacement(from baseline: String, to edited: String) -> (old: String, new: String)? {
        let baselineCharacters = Array(baseline)
        let editedCharacters = Array(edited)

        var prefix = 0
        while prefix < baselineCharacters.count,
              prefix < editedCharacters.count,
              baselineCharacters[prefix] == editedCharacters[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix + prefix < baselineCharacters.count,
              suffix + prefix < editedCharacters.count,
              baselineCharacters[baselineCharacters.count - suffix - 1] == editedCharacters[editedCharacters.count - suffix - 1] {
            let matchingCharacter = baselineCharacters[baselineCharacters.count - suffix - 1]
            if isLatinLetterOrDigit(matchingCharacter) {
                let baselinePreviousIndex = baselineCharacters.count - suffix - 2
                let editedPreviousIndex = editedCharacters.count - suffix - 2
                if baselinePreviousIndex >= prefix,
                   editedPreviousIndex >= prefix,
                   isLatinLetterOrDigit(baselineCharacters[baselinePreviousIndex]),
                   isLatinLetterOrDigit(editedCharacters[editedPreviousIndex]) {
                    break
                }
            }
            suffix += 1
        }

        let oldEnd = baselineCharacters.count - suffix
        let newEnd = editedCharacters.count - suffix
        guard prefix <= oldEnd, prefix <= newEnd else { return nil }

        let old = String(baselineCharacters[prefix..<oldEnd])
        let new = String(editedCharacters[prefix..<newEnd])
        return (old, new)
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isOnlyPunctuationOrWhitespace(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.punctuationCharacters.contains($0)
                || CharacterSet.symbols.contains($0)
        }
    }

    private static func looksLikeSentence(_ text: String) -> Bool {
        if text.count > 32 { return true }
        let sentenceMarkers = CharacterSet(charactersIn: "。！？!?；;，,\n")
        return text.rangeOfCharacter(from: sentenceMarkers) != nil
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func containsLatinLetterOrDigit(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").contains($0)
        }
    }

    private static func looksLikeChineseSentenceFragment(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: " ", with: "")
        let phraseMarkers = [
            "帮我", "给我", "看一下", "查一下", "查看", "有没有", "上有没有",
            "一下", "哪只", "那只", "是不是", "可不可以", "能不能", "需要",
            "应该", "不要", "把它", "帮我到", "最新"
        ]
        if phraseMarkers.contains(where: { compact.contains($0) }) {
            return true
        }

        let first = compact.first
        if compact.count > 3,
           let first,
           ["是", "要", "把", "帮", "查", "看"].contains(first) {
            return true
        }
        return false
    }

    private static func isLatinLetterOrDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").contains($0)
        }
    }

    private static func isGenericCommonWord(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let commonWords: Set<String> = [
            "这个", "那个", "今天", "明天", "昨天", "功能", "速度", "问题", "方案", "逻辑",
            "内容", "文字", "输入", "输出", "修改", "整理", "润色", "标点", "语序",
            "the", "and", "or", "but", "today", "tomorrow", "feature", "speed", "issue",
            "good", "great", "bad", "better", "best", "fast", "quick", "slow", "small",
            "big", "large", "important", "normal", "clear", "simple", "hard", "easy"
        ]
        return commonWords.contains(normalized)
    }

}
