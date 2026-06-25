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
    let draftReadMethod: String?
    let actualInsertionMethod: String?
    let focusedDraftPreview: String?
    let newTranscriptPreview: String?
    let insertedTextCharacters: Int?
    let insertedTextNewlineCount: Int?
    let insertedTextBlankLineCount: Int?
    let insertedTextContainsBlankLine: Bool?
    let readbackAvailable: Bool?
    let readbackMethod: String?
    let readbackCharacters: Int?
    let readbackNewlineCount: Int?
    let readbackBlankLineCount: Int?
    let readbackContainsBlankLine: Bool?
    let readbackMatchesInsertedText: Bool?

    init(
        event: String,
        appName: String?,
        bundleIdentifier: String?,
        hasEditableSelection: Bool,
        focusedDraft: String?,
        newTranscript: String,
        insertionMode: VoiceContinuousRewriteInsertionMode,
        draftReadMethod: FocusedTextAccessMethod? = nil,
        actualInsertionMethod: FocusedTextAccessMethod? = nil,
        insertedText: String? = nil,
        readbackText: String? = nil,
        readbackMethod: FocusedTextAccessMethod? = nil,
        expectedReadbackText: String? = nil,
        includeTextPreviews: Bool = true
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.event = event
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.hasEditableSelection = hasEditableSelection
        self.focusedDraftCharacters = focusedDraft?.count ?? 0
        self.newTranscriptCharacters = newTranscript.count
        self.insertionMode = String(describing: insertionMode)
        self.draftReadMethod = draftReadMethod?.rawValue
        self.actualInsertionMethod = actualInsertionMethod?.rawValue
        self.focusedDraftPreview = includeTextPreviews ? focusedDraft.map { Self.preview($0) } : nil
        self.newTranscriptPreview = includeTextPreviews ? Self.preview(newTranscript) : nil

        let insertedStats = insertedText.map { Self.textStats($0) }
        self.insertedTextCharacters = insertedStats?.characters
        self.insertedTextNewlineCount = insertedStats?.newlineCount
        self.insertedTextBlankLineCount = insertedStats?.blankLineCount
        self.insertedTextContainsBlankLine = insertedStats?.containsBlankLine

        let readbackStats = readbackText.map { Self.textStats($0) }
        self.readbackAvailable = readbackText != nil
        self.readbackMethod = readbackMethod?.rawValue
        self.readbackCharacters = readbackStats?.characters
        self.readbackNewlineCount = readbackStats?.newlineCount
        self.readbackBlankLineCount = readbackStats?.blankLineCount
        self.readbackContainsBlankLine = readbackStats?.containsBlankLine
        if let readbackText, let expectedReadbackText {
            self.readbackMatchesInsertedText = Self.normalize(readbackText) == Self.normalize(expectedReadbackText)
        } else {
            self.readbackMatchesInsertedText = nil
        }
    }

    private static func preview(_ text: String, limit: Int = 360) -> String {
        let normalized = normalize(text)
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "..." : prefix
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func textStats(_ text: String) -> TextStats {
        let normalized = normalize(text)
        let newlineCount = normalized.filter { $0 == "\n" }.count
        let blankLinePattern = #"\n[ \t]*\n"#
        let blankLineCount = (try? NSRegularExpression(pattern: blankLinePattern))
            .map {
                $0.numberOfMatches(
                    in: normalized,
                    range: NSRange(normalized.startIndex..., in: normalized)
                )
            } ?? 0
        return TextStats(
            characters: normalized.count,
            newlineCount: newlineCount,
            blankLineCount: blankLineCount,
            containsBlankLine: blankLineCount > 0
        )
    }

    private struct TextStats {
        let characters: Int
        let newlineCount: Int
        let blankLineCount: Int
        let containsBlankLine: Bool
    }
}
