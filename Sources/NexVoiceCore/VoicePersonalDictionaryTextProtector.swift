import Foundation

public enum VoicePersonalDictionaryTextProtector {
    public static func protect(_ text: String, dictionary: VoicePersonalDictionary) -> String {
        guard !text.isEmpty, !dictionary.isEmpty else { return text }
        var result = text

        for correction in dictionary.corrections {
            result = replace(correction.observedText, with: correction.targetTerm, in: result)
        }

        for term in dictionary.terms {
            result = replace(term.phrase, with: term.phrase, in: result)
        }

        return result
    }

    private static func replace(_ source: String, with replacement: String, in text: String) -> String {
        guard source.count >= 2 else { return text }
        let escaped = NSRegularExpression.escapedPattern(for: source)
        let pattern: String
        if source.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil {
            pattern = #"(?i)(?<![A-Za-z0-9_])"# + escaped + #"(?![A-Za-z0-9_])"#
        } else {
            pattern = #"(?i)"# + escaped
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacementTemplate(for: replacement))
    }

    private static func replacementTemplate(for text: String) -> String {
        text
            .replacingOccurrences(of: #"\"#, with: #"\\\\"#)
            .replacingOccurrences(of: "$", with: #"\\$"#)
    }
}
