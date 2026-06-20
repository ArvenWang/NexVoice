import Foundation
import Testing
@testable import NexVoiceCore

@Test func personalDictionaryBuildsTencentHotwordList() {
    let dictionary = VoicePersonalDictionary(terms: [
        VoicePersonalDictionaryTerm(phrase: "NexVoice", weight: 11),
        VoicePersonalDictionaryTerm(phrase: "DeepSeek", weight: 9),
        VoicePersonalDictionaryTerm(phrase: "bad|term", weight: 11)
    ])

    #expect(dictionary.terms.count == 2)
    #expect(dictionary.hotwordList == "NexVoice|11,DeepSeek|9")
}

@Test func personalDictionaryLimitsHotwordListToHighestWeightedTerms() {
    let dictionary = VoicePersonalDictionary(terms: (0..<140).map {
        VoicePersonalDictionaryTerm(phrase: "Term\($0)", weight: $0 % 11 + 1)
    })

    let fragments = dictionary.hotwordList?.components(separatedBy: ",") ?? []

    #expect(dictionary.terms.count == 140)
    #expect(fragments.count == 128)
}

@Test func personalDictionaryPrioritizesCurrentContextHotwords() {
    let dictionary = VoicePersonalDictionary(terms: [
        VoicePersonalDictionaryTerm(phrase: "GlobalHigh", weight: 9),
        VoicePersonalDictionaryTerm(
            phrase: "CodexTerm",
            weight: 7,
            contextWeights: ["bundle:com.openai.codex": 3]
        )
    ])
    let context = VoiceRewriteContext(
        sourceApplicationName: "Codex",
        sourceApplicationBundleIdentifier: "com.openai.codex"
    )

    let fragments = dictionary.hotwordList(for: context)?.components(separatedBy: ",") ?? []

    #expect(fragments.first == "CodexTerm|10")
}

@Test func personalDictionaryStoreLoadsObjectTerms() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try Data("""
    {
      "terms": [
        {"phrase":"NexVoice","weight":11,"note":"产品名"},
        "DeepSeek"
      ]
    }
    """.utf8).write(to: temporaryFile)
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    let dictionary = VoicePersonalDictionaryStore.load(fileURL: temporaryFile)

    #expect(dictionary.terms.map(\.phrase) == ["NexVoice", "DeepSeek"])
    #expect(dictionary.terms.first?.weight == 11)
    #expect(dictionary.terms.first?.note == "产品名")
}

@Test func personalDictionaryStoreSavesAndMergesAliases() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "NexVoice", weight: 8, note: "产品名", aliases: ["nex voice"]),
        fileURL: temporaryFile
    )
    let dictionary = try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "NexVoice", weight: 10, aliases: ["next voice"]),
        fileURL: temporaryFile
    )

    #expect(dictionary.terms.count == 1)
    #expect(dictionary.terms[0].phrase == "NexVoice")
    #expect(dictionary.terms[0].weight == 10)
    #expect(dictionary.terms[0].aliases.contains("nex voice"))
    #expect(dictionary.terms[0].aliases.contains("next voice"))
}

@Test func personalDictionaryStoreMergesContextWeights() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "NexVoice", contextWeights: ["bundle:com.openai.codex": 1]),
        fileURL: temporaryFile
    )
    let dictionary = try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "NexVoice", contextWeights: ["bundle:com.openai.codex": 2]),
        fileURL: temporaryFile
    )

    #expect(dictionary.terms.first?.contextWeights["bundle:com.openai.codex"] == 3)
}

@Test func personalDictionaryStoreDeletesTermByPhrase() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "typeless", aliases: ["timeless"]),
        fileURL: temporaryFile
    )
    try VoicePersonalDictionaryStore.upsert(
        VoicePersonalDictionaryTerm(phrase: "NexVoice"),
        fileURL: temporaryFile
    )

    let dictionary = try VoicePersonalDictionaryStore.delete(
        phrase: "TYPELESS",
        fileURL: temporaryFile
    )

    #expect(dictionary.terms.map(\.phrase) == ["NexVoice"])
    #expect(VoicePersonalDictionaryStore.load(fileURL: temporaryFile).terms.map(\.phrase) == ["NexVoice"])
}

@Test func personalDictionaryStoreReturnsEmptyDictionaryWhenFileIsMissing() {
    let missingFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")

    let dictionary = VoicePersonalDictionaryStore.load(fileURL: missingFile)

    #expect(dictionary.isEmpty)
    #expect(dictionary.hotwordList == nil)
}

@Test func personalDictionaryTextProtectorUsesAliasesAndCaseFixes() {
    let dictionary = VoicePersonalDictionary(terms: [
        VoicePersonalDictionaryTerm(phrase: "NexVoice", aliases: ["nex voice", "next voice"]),
        VoicePersonalDictionaryTerm(phrase: "DeepSeek")
    ])

    let output = VoicePersonalDictionaryTextProtector.protect(
        "我觉得 nex voice 和 deepseek 的体验都很重要，next voice 不能写错。",
        dictionary: dictionary
    )

    #expect(output.contains("NexVoice"))
    #expect(output.contains("DeepSeek"))
    #expect(!output.contains("next voice"))
}
