import AppKit
import CoreGraphics
import Foundation
import Vision

struct ScreenReplyCapturedContext: Sendable {
    let appName: String?
    let bundleIdentifier: String?
    let windowTitle: String?
    let visibleText: String
    let structuredMessages: String
    let lineCount: Int
}

enum ScreenReplyCaptureError: LocalizedError {
    case screenRecordingPermissionRequired
    case noFrontmostApplication
    case noVisibleWindow
    case captureFailed
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionRequired:
            return "需要屏幕录制权限，才能读取当前窗口可见文字。"
        case .noFrontmostApplication:
            return "没有找到当前前台应用。"
        case .noVisibleWindow:
            return "没有找到当前应用的可见窗口。"
        case .captureFailed:
            return "当前窗口截图失败。"
        case .noRecognizedText:
            return "没有识别到当前窗口里的文字。"
        }
    }
}

@MainActor
final class ScreenReplyContextCaptureService {
    func capture(from application: NSRunningApplication?) async throws -> ScreenReplyCapturedContext {
        guard SystemPermissionRequester.hasScreenRecordingPermission else {
            throw ScreenReplyCaptureError.screenRecordingPermissionRequired
        }
        guard let application else {
            throw ScreenReplyCaptureError.noFrontmostApplication
        }
        guard let window = Self.bestVisibleWindow(for: application.processIdentifier) else {
            throw ScreenReplyCaptureError.noVisibleWindow
        }
        guard let image = Self.capture(windowID: window.id) else {
            throw ScreenReplyCaptureError.captureFailed
        }

        let lines = try await Self.recognizeText(in: image)
        guard !lines.isEmpty else {
            throw ScreenReplyCaptureError.noRecognizedText
        }

        let visibleText = lines.map(\.text).joined(separator: "\n")
        let structuredMessages = Self.structuredMessages(from: lines, imageWidth: CGFloat(image.width))
        return ScreenReplyCapturedContext(
            appName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            windowTitle: window.title,
            visibleText: visibleText,
            structuredMessages: structuredMessages,
            lineCount: lines.count
        )
    }

    @MainActor
    static func requestScreenRecordingPermission() {
        if !SystemPermissionRequester.requestScreenRecordingPermission() {
            SystemPermissionRequester.openScreenRecordingSettings()
        }
    }

    private struct WindowInfo: Sendable {
        let id: CGWindowID
        let title: String?
        let bounds: CGRect
    }

    private struct OCRLine: Sendable {
        let text: String
        let rect: CGRect
        let confidence: Float
    }

    private static func bestVisibleWindow(for processIdentifier: pid_t) -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let candidates = windowList.compactMap { info -> WindowInfo? in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowIsOnscreen as String] as? Bool) == true,
                  let idNumber = info[kCGWindowNumber as String] as? UInt32,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
                return nil
            }
            guard bounds.width > 120, bounds.height > 80 else { return nil }
            return WindowInfo(
                id: CGWindowID(idNumber),
                title: info[kCGWindowName as String] as? String,
                bounds: bounds
            )
        }

        return candidates.max { lhs, rhs in
            lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
        }
    }

    private static func capture(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    private static func recognizeText(in image: CGImage) async throws -> [OCRLine] {
        try await Task.detached(priority: .userInitiated) {
            var recognizedLines: [OCRLine] = []
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                recognizedLines = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    let box = observation.boundingBox
                    let rect = CGRect(
                        x: box.minX * CGFloat(image.width),
                        y: (1 - box.maxY) * CGFloat(image.height),
                        width: box.width * CGFloat(image.width),
                        height: box.height * CGFloat(image.height)
                    )
                    return OCRLine(text: text, rect: rect, confidence: candidate.confidence)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return recognizedLines
                .filter { $0.confidence >= 0.25 }
                .sorted { lhs, rhs in
                    if abs(lhs.rect.minY - rhs.rect.minY) > 8 {
                        return lhs.rect.minY < rhs.rect.minY
                    }
                    return lhs.rect.minX < rhs.rect.minX
                }
        }.value
    }

    private static func structuredMessages(from lines: [OCRLine], imageWidth: CGFloat) -> String {
        let rows = lines.map { line -> String in
            let centerX = line.rect.midX
            let speaker: String
            if centerX > imageWidth * 0.60 {
                speaker = "我"
            } else if centerX < imageWidth * 0.48 {
                speaker = "对方"
            } else {
                speaker = "未知"
            }
            return "\(speaker)：\(line.text)"
        }
        return rows.joined(separator: "\n")
    }
}
