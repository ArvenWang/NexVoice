import Testing
@testable import NexVoiceCore

@Test func finalTranscriptProducesTrimmedTextForInsertion() {
    let text = VoiceFinalTextPolicy.insertionText(from: .finalTranscript("  今天下午三点开会。  "))

    #expect(text == "今天下午三点开会。")
}

@Test func partialTranscriptDoesNotProduceInsertionText() {
    let text = VoiceFinalTextPolicy.insertionText(from: .partialTranscript("今天下午", isStable: false))

    #expect(text == nil)
}

@Test func blankFinalTranscriptDoesNotProduceInsertionText() {
    let text = VoiceFinalTextPolicy.insertionText(from: .finalTranscript("  \n "))

    #expect(text == nil)
}

@Test func fallbackPartialProducesTrimmedInsertionTextWhenFinalIsMissing() {
    let text = VoiceFinalTextPolicy.fallbackInsertionText(fromPartialTranscript: "  这是临时识别文本  ")

    #expect(text == "这是临时识别文本")
}

@Test func blankFallbackPartialDoesNotProduceInsertionText() {
    let text = VoiceFinalTextPolicy.fallbackInsertionText(fromPartialTranscript: "\n  ")

    #expect(text == nil)
}

@Test func noSpeechDetectedMessageIsUserFacing() {
    #expect(VoiceFinalTextPolicy.noRecognizedSpeechMessage == "没有识别到语音，请确认麦克风输入后再试。")
}
