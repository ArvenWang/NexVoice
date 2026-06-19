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
    #expect(dictionary.promptInstruction?.contains("NexVoice") == true)
    #expect(dictionary.promptInstruction?.contains("专有名词") == true)
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

@Test func personalDictionaryStoreReturnsEmptyDictionaryWhenFileIsMissing() {
    let missingFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")

    let dictionary = VoicePersonalDictionaryStore.load(fileURL: missingFile)

    #expect(dictionary.isEmpty)
    #expect(dictionary.hotwordList == nil)
}
