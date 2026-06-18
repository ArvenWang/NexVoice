import Foundation
import Testing
@testable import NexVoiceCore

@Test func localSenseVoiceDefaultsToManagedBackendDirectory() {
    let config = LocalSenseVoiceTranscriptionConfiguration(
        language: .simplifiedChinese,
        baseDirectory: URL(fileURLWithPath: "/tmp/NexVoiceSenseVoice")
    )

    #expect(config.pythonExecutableURL.path == "/tmp/NexVoiceSenseVoice/.venv/bin/python")
    #expect(config.modelDirectoryURL.lastPathComponent == "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17")
    #expect(config.modelURL.lastPathComponent == "model.int8.onnx")
    #expect(config.tokensURL.lastPathComponent == "tokens.txt")
    #expect(config.useInverseTextNormalization)
    #expect(config.numThreads == 4)
}

@Test func localSenseVoiceUsesAutoLanguageForChineseAndEnglishForEnglishMode() {
    #expect(LocalSenseVoiceTranscriptionConfiguration(language: .simplifiedChinese).senseVoiceLanguageCode == "auto")
    #expect(LocalSenseVoiceTranscriptionConfiguration(language: .englishUS).senseVoiceLanguageCode == "en")
}

@Test func localSenseVoiceBuildsStablePythonArguments() {
    let config = LocalSenseVoiceTranscriptionConfiguration(
        language: .simplifiedChinese,
        baseDirectory: URL(fileURLWithPath: "/tmp/NexVoiceSenseVoice")
    )
    let scriptURL = URL(fileURLWithPath: "/Applications/NexVoice.app/Contents/Resources/SenseVoiceTranscriber.py")
    let audioURL = URL(fileURLWithPath: "/tmp/input.wav")

    #expect(config.pythonArguments(scriptURL: scriptURL, audioURL: audioURL) == [
        "/Applications/NexVoice.app/Contents/Resources/SenseVoiceTranscriber.py",
        "--model", "/tmp/NexVoiceSenseVoice/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17/model.int8.onnx",
        "--tokens", "/tmp/NexVoiceSenseVoice/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17/tokens.txt",
        "--wave", "/tmp/input.wav",
        "--language", "auto",
        "--use-itn", "1",
        "--num-threads", "4"
    ])
}
