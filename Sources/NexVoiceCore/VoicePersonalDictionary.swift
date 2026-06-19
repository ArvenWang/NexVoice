import Foundation

public struct VoicePersonalDictionaryTerm: Codable, Equatable, Sendable {
    public let phrase: String
    public let weight: Int
    public let note: String?

    public init(phrase: String, weight: Int = 8, note: String? = nil) {
        self.phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        self.weight = min(11, max(1, weight))
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        !phrase.isEmpty
            && !phrase.contains("|")
            && !phrase.contains("\n")
            && !phrase.contains("\r")
    }

    public var hotwordFragment: String? {
        guard isValid else { return nil }
        return "\(phrase)|\(weight)"
    }
}

public struct VoicePersonalDictionary: Codable, Equatable, Sendable {
    public let terms: [VoicePersonalDictionaryTerm]

    public init(terms: [VoicePersonalDictionaryTerm] = []) {
        self.terms = Array(terms.filter(\.isValid).prefix(80))
    }

    public var isEmpty: Bool {
        terms.isEmpty
    }

    public var hotwordList: String? {
        let fragments = terms.compactMap(\.hotwordFragment).prefix(30)
        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: ",")
    }

    public var promptInstruction: String? {
        guard !terms.isEmpty else { return nil }
        let lines = terms.prefix(30).map { term -> String in
            if let note = term.note, !note.isEmpty {
                return "- \(term.phrase)：\(note)"
            }
            return "- \(term.phrase)"
        }
        return """
        用户个人词库：
        \(lines.joined(separator: "\n"))

        处理这些词时要优先按用户词库理解，专有名词、产品名、人名、项目名不要误改。
        """
    }
}

public enum VoicePersonalDictionaryStore {
    private struct FileDictionary: Decodable {
        let terms: [FileTerm]
    }

    private struct FileTerm: Decodable {
        let phrase: String
        let weight: Int?
        let note: String?

        init(from decoder: Decoder) throws {
            let container = try? decoder.singleValueContainer()
            if let phrase = try? container?.decode(String.self) {
                self.phrase = phrase
                self.weight = nil
                self.note = nil
                return
            }

            let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.phrase = try keyedContainer.decode(String.self, forKey: .phrase)
            self.weight = try keyedContainer.decodeIfPresent(Int.self, forKey: .weight)
            self.note = try keyedContainer.decodeIfPresent(String.self, forKey: .note)
        }

        private enum CodingKeys: String, CodingKey {
            case phrase
            case weight
            case note
        }
    }

    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("PersonalDictionary.json")
    }

    public static func load(fileURL: URL = defaultFileURL) -> VoicePersonalDictionary {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return VoicePersonalDictionary()
        }

        if let fileDictionary = try? JSONDecoder().decode(FileDictionary.self, from: data) {
            return VoicePersonalDictionary(
                terms: fileDictionary.terms.map {
                    VoicePersonalDictionaryTerm(
                        phrase: $0.phrase,
                        weight: $0.weight ?? 8,
                        note: $0.note
                    )
                }
            )
        }

        if let plainTerms = try? JSONDecoder().decode([String].self, from: data) {
            return VoicePersonalDictionary(
                terms: plainTerms.map { VoicePersonalDictionaryTerm(phrase: $0) }
            )
        }

        return VoicePersonalDictionary()
    }
}
