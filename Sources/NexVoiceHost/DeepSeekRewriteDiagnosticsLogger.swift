import Foundation

actor DeepSeekRewriteDiagnosticsLogger {
    static let shared = DeepSeekRewriteDiagnosticsLogger()

    let fileURL: URL

    init(fileURL: URL = DeepSeekRewriteDiagnosticsLogger.defaultLogURL()) {
        self.fileURL = fileURL
    }

    func log(_ event: DeepSeekRewriteDiagnosticEvent) {
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
            // Diagnostics must never affect voice input or text insertion.
        }
    }

    private static func defaultLogURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DeepSeekRewrite.jsonl")
    }
}

struct DeepSeekRewriteDiagnosticEvent: Encodable {
    let timestamp: String
    let requestID: String
    let event: String
    let operation: String
    let model: String?
    let endpointHost: String?
    let outputLanguage: String?
    let rewriteStyle: String?
    let promptMode: String?
    let temperature: Double?
    let timeoutSeconds: Double?
    let latencyMs: Int?
    let httpStatus: Int?
    let finishReason: String?
    let promptCharacters: Int?
    let selectedTextCharacters: Int?
    let instructionCharacters: Int?
    let contextSummary: String?
    let outputCharacters: Int?
    let promptPreview: String?
    let outputPreview: String?
    let responseBodyPreview: String?
    let errorType: String?
    let errorMessage: String?

    init(
        requestID: String,
        event: String,
        operation: String,
        model: String? = nil,
        endpointHost: String? = nil,
        outputLanguage: String? = nil,
        rewriteStyle: String? = nil,
        promptMode: String? = nil,
        temperature: Double? = nil,
        timeoutSeconds: Double? = nil,
        latencyMs: Int? = nil,
        httpStatus: Int? = nil,
        finishReason: String? = nil,
        promptCharacters: Int? = nil,
        selectedTextCharacters: Int? = nil,
        instructionCharacters: Int? = nil,
        contextSummary: String? = nil,
        outputCharacters: Int? = nil,
        promptPreview: String? = nil,
        outputPreview: String? = nil,
        responseBodyPreview: String? = nil,
        errorType: String? = nil,
        errorMessage: String? = nil
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.requestID = requestID
        self.event = event
        self.operation = operation
        self.model = model
        self.endpointHost = endpointHost
        self.outputLanguage = outputLanguage
        self.rewriteStyle = rewriteStyle
        self.promptMode = promptMode
        self.temperature = temperature
        self.timeoutSeconds = timeoutSeconds
        self.latencyMs = latencyMs
        self.httpStatus = httpStatus
        self.finishReason = finishReason
        self.promptCharacters = promptCharacters
        self.selectedTextCharacters = selectedTextCharacters
        self.instructionCharacters = instructionCharacters
        self.contextSummary = contextSummary
        self.outputCharacters = outputCharacters
        self.promptPreview = promptPreview.map { Self.preview($0) }
        self.outputPreview = outputPreview.map { Self.preview($0) }
        self.responseBodyPreview = responseBodyPreview.map { Self.preview($0) }
        self.errorType = errorType
        self.errorMessage = errorMessage.map { Self.preview($0) }
    }

    private static func preview(_ text: String, limit: Int = 360) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "..." : prefix
    }
}
