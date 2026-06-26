import AppKit
import CoreGraphics
import Foundation
import Vision

@MainActor
final class MouseContextCaptureService {
    private struct OCRLine: Sendable {
        let id: Int
        let text: String
        let rectInScreen: CGRect
        let confidence: Float
    }

    private struct OCRResult: Sendable {
        let lines: [OCRLine]
        let durationMs: Double
    }

    private struct CaptureAttempt {
        let region: CGRect
        let maximumAnchorDistance: CGFloat
    }

    private struct MouseFocusedContext {
        let region: CGRect
        let includedLineIDs: Set<Int>
    }

    static func previewRegion(around mouseLocation: CGPoint) -> CGRect {
        screenRegion(centeredAt: mouseLocation, size: CGSize(width: 900, height: 380))
    }

    func capture(
        mouseScreenLocation: CGPoint,
        appName: String?,
        bundleIdentifier: String?,
        excludingWindowNumber: Int? = nil,
        interactionMode: String? = nil
    ) async throws -> ScreenReplyCapturedContext {
        guard SystemPermissionRequester.hasScreenRecordingPermission else {
            throw ScreenReplyCaptureError.screenRecordingPermissionRequired
        }

        let captureID = UUID().uuidString
        let attempts = [
            CaptureAttempt(
                region: Self.screenRegion(centeredAt: mouseScreenLocation, size: CGSize(width: 900, height: 380)),
                maximumAnchorDistance: 140
            ),
            CaptureAttempt(
                region: Self.screenRegion(centeredAt: mouseScreenLocation, size: CGSize(width: 1_280, height: 620)),
                maximumAnchorDistance: 240
            )
        ]

        var lastRecognizedLines: [OCRLine] = []
        var lastCaptureRegion: CGRect?
        var lastImageWidth: Int?
        var lastImageHeight: Int?
        var totalCaptureDurationMs: Double = 0
        var totalOCRDurationMs: Double = 0

        for attempt in attempts {
            let captureStartedAt = Date()
            guard let image = Self.captureScreenRegion(
                attempt.region,
                excludingWindowNumber: excludingWindowNumber
            ) else {
                continue
            }
            let captureDurationMs = Date().timeIntervalSince(captureStartedAt) * 1_000
            let ocrResult = try await Self.recognizeText(
                in: image,
                screenRegion: attempt.region
            )
            totalCaptureDurationMs += captureDurationMs
            totalOCRDurationMs += ocrResult.durationMs
            lastRecognizedLines = ocrResult.lines
            lastCaptureRegion = attempt.region
            lastImageWidth = image.width
            lastImageHeight = image.height

            guard !ocrResult.lines.isEmpty,
                  let mouseContext = Self.mouseFocusedContext(
                    from: ocrResult.lines,
                    mouseLocation: mouseScreenLocation,
                    captureRegion: attempt.region,
                    maximumAnchorDistance: attempt.maximumAnchorDistance
                  ) else {
                continue
            }

            let capturedLines = Self.capturedLines(
                from: ocrResult.lines,
                includedLineIDs: mouseContext.includedLineIDs
            )
            let replyLines = capturedLines.filter(\.includedInReplyContext)
            let visibleText = replyLines.map(\.text).joined(separator: "\n")
            let structuredMessages = Self.structuredMessages(from: replyLines)
            guard !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            await ScreenReplyDiagnosticsLogger.shared.log(
                ScreenReplyDiagnosticEvent(
                    captureID: captureID,
                    event: "mouse_visual_captured",
                    interactionMode: interactionMode,
                    captureMode: .mouseRegion,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    imageWidth: image.width,
                    imageHeight: image.height,
                    mouseScreenLocation: mouseScreenLocation,
                    ocrCropRegion: attempt.region,
                    mouseRegion: mouseContext.region,
                    mouseRegionInScreen: mouseContext.region,
                    screenCaptureRegion: attempt.region,
                    captureDurationMs: totalCaptureDurationMs,
                    ocrDurationMs: totalOCRDurationMs,
                    lineCount: ocrResult.lines.count,
                    visibleText: visibleText,
                    structuredMessages: structuredMessages,
                    lines: capturedLines,
                    contextSource: "screen_region_ocr"
                )
            )

            return ScreenReplyCapturedContext(
                captureMode: .mouseRegion,
                captureID: captureID,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                windowTitle: nil,
                visibleText: visibleText,
                structuredMessages: structuredMessages,
                lines: capturedLines,
                lineCount: ocrResult.lines.count,
                inputFrameInWindow: nil,
                replyRegionInWindow: nil,
                mouseLocationInWindow: nil,
                mouseRegionInWindow: nil,
                mouseAnchorRectInScreen: CGRect(origin: mouseScreenLocation, size: .zero),
                mouseRegionInScreen: mouseContext.region
            )
        }

        if let lastCaptureRegion {
            let capturedLines = Self.capturedLines(from: lastRecognizedLines, includedLineIDs: [])
            let visibleText = capturedLines.map(\.text).joined(separator: "\n")
            await ScreenReplyDiagnosticsLogger.shared.log(
                ScreenReplyDiagnosticEvent(
                    captureID: captureID,
                    event: lastRecognizedLines.isEmpty ? "mouse_visual_no_text" : "mouse_visual_region_missed",
                    interactionMode: interactionMode,
                    captureMode: .mouseRegion,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    imageWidth: lastImageWidth,
                    imageHeight: lastImageHeight,
                    mouseScreenLocation: mouseScreenLocation,
                    ocrCropRegion: lastCaptureRegion,
                    screenCaptureRegion: lastCaptureRegion,
                    captureDurationMs: totalCaptureDurationMs,
                    ocrDurationMs: totalOCRDurationMs,
                    lineCount: lastRecognizedLines.count,
                    visibleText: visibleText,
                    lines: capturedLines,
                    contextSource: "screen_region_ocr"
                )
            )
        }

        throw lastRecognizedLines.isEmpty
            ? ScreenReplyCaptureError.noRecognizedText
            : ScreenReplyCaptureError.noMouseRegionText
    }

    private static func captureScreenRegion(
        _ appKitRegion: CGRect,
        excludingWindowNumber: Int?
    ) -> CGImage? {
        let quartzRect = quartzRect(fromAppKitScreenRect: appKitRegion)
        if let excludingWindowNumber, excludingWindowNumber > 0 {
            return CGWindowListCreateImage(
                quartzRect,
                .optionOnScreenBelowWindow,
                CGWindowID(excludingWindowNumber),
                [.bestResolution]
            )
        }
        return CGWindowListCreateImage(
            quartzRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    private static func recognizeText(
        in image: CGImage,
        screenRegion: CGRect
    ) async throws -> OCRResult {
        let startedAt = Date()
        let lines = try await Task.detached(priority: .userInitiated) {
            var recognizedLines: [OCRLine] = []
            let request = VNRecognizeTextRequest { request, error in
                if error != nil {
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                recognizedLines = observations.enumerated().compactMap { index, observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    let box = observation.boundingBox
                    let rectInImage = CGRect(
                        x: box.minX * CGFloat(image.width),
                        y: (1 - box.maxY) * CGFloat(image.height),
                        width: box.width * CGFloat(image.width),
                        height: box.height * CGFloat(image.height)
                    )
                    let rectInScreen = appKitScreenRect(
                        fromTopLeftImageRect: rectInImage,
                        imageSize: CGSize(width: image.width, height: image.height),
                        screenRegion: screenRegion
                    )
                    return OCRLine(
                        id: index,
                        text: text,
                        rectInScreen: rectInScreen,
                        confidence: candidate.confidence
                    )
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return recognizedLines
                .filter { $0.confidence >= 0.20 }
                .sorted { lhs, rhs in
                    if abs(lhs.rectInScreen.midY - rhs.rectInScreen.midY) > 8 {
                        return lhs.rectInScreen.midY > rhs.rectInScreen.midY
                    }
                    return lhs.rectInScreen.minX < rhs.rectInScreen.minX
                }
        }.value
        return OCRResult(
            lines: lines,
            durationMs: Date().timeIntervalSince(startedAt) * 1_000
        )
    }

    private static func mouseFocusedContext(
        from lines: [OCRLine],
        mouseLocation: CGPoint,
        captureRegion: CGRect,
        maximumAnchorDistance: CGFloat
    ) -> MouseFocusedContext? {
        let candidates = lines.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && captureRegion.insetBy(dx: -2, dy: -2).intersects($0.rectInScreen)
        }
        guard let anchor = candidates.min(by: { lhs, rhs in
            distance(from: mouseLocation, to: lhs.rectInScreen.insetBy(dx: -12, dy: -8))
                < distance(from: mouseLocation, to: rhs.rectInScreen.insetBy(dx: -12, dy: -8))
        }) else {
            return nil
        }

        let anchorDistance = distance(from: mouseLocation, to: anchor.rectInScreen.insetBy(dx: -16, dy: -10))
        guard anchorDistance <= max(maximumAnchorDistance, anchor.rectInScreen.height * 2.4) else {
            return nil
        }

        var includedIDs: Set<Int> = [anchor.id]
        var region = anchor.rectInScreen
        var didChange = true

        while didChange, includedIDs.count < 8 {
            didChange = false
            let nextLine = candidates
                .filter { !includedIDs.contains($0.id) }
                .compactMap { line -> (line: OCRLine, score: CGFloat)? in
                    guard shouldIncludeParagraphLine(line.rectInScreen, anchor: anchor.rectInScreen, currentRegion: region) else {
                        return nil
                    }
                    let score = verticalGap(between: region, and: line.rectInScreen)
                        + abs(line.rectInScreen.midY - anchor.rectInScreen.midY) * 0.08
                    return (line, score)
                }
                .min { $0.score < $1.score }?
                .line

            if let nextLine {
                includedIDs.insert(nextLine.id)
                region = region.union(nextLine.rectInScreen)
                didChange = true
            }
        }

        let padded = region.insetBy(dx: -6, dy: -5).intersection(captureRegion)
        guard !padded.isNull, !includedIDs.isEmpty else { return nil }
        return MouseFocusedContext(region: padded, includedLineIDs: includedIDs)
    }

    private static func shouldIncludeParagraphLine(
        _ line: CGRect,
        anchor: CGRect,
        currentRegion: CGRect
    ) -> Bool {
        let anchorLineHeight = max(1, anchor.height)
        let gap = verticalGap(between: currentRegion, and: line)
        guard gap <= max(10, min(28, anchorLineHeight * 1.35)) else {
            return false
        }

        let expanded = currentRegion.union(line)
        guard expanded.height <= max(120, anchorLineHeight * 7.5),
              expanded.width <= max(anchor.width * 1.65, 1_080) else {
            return false
        }

        let overlapWidth = max(0, min(currentRegion.maxX, line.maxX) - max(currentRegion.minX, line.minX))
        let overlapRatio = overlapWidth / max(1, min(currentRegion.width, line.width))
        let leftEdgeDistance = abs(line.minX - anchor.minX)
        let centerDistance = abs(line.midX - anchor.midX)
        let rightEdgeDistance = abs(line.maxX - anchor.maxX)

        return overlapRatio >= 0.28
            || leftEdgeDistance <= max(42, anchorLineHeight * 2.8)
            || rightEdgeDistance <= max(64, anchorLineHeight * 3.2)
            || centerDistance <= max(150, anchor.width * 0.42)
    }

    private static func capturedLines(
        from lines: [OCRLine],
        includedLineIDs: Set<Int>
    ) -> [ScreenReplyCapturedLine] {
        lines.map { line in
            ScreenReplyCapturedLine(
                speaker: "屏幕",
                text: line.text,
                confidence: line.confidence,
                x: line.rectInScreen.minX,
                y: line.rectInScreen.minY,
                width: line.rectInScreen.width,
                height: line.rectInScreen.height,
                includedInReplyContext: includedLineIDs.contains(line.id)
            )
        }
    }

    private static func structuredMessages(from lines: [ScreenReplyCapturedLine]) -> String {
        lines.map { "\($0.speaker)：\($0.text)" }.joined(separator: "\n")
    }

    private static func screenRegion(centeredAt point: CGPoint, size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.insetBy(dx: -2, dy: -2).contains(point) }
            ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(origin: .zero, size: size)
        let width = min(size.width, screenFrame.width)
        let height = min(size.height, screenFrame.height)
        let raw = CGRect(
            x: point.x - width / 2,
            y: point.y - height / 2,
            width: width,
            height: height
        )
        return CGRect(
            x: min(max(raw.minX, screenFrame.minX), max(screenFrame.minX, screenFrame.maxX - width)),
            y: min(max(raw.minY, screenFrame.minY), max(screenFrame.minY, screenFrame.maxY - height)),
            width: width,
            height: height
        )
    }

    private static func quartzRect(fromAppKitScreenRect rect: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) || $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) })
            ?? NSScreen.main else {
            return rect
        }
        return CGRect(
            x: rect.minX,
            y: screen.frame.minY + (screen.frame.maxY - rect.maxY),
            width: rect.width,
            height: rect.height
        )
    }

    nonisolated private static func appKitScreenRect(
        fromTopLeftImageRect rect: CGRect,
        imageSize: CGSize,
        screenRegion: CGRect
    ) -> CGRect {
        let scaleX = screenRegion.width / max(1, imageSize.width)
        let scaleY = screenRegion.height / max(1, imageSize.height)
        return CGRect(
            x: screenRegion.minX + rect.minX * scaleX,
            y: screenRegion.maxY - rect.maxY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    private static func verticalGap(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        if lhs.maxY < rhs.minY {
            return rhs.minY - lhs.maxY
        }
        if rhs.maxY < lhs.minY {
            return lhs.minY - rhs.maxY
        }
        return 0
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx: CGFloat
        if point.x < rect.minX {
            dx = rect.minX - point.x
        } else if point.x > rect.maxX {
            dx = point.x - rect.maxX
        } else {
            dx = 0
        }

        let dy: CGFloat
        if point.y < rect.minY {
            dy = rect.minY - point.y
        } else if point.y > rect.maxY {
            dy = point.y - rect.maxY
        } else {
            dy = 0
        }
        return sqrt(dx * dx + dy * dy)
    }
}
