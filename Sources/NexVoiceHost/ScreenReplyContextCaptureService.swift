import AppKit
import CoreGraphics
import Foundation
import Vision

struct ScreenReplyCapturedContext: Sendable {
    let captureMode: ScreenReplyCaptureMode
    let captureID: String
    let appName: String?
    let bundleIdentifier: String?
    let windowTitle: String?
    let visibleText: String
    let structuredMessages: String
    let lines: [ScreenReplyCapturedLine]
    let lineCount: Int
    let inputFrameInWindow: CGRect?
    let replyRegionInWindow: CGRect?
    let mouseLocationInWindow: CGPoint?
    let mouseRegionInWindow: CGRect?
    let mouseAnchorRectInScreen: CGRect?
    let mouseRegionInScreen: CGRect?
}

enum ScreenReplyCaptureMode: String, Encodable, Sendable {
    case replyRegion
    case mouseRegion
}

struct ScreenReplyCapturedLine: Encodable, Sendable {
    let speaker: String
    let text: String
    let confidence: Float
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let includedInReplyContext: Bool
}

enum ScreenReplyCaptureError: LocalizedError {
    case screenRecordingPermissionRequired
    case noFrontmostApplication
    case noVisibleWindow
    case captureFailed
    case noRecognizedText
    case noMouseRegionText

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
        case .noMouseRegionText:
            return "没有识别到鼠标附近的文字。"
        }
    }
}

@MainActor
final class ScreenReplyContextCaptureService {
    func capture(
        from application: NSRunningApplication?,
        focusedInputFrame: CGRect? = nil,
        mouseScreenLocation: CGPoint? = nil,
        interactionMode: String? = nil
    ) async throws -> ScreenReplyCapturedContext {
        guard SystemPermissionRequester.hasScreenRecordingPermission else {
            throw ScreenReplyCaptureError.screenRecordingPermissionRequired
        }
        guard let application else {
            throw ScreenReplyCaptureError.noFrontmostApplication
        }
        guard let window = Self.bestVisibleWindow(for: application.processIdentifier) else {
            throw ScreenReplyCaptureError.noVisibleWindow
        }
        let captureStartedAt = Date()
        guard let image = Self.capture(windowID: window.id) else {
            throw ScreenReplyCaptureError.captureFailed
        }
        let captureDurationMs = Date().timeIntervalSince(captureStartedAt) * 1_000

        let mouseLocationInWindow = mouseScreenLocation.flatMap {
            Self.mouseScreenPointInWindow(
                $0,
                windowBounds: window.bounds,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height)
            )
        }
        let mouseCropRegion = mouseLocationInWindow.map {
            Self.mouseOCRCropRegion(
                centeredAt: $0,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height)
            )
        }

        let ocrResult = try await Self.recognizeText(in: image, cropRegion: mouseCropRegion)
        let lines = ocrResult.lines
        guard !lines.isEmpty else {
            throw ScreenReplyCaptureError.noRecognizedText
        }

        let captureID = UUID().uuidString
        let axInputFrameInWindow = focusedInputFrame.flatMap {
            Self.inputFrameInWindow(
                $0,
                windowBounds: window.bounds,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height)
            )
        }
        let ocrInputFrameInWindow = Self.inferredInputFrameInWindow(
            from: lines,
            imageWidth: CGFloat(image.width),
            imageHeight: CGFloat(image.height),
            bundleIdentifier: application.bundleIdentifier
        )
        let inputFrameInWindow = Self.resolvedInputFrameInWindow(
            axInputFrame: axInputFrameInWindow,
            ocrInputFrame: ocrInputFrameInWindow,
            bundleIdentifier: application.bundleIdentifier
        )
        let replyRegion = inputFrameInWindow.map {
            Self.replyRegion(
                for: $0,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height),
                bundleIdentifier: application.bundleIdentifier
            )
        }
        let mouseContext = mouseLocationInWindow.flatMap {
            Self.mouseFocusedContext(
                from: lines,
                mouseLocation: $0,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height),
                bundleIdentifier: application.bundleIdentifier
            )
        }
        if mouseScreenLocation != nil, mouseContext == nil {
            let visibleText = lines.map(\.text).joined(separator: "\n")
            await ScreenReplyDiagnosticsLogger.shared.log(
                ScreenReplyDiagnosticEvent(
                    captureID: UUID().uuidString,
                    event: "mouse_region_missed",
                    interactionMode: interactionMode,
                    appName: application.localizedName,
                    bundleIdentifier: application.bundleIdentifier,
                    windowTitle: window.title,
                    imageWidth: image.width,
                    imageHeight: image.height,
                    windowBounds: window.bounds,
                    mouseScreenLocation: mouseScreenLocation,
                    mouseLocation: mouseLocationInWindow,
                    mouseImageLocation: mouseLocationInWindow,
                    ocrCropRegion: ocrResult.cropRegion,
                    captureDurationMs: captureDurationMs,
                    ocrDurationMs: ocrResult.durationMs,
                    lineCount: lines.count,
                    visibleText: visibleText,
                    lines: Self.capturedLines(
                        from: lines,
                        imageWidth: CGFloat(image.width),
                        imageHeight: CGFloat(image.height),
                        bundleIdentifier: application.bundleIdentifier,
                        replyRegion: nil,
                        mouseIncludedLineIDs: []
                    )
                )
            )
            throw ScreenReplyCaptureError.noMouseRegionText
        }
        let captureMode: ScreenReplyCaptureMode = mouseContext == nil ? .replyRegion : .mouseRegion
        let capturedLines = Self.capturedLines(
            from: lines,
            imageWidth: CGFloat(image.width),
            imageHeight: CGFloat(image.height),
            bundleIdentifier: application.bundleIdentifier,
            replyRegion: replyRegion,
            mouseIncludedLineIDs: mouseContext?.includedLineIDs
        )
        let replyLines = capturedLines.filter(\.includedInReplyContext)
        let visibleText = replyLines.map(\.text).joined(separator: "\n")
        let structuredMessages = Self.structuredMessages(from: replyLines)
        let mouseRegionInScreen = mouseContext.flatMap {
            Self.windowRectInScreen(
                $0.region,
                windowBounds: window.bounds,
                imageWidth: CGFloat(image.width),
                imageHeight: CGFloat(image.height)
            )
        }
        await ScreenReplyDiagnosticsLogger.shared.log(
            ScreenReplyDiagnosticEvent(
                captureID: captureID,
                event: "captured",
                interactionMode: interactionMode,
                captureMode: captureMode,
                appName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                windowTitle: window.title,
                imageWidth: image.width,
                imageHeight: image.height,
                windowBounds: window.bounds,
                inputFrame: inputFrameInWindow,
                replyRegion: replyRegion,
                mouseScreenLocation: mouseScreenLocation,
                mouseLocation: mouseLocationInWindow,
                mouseImageLocation: mouseLocationInWindow,
                ocrCropRegion: ocrResult.cropRegion,
                mouseRegion: mouseContext?.region,
                mouseRegionInScreen: mouseRegionInScreen,
                captureDurationMs: captureDurationMs,
                ocrDurationMs: ocrResult.durationMs,
                lineCount: lines.count,
                visibleText: visibleText,
                structuredMessages: structuredMessages,
                lines: capturedLines
            )
        )
        return ScreenReplyCapturedContext(
            captureMode: captureMode,
            captureID: captureID,
            appName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            windowTitle: window.title,
            visibleText: visibleText,
            structuredMessages: structuredMessages,
            lines: capturedLines,
            lineCount: lines.count,
            inputFrameInWindow: inputFrameInWindow,
            replyRegionInWindow: replyRegion,
            mouseLocationInWindow: mouseLocationInWindow,
            mouseRegionInWindow: mouseContext?.region,
            mouseAnchorRectInScreen: mouseScreenLocation.map { CGRect(origin: $0, size: .zero) },
            mouseRegionInScreen: mouseRegionInScreen
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
        let id: Int
        let text: String
        let rect: CGRect
        let confidence: Float
    }

    private struct MouseFocusedContext: Sendable {
        let region: CGRect
        let includedLineIDs: Set<Int>
    }

    private struct OCRResult: Sendable {
        let lines: [OCRLine]
        let cropRegion: CGRect?
        let durationMs: Double
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

    private static func recognizeText(in image: CGImage, cropRegion: CGRect? = nil) async throws -> OCRResult {
        let startedAt = Date()
        let crop = cropRegion.flatMap { normalizedCropRegion($0, imageWidth: image.width, imageHeight: image.height) }
        let recognitionImage: CGImage
        let offset: CGPoint
        if let crop, let croppedImage = image.cropping(to: crop) {
            recognitionImage = croppedImage
            offset = crop.origin
        } else {
            recognitionImage = image
            offset = .zero
        }

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
                    let rect = CGRect(
                        x: offset.x + box.minX * CGFloat(recognitionImage.width),
                        y: offset.y + (1 - box.maxY) * CGFloat(recognitionImage.height),
                        width: box.width * CGFloat(recognitionImage.width),
                        height: box.height * CGFloat(recognitionImage.height)
                    )
                    return OCRLine(id: index, text: text, rect: rect, confidence: candidate.confidence)
                }
            }
            request.recognitionLevel = crop == nil ? .accurate : .fast
            request.usesLanguageCorrection = crop == nil
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: recognitionImage, options: [:])
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
        return OCRResult(
            lines: lines,
            cropRegion: crop,
            durationMs: Date().timeIntervalSince(startedAt) * 1_000
        )
    }

    private static func capturedLines(
        from lines: [OCRLine],
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        bundleIdentifier: String?,
        replyRegion: CGRect?,
        mouseIncludedLineIDs: Set<Int>? = nil
    ) -> [ScreenReplyCapturedLine] {
        lines.map { line in
            let centerX = line.rect.midX
            let speaker: String
            if line.rect.minX > imageWidth * 0.50 || line.rect.maxX > imageWidth * 0.80 {
                speaker = "我"
            } else if centerX < imageWidth * 0.60 {
                speaker = "对方"
            } else {
                speaker = "未知"
            }
            let includedInReplyContext = mouseIncludedLineIDs.map { $0.contains(line.id) }
                ?? Self.shouldIncludeInReplyContext(
                    line: line,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    bundleIdentifier: bundleIdentifier,
                    replyRegion: replyRegion
                )
            return ScreenReplyCapturedLine(
                speaker: speaker,
                text: line.text,
                confidence: line.confidence,
                x: line.rect.minX,
                y: line.rect.minY,
                width: line.rect.width,
                height: line.rect.height,
                includedInReplyContext: includedInReplyContext
            )
        }
    }

    private static func structuredMessages(from lines: [ScreenReplyCapturedLine]) -> String {
        let rows = lines.map { line -> String in
            "\(line.speaker)：\(line.text)"
        }
        return rows.joined(separator: "\n")
    }

    private static func shouldIncludeInReplyContext(
        line: OCRLine,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        bundleIdentifier: String?,
        replyRegion: CGRect?
    ) -> Bool {
        if let replyRegion {
            let horizontalTolerance: CGFloat = usesReplyColumn(bundleIdentifier) ? 4 : 0
            let startsInsideReplyColumn = line.rect.minX >= replyRegion.minX - horizontalTolerance
                && line.rect.minX <= replyRegion.maxX
            return startsInsideReplyColumn
                && replyRegion.intersects(line.rect)
                && line.rect.midY < replyRegion.maxY
                && !isLikelyReplyContextNoise(
                    line: line,
                    imageHeight: imageHeight,
                    bundleIdentifier: bundleIdentifier
                )
        }
        guard isChatApp(bundleIdentifier) else { return true }
        guard line.rect.minX >= imageWidth * 0.30 else { return false }
        guard line.rect.minY >= imageHeight * 0.14 else { return false }
        guard !isLikelyReplyContextNoise(
            line: line,
            imageHeight: imageHeight,
            bundleIdentifier: bundleIdentifier
        ) else { return false }
        return true
    }

    private static func isChatApp(_ bundleIdentifier: String?) -> Bool {
        switch bundleIdentifier {
        case "com.tencent.WeWorkMac", "com.tencent.xinWeChat":
            return true
        default:
            return false
        }
    }

    private static func isLarkApp(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.electron.lark"
    }

    private static func isBrowserApp(_ bundleIdentifier: String?) -> Bool {
        switch bundleIdentifier {
        case "com.google.Chrome", "com.microsoft.edgemac", "com.apple.Safari":
            return true
        default:
            return false
        }
    }

    private static func usesReplyColumn(_ bundleIdentifier: String?) -> Bool {
        isChatApp(bundleIdentifier) || isLarkApp(bundleIdentifier) || isBrowserApp(bundleIdentifier)
    }

    private static func isLikelyReplyContextNoise(
        line: OCRLine,
        imageHeight: CGFloat,
        bundleIdentifier: String?
    ) -> Bool {
        if isLikelyChatChromeText(line.text) { return true }

        let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        if isLarkApp(bundleIdentifier) {
            // 飞书右侧话题栏顶部有固定工具按钮，OCR 会把它们当成正文。
            if line.rect.minY < imageHeight * 0.16,
               ["E", "••", "••。", "ot", "呵。", "包云文档", "已云文档", "包云文档＋", "文件", "文件＋", "话题", "竺因", "全因", "因", "×"].contains(compact) {
                return true
            }

            // 话题列表中头像/姓名有时会被 Vision 识别成大号文字块，重复进入上下文会误导模型。
            if line.rect.height > 52,
               line.rect.width < 240,
               compact.range(of: #"^[\p{L}\p{N}_-]{2,24}\d{3,4}$"#, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    private static func isLikelyChatChromeText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        let chromeTexts: Set<String> = [
            "搜索", "消息", "邮件", "文档", "日程", "待办", "会议", "智能文档",
            "智能总结", "工作台", "通讯录", "微盘", "更多", "昨天", "今天",
            "Q 搜索", "草稿", "回复话题", "新建话题", "快捷指令", "快捷指令v",
            "最佳实践", "什么新鲜事", "正在关注", "帖子", "显示更多", "订阅",
            "文件", "话题", "暂无回复", "Aa", "Design Engineers", "Al Leaders",
            "AI Leaders"
        ]
        let compactChromeTexts: Set<String> = [
            "Q搜索", "包云文档", "包云文档＋", "文件＋", "新建话题", "回复话题"
        ]
        if chromeTexts.contains(trimmed) || compactChromeTexts.contains(compact) { return true }
        if trimmed.contains("推广你的回复") { return true }
        if trimmed.range(of: #"^(AI|Al)\s+Founders\s+#?\s*1\s*of\s*3$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^[×xX]$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^\d+\s*分钟前$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^昨天下午\s*\d+:\d+$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^https?://"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func isLikelyInputPlaceholder(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("输入文字")
            || trimmed.contains("按住Fn")
            || trimmed.contains("使用语音输入")
            || trimmed.contains("输入消息")
            || trimmed.contains("发送消息")
    }

    private static func isLikelyLarkInputAnchor(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("发送给 ")
            || trimmed.contains("发送给")
            || trimmed == "Aa"
            || trimmed.contains("新建话题")
            || trimmed.contains("回复话题")
    }

    private static func inferredInputFrameInWindow(
        from lines: [OCRLine],
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        bundleIdentifier: String?
    ) -> CGRect? {
        if isLarkApp(bundleIdentifier) {
            return inferredLarkInputFrameInWindow(
                from: lines,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        }
        guard isChatApp(bundleIdentifier) else { return nil }
        guard let placeholderLine = lines
            .filter({ isLikelyInputPlaceholder($0.text) && $0.rect.minY > imageHeight * 0.55 })
            .max(by: { $0.rect.minY < $1.rect.minY }) else {
            return nil
        }

        let placeholder = placeholderLine.rect
        let minX = max(0, placeholder.minX - min(max(imageWidth * 0.015, 18), 32))
        let maxX = min(imageWidth, placeholder.maxX + imageWidth * 0.25)
        let inputHeight = max(placeholder.height, imageHeight - placeholder.minY)
        let rect = CGRect(
            x: minX,
            y: placeholder.minY,
            width: max(0, maxX - minX),
            height: inputHeight
        )
        guard rect.width > imageWidth * 0.25, rect.height > 10 else { return nil }
        return rect
    }

    private static func inferredLarkInputFrameInWindow(
        from lines: [OCRLine],
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect? {
        let bottomAnchors = lines.filter {
            isLikelyLarkInputAnchor($0.text)
                && $0.rect.minY > imageHeight * 0.70
                && $0.rect.minX > imageWidth * 0.25
        }
        guard !bottomAnchors.isEmpty else {
            return nil
        }

        let newTopicAnchors = bottomAnchors.filter {
            $0.text.contains("新建话题")
        }
        let rightReplyAnchors = bottomAnchors.filter {
            ($0.text.contains("回复话题") || $0.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Aa"))
                && $0.rect.minX > imageWidth * 0.55
        }
        let sendAnchors = bottomAnchors.filter {
            $0.text.contains("发送给")
        }

        let leftAnchor: OCRLine
        let minimumWidthRatio: CGFloat
        if !newTopicAnchors.isEmpty,
           let rightTopicAnchor = rightReplyAnchors.min(by: { $0.rect.minX < $1.rect.minX }) {
            leftAnchor = rightTopicAnchor
            minimumWidthRatio = 0.18
        } else if let sendAnchor = sendAnchors.min(by: { $0.rect.minX < $1.rect.minX }) {
            leftAnchor = sendAnchor
            minimumWidthRatio = 0.35
        } else {
            leftAnchor = bottomAnchors.min(by: { $0.rect.minX < $1.rect.minX })!
            minimumWidthRatio = 0.35
        }

        let leftPadding = min(max(imageWidth * 0.015, 18), 36)
        let minX = max(0, leftAnchor.rect.minX - leftPadding)
        let maxX = imageWidth
        let relatedAnchors = bottomAnchors.filter { $0.rect.minX >= minX }
        let minY = relatedAnchors.map(\.rect.minY).max() ?? leftAnchor.rect.minY
        let inputHeight = max(leftAnchor.rect.height, imageHeight - minY)
        let rect = CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: inputHeight
        )
        guard rect.width > imageWidth * minimumWidthRatio, rect.height > 10 else { return nil }
        return rect
    }

    private static func resolvedInputFrameInWindow(
        axInputFrame: CGRect?,
        ocrInputFrame: CGRect?,
        bundleIdentifier: String?
    ) -> CGRect? {
        guard (bundleIdentifier == "com.tencent.xinWeChat" || isLarkApp(bundleIdentifier)),
              let ocrInputFrame else {
            return axInputFrame ?? ocrInputFrame
        }
        guard let axInputFrame else { return ocrInputFrame }

        let minX = max(axInputFrame.minX, ocrInputFrame.minX)
        let maxX = max(minX, axInputFrame.maxX)
        return CGRect(
            x: minX,
            y: min(axInputFrame.minY, ocrInputFrame.minY),
            width: max(0, maxX - minX),
            height: max(axInputFrame.height, ocrInputFrame.height)
        )
    }

    private static func inputFrameInWindow(
        _ inputFrame: CGRect,
        windowBounds: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect? {
        let scaleX = windowBounds.width > 0 ? imageWidth / windowBounds.width : 1
        let scaleY = windowBounds.height > 0 ? imageHeight / windowBounds.height : 1
        // AX returns screen points, while Vision OCR lines are measured in screenshot pixels.
        // Convert once here so replyRegion and OCR coordinates live in the same space.
        let rect = CGRect(
            x: (inputFrame.minX - windowBounds.minX) * scaleX,
            y: (inputFrame.minY - windowBounds.minY) * scaleY,
            width: inputFrame.width * scaleX,
            height: inputFrame.height * scaleY
        )
        guard rect.width > 20, rect.height > 10 else { return nil }
        return rect
    }

    private static func mouseScreenPointInWindow(
        _ point: CGPoint,
        windowBounds: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGPoint? {
        guard windowBounds.width > 0, windowBounds.height > 0 else { return nil }
        let convertedPoint = quartzPoint(fromAppKitScreenPoint: point) ?? point
        guard windowBounds.insetBy(dx: -2, dy: -2).contains(convertedPoint) else { return nil }
        let scaleX = imageWidth / windowBounds.width
        let scaleY = imageHeight / windowBounds.height
        let converted = CGPoint(
            x: (convertedPoint.x - windowBounds.minX) * scaleX,
            y: (convertedPoint.y - windowBounds.minY) * scaleY
        )
        guard converted.x >= 0,
              converted.y >= 0,
              converted.x <= imageWidth,
              converted.y <= imageHeight else {
            return nil
        }
        return converted
    }

    private static func mouseOCRCropRegion(
        centeredAt point: CGPoint,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        let width = min(imageWidth, max(760, min(1_420, imageWidth * 0.52)))
        let height = min(imageHeight, max(520, min(820, imageHeight * 0.42)))
        let x = min(max(0, point.x - width / 2), max(0, imageWidth - width))
        let y = min(max(0, point.y - height / 2), max(0, imageHeight - height))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func normalizedCropRegion(_ rect: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect? {
        let imageRect = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        let clamped = rect.intersection(imageRect)
        guard !clamped.isNull, clamped.width > 8, clamped.height > 8 else { return nil }
        let integral = clamped.integral.intersection(imageRect)
        guard !integral.isNull, integral.width > 8, integral.height > 8 else { return nil }
        return integral
    }

    private static func windowRectInScreen(
        _ rect: CGRect,
        windowBounds: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect? {
        guard imageWidth > 0, imageHeight > 0 else { return nil }
        let scaleX = windowBounds.width / imageWidth
        let scaleY = windowBounds.height / imageHeight
        let converted = CGRect(
            x: windowBounds.minX + rect.minX * scaleX,
            y: windowBounds.minY + rect.minY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        guard converted.width > 0, converted.height > 0 else { return nil }
        return appKitRect(fromQuartzScreenRect: converted)
    }

    private static func quartzPoint(fromAppKitScreenPoint point: CGPoint) -> CGPoint? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(point) })
            ?? NSScreen.main else {
            return nil
        }
        return CGPoint(
            x: point.x,
            y: screen.frame.minY + (screen.frame.maxY - point.y)
        )
    }

    private static func appKitRect(fromQuartzScreenRect rect: CGRect) -> CGRect {
        guard let screen = NSScreen.screens.first(where: { screen in
            let quartzFrame = CGRect(
                x: screen.frame.minX,
                y: screen.frame.minY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return quartzFrame.intersects(rect) || quartzFrame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }) ?? NSScreen.main else {
            return rect
        }
        return CGRect(
            x: rect.minX,
            y: screen.frame.minY + (screen.frame.maxY - rect.maxY),
            width: rect.width,
            height: rect.height
        )
    }

    private static func mouseFocusedContext(
        from lines: [OCRLine],
        mouseLocation: CGPoint,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        bundleIdentifier: String?
    ) -> MouseFocusedContext? {
        let candidates = lines.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !isLikelyReplyContextNoise(
                    line: $0,
                    imageHeight: imageHeight,
                    bundleIdentifier: bundleIdentifier
                )
        }
        guard let anchor = candidates.min(by: { lhs, rhs in
            distance(from: mouseLocation, to: lhs.rect.insetBy(dx: -10, dy: -8))
                < distance(from: mouseLocation, to: rhs.rect.insetBy(dx: -10, dy: -8))
        }) else {
            return nil
        }
        guard distance(from: mouseLocation, to: anchor.rect.insetBy(dx: -16, dy: -12)) <= max(80, min(imageWidth, imageHeight) * 0.08) else {
            return nil
        }

        var includedIDs: Set<Int> = [anchor.id]
        var region = anchor.rect
        var didChange = true
        while didChange, includedIDs.count < 8 {
            didChange = false
            let nextLine = candidates
                .filter { !includedIDs.contains($0.id) }
                .compactMap { line -> (line: OCRLine, score: CGFloat)? in
                    guard shouldIncludeMouseParagraphLine(
                        line,
                        anchor: anchor,
                        currentRegion: region,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight
                    ) else {
                        return nil
                    }
                    let score = verticalGap(between: region, and: line.rect)
                        + abs(line.rect.midY - anchor.rect.midY) * 0.04
                    return (line, score)
                }
                .min { $0.score < $1.score }?
                .line

            if let nextLine {
                includedIDs.insert(nextLine.id)
                region = region.union(nextLine.rect)
                didChange = true
            }
        }

        let paddedRegion = region.insetBy(dx: -8, dy: -6)
        let clampedRegion = paddedRegion.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard !clampedRegion.isNull, !includedIDs.isEmpty else { return nil }
        return MouseFocusedContext(region: clampedRegion, includedLineIDs: includedIDs)
    }

    private static func shouldIncludeMouseParagraphLine(
        _ line: OCRLine,
        anchor: OCRLine,
        currentRegion: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> Bool {
        let anchorLineHeight = max(1, anchor.rect.height)
        let gap = verticalGap(between: currentRegion, and: line.rect)
        guard gap <= max(8, min(24, anchorLineHeight * 1.2)) else {
            return false
        }

        let expanded = currentRegion.union(line.rect)
        guard expanded.width <= min(imageWidth * 0.82, max(anchor.rect.width * 1.35, 520)),
              expanded.height <= min(imageHeight * 0.28, max(anchorLineHeight * 8, 180)) else {
            return false
        }

        let overlapWidth = max(0, min(currentRegion.maxX, line.rect.maxX) - max(currentRegion.minX, line.rect.minX))
        let overlapRatio = overlapWidth / max(1, min(currentRegion.width, line.rect.width))
        let leftEdgeDistance = abs(line.rect.minX - anchor.rect.minX)
        let centerDistance = abs(line.rect.midX - anchor.rect.midX)
        let rightEdgeDistance = abs(line.rect.maxX - anchor.rect.maxX)

        return overlapRatio >= 0.32
            || leftEdgeDistance <= max(36, anchorLineHeight * 2.2)
            || rightEdgeDistance <= max(52, anchorLineHeight * 2.8)
            || centerDistance <= max(120, anchor.rect.width * 0.35)
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
        return hypot(dx, dy)
    }

    private static func replyRegion(
        for inputFrame: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        bundleIdentifier: String?
    ) -> CGRect {
        let isChatApp = isChatApp(bundleIdentifier)
        if usesReplyColumn(bundleIdentifier) {
            let leftMargin: CGFloat = isBrowserApp(bundleIdentifier)
                ? min(max(inputFrame.width * 0.03, 24), 48)
                : 0
            let minX = max(0, inputFrame.minX)
            let adjustedMinX = max(0, minX - leftMargin)
            let maxX = min(imageWidth, inputFrame.maxX)
            let bottomGap: CGFloat = 8
            let maxY = max(0, min(imageHeight, inputFrame.minY - bottomGap))
            return CGRect(
                x: adjustedMinX,
                y: 0,
                width: max(0, maxX - adjustedMinX),
                height: maxY
            )
        }

        let leftMargin: CGFloat = isChatApp ? min(max(inputFrame.width * 0.04, 20), 48) : min(max(inputFrame.width * 0.12, 80), 160)
        let rightMargin: CGFloat = min(max(inputFrame.width * 0.18, 120), 240)
        let minimumWidth: CGFloat = min(620, imageWidth)
        let centerX = inputFrame.midX
        let leftSafetyX = isChatApp ? imageWidth * 0.34 : 0
        var minX = max(inputFrame.minX - leftMargin, leftSafetyX)
        var maxX = inputFrame.maxX + rightMargin

        if maxX - minX < minimumWidth {
            minX = isChatApp
                ? max(inputFrame.minX - leftMargin, leftSafetyX)
                : centerX - minimumWidth / 2
            maxX = centerX + minimumWidth / 2
            if isChatApp, maxX - minX < minimumWidth {
                maxX = minX + minimumWidth
            }
        }

        minX = max(0, minX)
        maxX = min(imageWidth, maxX)
        let bottomGap: CGFloat = 8
        let maxY = max(0, min(imageHeight, inputFrame.minY - bottomGap))

        return CGRect(
            x: minX,
            y: 0,
            width: max(0, maxX - minX),
            height: maxY
        )
    }
}
