import AppKit
import Foundation
import NexVoiceCore

actor ShortcutDiagnosticsLogger {
    static let shared = ShortcutDiagnosticsLogger()

    let fileURL: URL

    init(fileURL: URL = ShortcutDiagnosticsLogger.defaultLogURL()) {
        self.fileURL = fileURL
    }

    func log(_ event: ShortcutDiagnosticEvent) {
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
            // 快捷键诊断不能影响录音、问答或文字写入。
        }
    }

    private static func defaultLogURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Shortcut.jsonl")
    }
}

struct ShortcutDiagnosticEvent: Encodable {
    let timestamp: String
    let event: String
    let source: String?
    let shortcut: String?
    let keyCode: UInt16?
    let eventType: String?
    let flagsRawValue: UInt64?
    let eventTimestampSeconds: Double?
    let deliveryDelayMs: Int?
    let matched: Bool?
    let isPressed: Bool?
    let isSuspended: Bool?
    let isSecondPressForDoubleTrigger: Bool?
    let didTriggerLongPress: Bool?
    let shouldDelayShortPress: Bool?
    let triggerKind: String?
    let routeAction: String?
    let transcriptionState: String?
    let interactionMode: String?
    let appName: String?
    let bundleIdentifier: String?
    let mouseLocation: ShortcutDiagnosticPoint?
    let usesRegisteredHotKey: Bool?
    let allowsEventMonitorFallback: Bool?
    let usesLowLevelKeyboardTapFallback: Bool?
    let didRegisterHotKey: Bool?
    let didStartKeyboardEventTap: Bool?
    let errorMessage: String?

    init(
        event: String,
        source: String? = nil,
        shortcut: VoiceShortcut? = nil,
        keyCode: UInt16? = nil,
        eventType: String? = nil,
        flagsRawValue: UInt64? = nil,
        eventTimestampSeconds: Double? = nil,
        deliveryDelayMs: Int? = nil,
        matched: Bool? = nil,
        isPressed: Bool? = nil,
        isSuspended: Bool? = nil,
        isSecondPressForDoubleTrigger: Bool? = nil,
        didTriggerLongPress: Bool? = nil,
        shouldDelayShortPress: Bool? = nil,
        triggerKind: String? = nil,
        routeAction: String? = nil,
        transcriptionState: String? = nil,
        interactionMode: String? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        mouseLocation: CGPoint? = nil,
        usesRegisteredHotKey: Bool? = nil,
        allowsEventMonitorFallback: Bool? = nil,
        usesLowLevelKeyboardTapFallback: Bool? = nil,
        didRegisterHotKey: Bool? = nil,
        didStartKeyboardEventTap: Bool? = nil,
        errorMessage: String? = nil
    ) {
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.event = event
        self.source = source
        self.shortcut = shortcut?.displayTitle
        self.keyCode = keyCode
        self.eventType = eventType
        self.flagsRawValue = flagsRawValue
        self.eventTimestampSeconds = eventTimestampSeconds
        self.deliveryDelayMs = deliveryDelayMs
        self.matched = matched
        self.isPressed = isPressed
        self.isSuspended = isSuspended
        self.isSecondPressForDoubleTrigger = isSecondPressForDoubleTrigger
        self.didTriggerLongPress = didTriggerLongPress
        self.shouldDelayShortPress = shouldDelayShortPress
        self.triggerKind = triggerKind
        self.routeAction = routeAction
        self.transcriptionState = transcriptionState
        self.interactionMode = interactionMode
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.mouseLocation = mouseLocation.map(ShortcutDiagnosticPoint.init)
        self.usesRegisteredHotKey = usesRegisteredHotKey
        self.allowsEventMonitorFallback = allowsEventMonitorFallback
        self.usesLowLevelKeyboardTapFallback = usesLowLevelKeyboardTapFallback
        self.didRegisterHotKey = didRegisterHotKey
        self.didStartKeyboardEventTap = didStartKeyboardEventTap
        self.errorMessage = errorMessage.map { String($0.prefix(1_000)) }
    }
}

struct ShortcutDiagnosticPoint: Encodable {
    let x: Double
    let y: Double

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}
