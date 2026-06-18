import Foundation
import NexVoiceCore

final class SenseVoiceCommandTranscriber: @unchecked Sendable {
    enum Error: LocalizedError, Equatable {
        case missingPython(String)
        case missingScript
        case missingModel(String)
        case processFailed(status: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .missingPython(let path):
                return "SenseVoice Python 环境不存在：\(path)。请先运行 scripts/install_sensevoice_backend.sh。"
            case .missingScript:
                return "SenseVoice 转写脚本没有打进应用资源。"
            case .missingModel(let path):
                return "SenseVoice 模型文件不存在：\(path)。请先运行 scripts/install_sensevoice_backend.sh。"
            case .processFailed(let status, let stderr):
                let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return "SenseVoice 进程退出码 \(status)：\(message.isEmpty ? "无错误输出" : message)"
            }
        }
    }

    func transcribe(
        audioURL: URL,
        configuration: LocalSenseVoiceTranscriptionConfiguration
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try self.run(audioURL: audioURL, configuration: configuration)
        }.value
    }

    private func run(
        audioURL: URL,
        configuration: LocalSenseVoiceTranscriptionConfiguration
    ) throws -> String {
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: configuration.pythonExecutableURL.path) else {
            throw Error.missingPython(configuration.pythonExecutableURL.path)
        }
        guard let scriptURL = findTranscriberScript() else {
            throw Error.missingScript
        }
        guard fileManager.fileExists(atPath: configuration.modelURL.path) else {
            throw Error.missingModel(configuration.modelURL.path)
        }
        guard fileManager.fileExists(atPath: configuration.tokensURL.path) else {
            throw Error.missingModel(configuration.tokensURL.path)
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = configuration.pythonExecutableURL
        process.arguments = configuration.pythonArguments(scriptURL: scriptURL, audioURL: audioURL)
        process.currentDirectoryURL = configuration.baseDirectory
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            throw Error.processFailed(
                status: process.terminationStatus,
                stderr: String(data: errorOutput, encoding: .utf8) ?? ""
            )
        }
        return try SenseVoiceTranscriptionOutput.transcribedText(from: output)
    }

    private func findTranscriberScript() -> URL? {
        let fileManager = FileManager.default
        let scriptName = "SenseVoiceTranscriber.py"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(scriptName),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("NexVoiceHost", isDirectory: true)
                .appendingPathComponent(scriptName),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("NexVoiceHost", isDirectory: true)
                .appendingPathComponent(scriptName)
        ]
        return candidates.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }
}
