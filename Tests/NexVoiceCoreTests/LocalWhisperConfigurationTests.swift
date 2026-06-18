import Testing
@testable import NexVoiceCore

@Test func localWhisperDefaultsToBalancedMultilingualModel() {
    #expect(LocalWhisperTranscriptionConfiguration().modelName == "openai_whisper-large-v3-v20240930_626MB")
}

@Test func localWhisperMapsAppLanguagesToWhisperLanguageCodes() {
    #expect(LocalWhisperTranscriptionConfiguration(language: .simplifiedChinese).whisperLanguageCode == "zh")
    #expect(LocalWhisperTranscriptionConfiguration(language: .englishUS).whisperLanguageCode == "en")
}

@Test func localWhisperRequiresRecordingBeforeTranscription() {
    let error = LocalWhisperTranscriptionError.noRecordedAudio

    #expect(error.errorDescription == "没有录到可转写的语音。")
}

@Test func localWhisperReportsTimeoutClearly() {
    let error = LocalWhisperTranscriptionError.transcriptionTimedOut(seconds: 90)

    #expect(error.errorDescription == "本地转写超时。首次使用需要下载模型，请确认网络稳定后再试。")
}

@Test func localTranscriptionReportsBackendUnavailableClearly() {
    let error = LocalWhisperTranscriptionError.modelUnavailable("missing runtime")

    #expect(error.errorDescription == "本地 ASR 引擎不可用：missing runtime")
}
