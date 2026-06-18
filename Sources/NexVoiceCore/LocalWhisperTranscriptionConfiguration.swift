import Foundation

public struct LocalWhisperTranscriptionConfiguration: Equatable, Sendable {
    public let language: SpeechRecognitionLanguage
    public let backend: LocalASRBackend
    public let modelName: String

    public init(
        language: SpeechRecognitionLanguage = .simplifiedChinese,
        backend: LocalASRBackend = .default,
        modelName: String = "openai_whisper-large-v3-v20240930_626MB"
    ) {
        self.language = language
        self.backend = backend
        self.modelName = modelName
    }

    public var whisperLanguageCode: String {
        switch language {
        case .simplifiedChinese:
            return "zh"
        case .englishUS:
            return "en"
        }
    }
}

public enum LocalWhisperTranscriptionError: Error, LocalizedError, Equatable, Sendable {
    case alreadyRunning
    case microphonePermissionMissing
    case noRecordedAudio
    case modelUnavailable(String)
    case transcriptionTimedOut(seconds: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "本地转写已经在运行。"
        case .microphonePermissionMissing:
            return "请先允许 NexVoice 使用麦克风。"
        case .noRecordedAudio:
            return "没有录到可转写的语音。"
        case .modelUnavailable(let message):
            return "本地 ASR 引擎不可用：\(message)"
        case .transcriptionTimedOut:
            return "本地转写超时。首次使用需要下载模型，请确认网络稳定后再试。"
        }
    }
}
