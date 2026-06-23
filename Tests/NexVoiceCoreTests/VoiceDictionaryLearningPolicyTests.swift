import Testing
@testable import NexVoiceCore

@Test func dictionaryLearningPolicyExtractsLikelyProperNounCorrection() {
    let candidate = VoiceDictionaryLearningPolicy.candidate(
        baselineText: "我觉得耐克斯 voice 的体验还需要继续优化。",
        editedText: "我觉得 NexVoice 的体验还需要继续优化。",
        originalASRText: "我觉得耐克斯 voice 的体验还需要继续优化。",
        rewrittenText: "我觉得耐克斯 voice 的体验还需要继续优化。",
        context: VoiceRewriteContext(sourceApplicationName: "Cursor")
    )

    #expect(candidate?.incorrectText == "耐克斯 voice")
    #expect(candidate?.correctedText == "NexVoice")
}

@Test func dictionaryLearningPolicyRejectsPunctuationOnlyEdit() {
    let candidate = VoiceDictionaryLearningPolicy.candidate(
        baselineText: "这个功能很好",
        editedText: "这个功能很好。",
        originalASRText: "这个功能很好",
        rewrittenText: "这个功能很好",
        context: VoiceRewriteContext()
    )

    #expect(candidate == nil)
}

@Test func dictionaryLearningPolicyRejectsSentenceRewrite() {
    let candidate = VoiceDictionaryLearningPolicy.candidate(
        baselineText: "这个功能很好。",
        editedText: "这个功能现在整体可用，但还需要继续优化。",
        originalASRText: "这个功能很好。",
        rewrittenText: "这个功能很好。",
        context: VoiceRewriteContext()
    )

    #expect(candidate == nil)
}

@Test func dictionaryLearningPolicyRejectsEditingIntermediateSentenceAsAlias() {
    let candidate = VoiceDictionaryLearningPolicy.candidate(
        baselineText: "再去调研一下Tablets这个软件。",
        editedText: "Tablets",
        originalASRText: "再去调研一下Tablets这个软件。",
        rewrittenText: "再去调研一下Tablets这个软件。",
        context: VoiceRewriteContext(sourceApplicationName: "Codex")
    )

    #expect(candidate == nil)
}

@Test func dictionaryLearningPolicyRejectsGenericCommonWord() {
    #expect(!VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "速度",
        correctedText: "功能"
    ))
}

@Test func dictionaryLearningPolicyAsksModelForSingleEnglishTermCorrection() {
    #expect(VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "timeless",
        correctedText: "typeless"
    ))
}

@Test func dictionaryLearningPolicyRejectsOrdinaryEnglishPolishBeforeModel() {
    #expect(!VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "good",
        correctedText: "great"
    ))
}

@Test func dictionaryLearningPolicyAsksModelForMixedCaseTermCorrection() {
    #expect(VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "deep seek",
        correctedText: "DeepSeek"
    ))
}

@Test func dictionaryLearningPolicyAllowsDistantASRCorrectionToTechnicalTerm() {
    #expect(VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "是那只天猫",
        correctedText: "HTML"
    ))
}

@Test func dictionaryLearningPolicyRejectsInstructionSentenceAsDictionaryTerm() {
    #expect(!VoiceDictionaryLearningPolicy.shouldAskModel(
        incorrectText: "帮我到柜台上看一下",
        correctedText: "查看一下 Git 上有没有最新代码"
    ))
}
