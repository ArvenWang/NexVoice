import Foundation

actor TencentCloudASRDiagnosticsLogger {
    static let shared = TencentCloudASRDiagnosticsLogger()

    let fileURL: URL

    init(fileURL: URL = TencentCloudASRDiagnosticsLogger.defaultLogURL()) {
        self.fileURL = fileURL
    }

    func log(_ event: TencentCloudASRDiagnosticEvent) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            var data = try encoder.encode(event)
            data.append(0x0A)

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // ASR diagnostics must never interrupt transcription.
        }
    }

    private static func defaultLogURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("TencentCloudASR.jsonl")
    }
}

struct TencentCloudASRDiagnosticEvent: Encodable {
    let timestamp: String
    let sessionID: String
    let event: String
    let engineModelType: String?
    let frameDurationMilliseconds: Int?
    let hasHotwords: Bool?
    let hotwordCount: Int?
    let latencyMs: Int?
    let finishToFinalMs: Int?
    let partialCharacters: Int?
    let finalCharacters: Int?
    let partialPreview: String?
    let finalPreview: String?
    let errorMessage: String?

    init(
        sessionID: String,
        event: String,
        engineModelType: String? = nil,
        frameDurationMilliseconds: Int? = nil,
        hasHotwords: Bool? = nil,
        hotwordCount: Int? = nil,
        latencyMs: Int? = nil,
        finishToFinalMs: Int? = nil,
        partialCharacters: Int? = nil,
        finalCharacters: Int? = nil,
        partialPreview: String? = nil,
        finalPreview: String? = nil,
        errorMessage: String? = nil
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.sessionID = sessionID
        self.event = event
        self.engineModelType = engineModelType
        self.frameDurationMilliseconds = frameDurationMilliseconds
        self.hasHotwords = hasHotwords
        self.hotwordCount = hotwordCount
        self.latencyMs = latencyMs
        self.finishToFinalMs = finishToFinalMs
        self.partialCharacters = partialCharacters
        self.finalCharacters = finalCharacters
        self.partialPreview = partialPreview.map { Self.preview($0) }
        self.finalPreview = finalPreview.map { Self.preview($0) }
        self.errorMessage = errorMessage.map { Self.preview($0) }
    }

    private static func preview(_ text: String, limit: Int = 180) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "..." : prefix
    }
}
