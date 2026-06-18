import Foundation

public struct LocalSenseVoiceTranscriptionConfiguration: Equatable, Sendable {
    public static let modelDirectoryName = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"

    public let language: SpeechRecognitionLanguage
    public let baseDirectory: URL
    public let useInverseTextNormalization: Bool
    public let numThreads: Int

    public init(
        language: SpeechRecognitionLanguage = .simplifiedChinese,
        baseDirectory: URL = Self.defaultBaseDirectory,
        useInverseTextNormalization: Bool = true,
        numThreads: Int = 4
    ) {
        self.language = language
        self.baseDirectory = baseDirectory
        self.useInverseTextNormalization = useInverseTextNormalization
        self.numThreads = max(1, numThreads)
    }

    public static var defaultBaseDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("SenseVoice", isDirectory: true)
    }

    public var pythonExecutableURL: URL {
        baseDirectory
            .appendingPathComponent(".venv", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("python")
    }

    public var modelDirectoryURL: URL {
        baseDirectory.appendingPathComponent(Self.modelDirectoryName, isDirectory: true)
    }

    public var modelURL: URL {
        modelDirectoryURL.appendingPathComponent("model.int8.onnx")
    }

    public var tokensURL: URL {
        modelDirectoryURL.appendingPathComponent("tokens.txt")
    }

    public var senseVoiceLanguageCode: String {
        switch language {
        case .simplifiedChinese:
            // Chinese mode often contains English words; auto performs better for mixed input.
            return "auto"
        case .englishUS:
            return "en"
        }
    }

    public func pythonArguments(scriptURL: URL, audioURL: URL) -> [String] {
        [
            scriptURL.path,
            "--model", modelURL.path,
            "--tokens", tokensURL.path,
            "--wave", audioURL.path,
            "--language", senseVoiceLanguageCode,
            "--use-itn", useInverseTextNormalization ? "1" : "0",
            "--num-threads", "\(numThreads)"
        ]
    }
}
