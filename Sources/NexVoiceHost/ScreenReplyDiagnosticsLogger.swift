import Foundation

actor ScreenReplyDiagnosticsLogger {
    static let shared = ScreenReplyDiagnosticsLogger()

    let fileURL: URL

    init(fileURL: URL = ScreenReplyDiagnosticsLogger.defaultLogURL()) {
        self.fileURL = fileURL
    }

    func log(_ event: ScreenReplyDiagnosticEvent) {
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
            // Screen reply diagnostics must never affect capture, generation, or insertion.
        }
    }

    private static func defaultLogURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ScreenReply.jsonl")
    }
}

struct ScreenReplyDiagnosticEvent: Encodable {
    let timestamp: String
    let captureID: String
    let event: String
    let interactionMode: String?
    let captureMode: ScreenReplyCaptureMode?
    let appName: String?
    let bundleIdentifier: String?
    let windowTitle: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let inputFrame: ScreenReplyDiagnosticRect?
    let replyRegion: ScreenReplyDiagnosticRect?
    let mouseLocation: ScreenReplyDiagnosticPoint?
    let mouseRegion: ScreenReplyDiagnosticRect?
    let mouseRegionInScreen: ScreenReplyDiagnosticRect?
    let lineCount: Int?
    let visibleTextCharacters: Int?
    let structuredMessagesCharacters: Int?
    let visibleText: String?
    let structuredMessages: String?
    let lines: [ScreenReplyCapturedLine]?
    let contextSource: String?
    let selectedTextCharacters: Int?
    let selectedText: String?
    let voiceInstructionCharacters: Int?
    let voiceInstruction: String?
    let replyCharacters: Int?
    let replyPreview: String?
    let errorMessage: String?

    init(
        captureID: String,
        event: String,
        interactionMode: String? = nil,
        captureMode: ScreenReplyCaptureMode? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        windowTitle: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        inputFrame: CGRect? = nil,
        replyRegion: CGRect? = nil,
        mouseLocation: CGPoint? = nil,
        mouseRegion: CGRect? = nil,
        mouseRegionInScreen: CGRect? = nil,
        lineCount: Int? = nil,
        visibleText: String? = nil,
        structuredMessages: String? = nil,
        lines: [ScreenReplyCapturedLine]? = nil,
        contextSource: String? = nil,
        selectedText: String? = nil,
        voiceInstruction: String? = nil,
        reply: String? = nil,
        errorMessage: String? = nil
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.captureID = captureID
        self.event = event
        self.interactionMode = interactionMode
        self.captureMode = captureMode
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.inputFrame = inputFrame.map(ScreenReplyDiagnosticRect.init)
        self.replyRegion = replyRegion.map(ScreenReplyDiagnosticRect.init)
        self.mouseLocation = mouseLocation.map(ScreenReplyDiagnosticPoint.init)
        self.mouseRegion = mouseRegion.map(ScreenReplyDiagnosticRect.init)
        self.mouseRegionInScreen = mouseRegionInScreen.map(ScreenReplyDiagnosticRect.init)
        self.lineCount = lineCount
        self.visibleTextCharacters = visibleText?.count
        self.structuredMessagesCharacters = structuredMessages?.count
        self.visibleText = visibleText.map { Self.logText($0) }
        self.structuredMessages = structuredMessages.map { Self.logText($0) }
        self.lines = lines
        self.contextSource = contextSource
        self.selectedTextCharacters = selectedText?.count
        self.selectedText = selectedText.map { Self.logText($0, limit: 4_000) }
        self.voiceInstructionCharacters = voiceInstruction?.count
        self.voiceInstruction = voiceInstruction.map { Self.logText($0, limit: 4_000) }
        self.replyCharacters = reply?.count
        self.replyPreview = reply.map { Self.logText($0, limit: 1_000) }
        self.errorMessage = errorMessage.map { Self.logText($0, limit: 1_000) }
    }

    private static func logText(_ text: String, limit: Int = 12_000) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let prefix = String(normalized.prefix(limit))
        return normalized.count > limit ? prefix + "\n...[truncated]" : prefix
    }
}

struct ScreenReplyDiagnosticRect: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
    }
}

struct ScreenReplyDiagnosticPoint: Encodable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}
