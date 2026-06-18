import Testing
@testable import NexVoiceCore

@Test func transcriptionPartialAndFinalTextStaySeparated() {
    var transcript = VoiceLiveTranscript()

    transcript.apply(.partialTranscript("今天先讨论", isStable: false))
    #expect(transcript.sourceDraft == "今天先讨论")
    #expect(transcript.sourceText == "")

    transcript.apply(.finalTranscript("今天先讨论实时转写。"))
    #expect(transcript.sourceDraft == "")
    #expect(transcript.sourceText == "今天先讨论实时转写。")
}

@Test func translationEventsKeepSourceAndTargetDraftsUntilFinal() {
    var transcript = VoiceLiveTranscript()

    transcript.apply(.partialTranslation(sourceText: "我们开始", targetText: "Let's start"))
    #expect(transcript.sourceDraft == "我们开始")
    #expect(transcript.targetDraft == "Let's start")
    #expect(transcript.targetText == "")

    transcript.apply(.finalTranslation(sourceText: "我们开始吧。", targetText: "Let's get started."))
    #expect(transcript.sourceDraft == "")
    #expect(transcript.targetDraft == "")
    #expect(transcript.sourceText == "我们开始吧。")
    #expect(transcript.targetText == "Let's get started.")
}

@Test func textSegmentsAreJoinedWithSingleNewlines() {
    var transcript = VoiceLiveTranscript()

    transcript.apply(.finalTranscript("第一句。"))
    transcript.apply(.finalTranscript("第二句。"))

    #expect(transcript.sourceText == "第一句。\n第二句。")
}
