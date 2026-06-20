import Foundation

public struct VoicePersonalDictionaryTerm: Codable, Equatable, Sendable {
    public let phrase: String
    public let weight: Int
    public let note: String?
    public let aliases: [String]
    public let contextWeights: [String: Int]

    public init(
        phrase: String,
        weight: Int = 8,
        note: String? = nil,
        aliases: [String] = [],
        contextWeights: [String: Int] = [:]
    ) {
        self.phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        self.weight = min(11, max(1, weight))
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aliases = Self.normalizedAliases(aliases, phrase: self.phrase)
        self.contextWeights = Self.normalizedContextWeights(contextWeights)
    }

    public var isValid: Bool {
        !phrase.isEmpty
            && !phrase.contains("|")
            && !phrase.contains("\n")
            && !phrase.contains("\r")
    }

    public var hotwordFragment: String? {
        hotwordFragment(weight: weight)
    }

    public func hotwordFragment(weight dynamicWeight: Int) -> String? {
        guard isValid else { return nil }
        return "\(phrase)|\(min(11, max(1, dynamicWeight)))"
    }

    public func dynamicWeight(contextKey: String?) -> Int {
        guard let contextKey, let contextCount = contextWeights[contextKey] else {
            return weight
        }
        return min(11, weight + min(3, max(1, contextCount)))
    }

    private static func normalizedAliases(_ aliases: [String], phrase: String) -> [String] {
        var seen = Set<String>()
        return aliases.compactMap { alias in
            let value = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty,
                  value != phrase,
                  !value.contains("|"),
                  !value.contains("\n"),
                  !value.contains("\r") else {
                return nil
            }
            let key = value.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
    }

    private static func normalizedContextWeights(_ contextWeights: [String: Int]) -> [String: Int] {
        contextWeights.reduce(into: [:]) { result, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, item.value > 0 else { return }
            result[key] = min(1_000, item.value)
        }
    }
}

public struct VoicePersonalDictionary: Codable, Equatable, Sendable {
    public let terms: [VoicePersonalDictionaryTerm]

    public init(terms: [VoicePersonalDictionaryTerm] = []) {
        self.terms = Array(terms.filter(\.isValid).prefix(3_000))
    }

    public var isEmpty: Bool {
        terms.isEmpty
    }

    public var hotwordList: String? {
        hotwordList(for: nil)
    }

    public func hotwordList(for context: VoiceRewriteContext?) -> String? {
        let contextKey = context?.hotwordContextKey.lowercased()
        let fragments = terms
            .sorted { lhs, rhs in
                let lhsDynamicWeight = lhs.dynamicWeight(contextKey: contextKey)
                let rhsDynamicWeight = rhs.dynamicWeight(contextKey: contextKey)
                if lhsDynamicWeight != rhsDynamicWeight {
                    return lhsDynamicWeight > rhsDynamicWeight
                }
                let lhsContextCount = contextKey.flatMap { lhs.contextWeights[$0] } ?? 0
                let rhsContextCount = contextKey.flatMap { rhs.contextWeights[$0] } ?? 0
                if lhsContextCount != rhsContextCount {
                    return lhsContextCount > rhsContextCount
                }
                if lhs.weight == rhs.weight {
                    return lhs.phrase.localizedCaseInsensitiveCompare(rhs.phrase) == .orderedAscending
                }
                return lhs.weight > rhs.weight
            }
            .compactMap { $0.hotwordFragment(weight: $0.dynamicWeight(contextKey: contextKey)) }
            .prefix(128)
        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: ",")
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
        let aliases: [String]?
        let contextWeights: [String: Int]?

        init(from decoder: Decoder) throws {
            let container = try? decoder.singleValueContainer()
            if let phrase = try? container?.decode(String.self) {
                self.phrase = phrase
                self.weight = nil
                self.note = nil
                self.aliases = nil
                self.contextWeights = nil
                return
            }

            let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.phrase = try keyedContainer.decode(String.self, forKey: .phrase)
            self.weight = try keyedContainer.decodeIfPresent(Int.self, forKey: .weight)
            self.note = try keyedContainer.decodeIfPresent(String.self, forKey: .note)
            self.aliases = try keyedContainer.decodeIfPresent([String].self, forKey: .aliases)
            self.contextWeights = try keyedContainer.decodeIfPresent([String: Int].self, forKey: .contextWeights)
        }

        private enum CodingKeys: String, CodingKey {
            case phrase
            case weight
            case note
            case aliases
            case contextWeights
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
                        note: $0.note,
                        aliases: $0.aliases ?? [],
                        contextWeights: $0.contextWeights ?? [:]
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

    public static func save(_ dictionary: VoicePersonalDictionary, fileURL: URL = defaultFileURL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.prettyDictionaryEncoder.encode(dictionary)
        try data.write(to: fileURL, options: [.atomic])
    }

    @discardableResult
    public static func upsert(
        _ term: VoicePersonalDictionaryTerm,
        fileURL: URL = defaultFileURL
    ) throws -> VoicePersonalDictionary {
        let current = load(fileURL: fileURL)
        let normalizedPhrase = term.phrase.lowercased()
        var mergedTerms: [VoicePersonalDictionaryTerm] = []
        var didMerge = false

        for existing in current.terms {
            if existing.phrase.lowercased() == normalizedPhrase {
                didMerge = true
                let aliases = existing.aliases + term.aliases
                let note = term.note?.isEmpty == false ? term.note : existing.note
                let contextWeights = mergeContextWeights(existing.contextWeights, term.contextWeights)
                mergedTerms.append(
                    VoicePersonalDictionaryTerm(
                        phrase: term.phrase,
                        weight: max(existing.weight, term.weight),
                        note: note,
                        aliases: aliases,
                        contextWeights: contextWeights
                    )
                )
            } else {
                mergedTerms.append(existing)
            }
        }

        if !didMerge {
            mergedTerms.insert(term, at: 0)
        }

        let updated = VoicePersonalDictionary(terms: mergedTerms)
        try save(updated, fileURL: fileURL)
        return updated
    }

    @discardableResult
    public static func delete(
        phrase: String,
        fileURL: URL = defaultFileURL
    ) throws -> VoicePersonalDictionary {
        let normalizedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedPhrase.isEmpty else {
            return load(fileURL: fileURL)
        }

        let current = load(fileURL: fileURL)
        let updated = VoicePersonalDictionary(
            terms: current.terms.filter { $0.phrase.lowercased() != normalizedPhrase }
        )
        try save(updated, fileURL: fileURL)
        return updated
    }

    private static func mergeContextWeights(
        _ lhs: [String: Int],
        _ rhs: [String: Int]
    ) -> [String: Int] {
        var result = lhs
        for (key, value) in rhs {
            result[key] = min(1_000, (result[key] ?? 0) + value)
        }
        return result
    }
}

private extension JSONEncoder {
    static var prettyDictionaryEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
