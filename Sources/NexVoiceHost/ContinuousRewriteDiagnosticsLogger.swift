import Foundation
import NexVoiceCore

actor ContinuousRewriteDiagnosticsLogger {
    static let shared = ContinuousRewriteDiagnosticsLogger()

    let fileURL: URL

    init(fileURL: URL = ContinuousRewriteDiagnosticsLogger.defaultLogURL()) {
        self.fileURL = fileURL
    }

    func log(_ event: ContinuousRewriteDiagnosticEvent) {
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
            .appendingPathComponent("ContinuousRewrite.jsonl")
    }
}

struct ContinuousRewriteDiagnosticEvent: Encodable {
    let timestamp: String
    let event: String
    let appName: String?
    let bundleIdentifier: String?
    let hasEditableSelection: Bool
    let focusedDraftCharacters: Int
    let newTranscriptCharacters: Int
    let insertionMode: String
    let focusedDraftPreview: String?
    let newTranscriptPreview: String?

    init(
        event: String,
        appName: String?,
        bundleIdentifier: String?,
        hasEditableSelection: Bool,
        focusedDraft: String?,
        newTranscript: String,
        insertionMode: VoiceContinuousRewriteInsertionMode
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.event = event
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.hasEditableSelection = hasEditableSelection
        self.focusedDraftCharacters = focusedDraft?.count ?? 0
        self.newTranscriptCharacters = newTranscript.count
        self.insertionMode = String(describing: insertionMode)
        self.focusedDraftPreview = focusedDraft.map { Self.preview($0) }
        self.newTranscriptPreview = Self.preview(newTranscript)
    }

    private static func preview(_ text: String, limit: Int = 360) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "..." : prefix
    }
}
