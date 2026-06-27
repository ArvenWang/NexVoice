import AppKit
import ApplicationServices
import CoreGraphics
import NexVoiceCore

struct SelectedTextContext {
    let text: String
    let anchorRect: CGRect
}

struct SelectedTextQuestionDetection {
    let context: SelectedTextContext?
    let source: String
    let shouldFallbackToMouseContext: Bool
    let focusedChainCount: Int
    let searchRootCount: Int
    let scannedNodeCount: Int
    let didUseRecursiveScan: Bool
    let didSeeAXSelectionSignal: Bool
    let clipboardDurationMs: Double?
    let clipboardDidChange: Bool?
    let clipboardTextCharacters: Int?
    let clipboardRestoreSucceeded: Bool?
}

enum FocusedTextAccessMethod: String {
    case axValue
    case axStringForRange
    case axSetValue
    case keyboardInsert
}

struct FocusedDraftSnapshot {
    let text: String
    let method: FocusedTextAccessMethod
    let requiresTrustValidation: Bool
}

enum FocusedTextInsertionError: LocalizedError {
    case emptyText
    case accessibilityPermissionRequired
    case pasteboardWriteFailed
    case focusedDraftReplacementUnsupported

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "没有可输入的文本。"
        case .accessibilityPermissionRequired:
            return "需要辅助功能权限，才能把文字输入到当前文本框。"
        case .pasteboardWriteFailed:
            return "写入系统剪贴板失败。"
        case .focusedDraftReplacementUnsupported:
            return "当前输入框不支持安全替换已有草稿。"
        }
    }
}

@MainActor
final class FocusedTextInserter {
    private let pasteboard: NSPasteboard
    private var restoreWorkItem: DispatchWorkItem?
    private(set) var latestDraftReadMethod: FocusedTextAccessMethod?
    private(set) var latestInsertionMethod: FocusedTextAccessMethod?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var canPostKeyboardEvents: Bool {
        SystemPermissionRequester.hasAccessibilityPermission
    }

    func insert(_ text: String, into targetApplication: NSRunningApplication?) throws {
        let insertionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !insertionText.isEmpty else { throw FocusedTextInsertionError.emptyText }
        guard canPostKeyboardEvents else {
            Self.requestAccessibilityPermission()
            throw FocusedTextInsertionError.accessibilityPermissionRequired
        }

        restoreWorkItem?.cancel()
        latestInsertionMethod = .keyboardInsert
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(insertionText, forType: .string) else {
            throw FocusedTextInsertionError.pasteboardWriteFailed
        }

        let insertionChangeCount = pasteboard.changeCount
        targetApplication?.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.postCommandV()
        }

        let restoreWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.pasteboard.changeCount == insertionChangeCount else { return }
            snapshot.restore(to: self.pasteboard)
        }
        self.restoreWorkItem = restoreWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: restoreWorkItem)
    }

    func replaceFocusedDraft(_ text: String, into targetApplication: NSRunningApplication?) throws {
        let insertionText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !insertionText.isEmpty else { throw FocusedTextInsertionError.emptyText }
        guard canPostKeyboardEvents else {
            Self.requestAccessibilityPermission()
            throw FocusedTextInsertionError.accessibilityPermissionRequired
        }
        targetApplication?.activate(options: [.activateIgnoringOtherApps])
        if Self.replaceFocusedDraftUsingAXValue(insertionText, in: targetApplication) {
            latestInsertionMethod = .axSetValue
            return
        }
        latestInsertionMethod = nil
        throw FocusedTextInsertionError.focusedDraftReplacementUnsupported
    }

    func selectedText(in targetApplication: NSRunningApplication?) async -> String? {
        let context = await selectedTextContext(in: targetApplication)
        return context?.text
    }

    func selectedTextContext(in targetApplication: NSRunningApplication?) async -> SelectedTextContext? {
        guard !Self.hasFocusedEditableElement(in: targetApplication) else { return nil }
        guard !Self.hasEditableSelectedText(in: targetApplication) else { return nil }

        return Self.nonEditableSelectedTextContext(in: targetApplication)
    }

    func selectedTextQuestionDetection(in targetApplication: NSRunningApplication?) async -> SelectedTextQuestionDetection {
        let accessibilityDetection = Self.selectedTextQuestionDetection(in: targetApplication)
        if accessibilityDetection.context != nil {
            return accessibilityDetection
        }
        return await selectedTextQuestionDetectionUsingClipboardFallback(
            in: targetApplication,
            accessibilityDetection: accessibilityDetection
        )
    }

    func rewriteContext(
        in targetApplication: NSRunningApplication?,
        selectedTextMode: Bool,
        personalDictionary: VoicePersonalDictionary
    ) -> VoiceRewriteContext {
        let focusedElement = Self.focusedElement(in: targetApplication) ?? Self.systemFocusedElement()
        let elementChain = focusedElement.map { Self.elementAndParents(from: $0, maxDepth: 4) } ?? []

        return VoiceRewriteContext(
            sourceApplicationName: targetApplication?.localizedName,
            sourceApplicationBundleIdentifier: targetApplication?.bundleIdentifier,
            focusedElementRole: elementChain.compactMap { Self.stringAttribute(kAXRoleAttribute as String, on: $0) }.first,
            focusedElementDescription: elementChain.compactMap { element in
                Self.stringAttribute(kAXDescriptionAttribute as String, on: element)
                    ?? Self.stringAttribute(kAXTitleAttribute as String, on: element)
            }.first,
            focusedTextPreview: Self.focusedTextSnapshot(
                from: elementChain,
                targetApplication: targetApplication
            )?.text,
            selectedTextMode: selectedTextMode,
            personalDictionary: personalDictionary
        )
    }

    func focusedTextPreview(in targetApplication: NSRunningApplication?) -> String? {
        let focusedElement = Self.focusedElement(in: targetApplication) ?? Self.systemFocusedElement()
        let elementChain = focusedElement.map { Self.elementAndParents(from: $0, maxDepth: 4) } ?? []
        if let snapshot = Self.focusedTextSnapshot(from: elementChain, targetApplication: targetApplication) {
            return snapshot.text
        }
        if let bottomElement = Self.bottomEditableInputElement(in: targetApplication),
           let snapshot = Self.focusedTextSnapshot(from: [bottomElement], targetApplication: targetApplication) {
            return snapshot.text
        }
        return nil
    }

    func focusedDraftSnapshot(in targetApplication: NSRunningApplication?) async -> String? {
        await focusedDraftSnapshotResult(in: targetApplication)?.text
    }

    func focusedDraftSnapshotResult(in targetApplication: NSRunningApplication?) async -> FocusedDraftSnapshot? {
        latestDraftReadMethod = nil
        let focusedElement = Self.focusedElement(in: targetApplication) ?? Self.systemFocusedElement()
        let elementChain = focusedElement.map { Self.elementAndParents(from: $0, maxDepth: 4) } ?? []
        if let snapshot = Self.focusedTextSnapshot(
            from: elementChain,
            targetApplication: targetApplication
        ) {
            latestDraftReadMethod = snapshot.method
            return snapshot
        }
        if let bottomElement = Self.bottomEditableInputElement(in: targetApplication),
           let snapshot = Self.focusedTextSnapshot(from: [bottomElement], targetApplication: targetApplication) {
            latestDraftReadMethod = snapshot.method
            return snapshot
        }
        return nil
    }

    func hasEditableSelection(in targetApplication: NSRunningApplication?) -> Bool {
        Self.hasEditableSelectedText(in: targetApplication)
    }

    func focusedInputFrame(in targetApplication: NSRunningApplication?) -> CGRect? {
        let focusedElement = Self.focusedElement(in: targetApplication) ?? Self.systemFocusedElement()
        let elementChain = focusedElement.map { Self.elementAndParents(from: $0, maxDepth: 4) } ?? []
        for element in elementChain where Self.isEditableTextElement(element) {
            if let frame = Self.frameAttribute(on: element) {
                return frame
            }
        }
        return Self.bottomEditableInputFrame(in: targetApplication)
    }

    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let trusted = SystemPermissionRequester.requestAccessibilityPermission(prompt: true)
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SystemPermissionRequester.openAccessibilitySettings()
            }
        }
        return trusted
    }

    private static func postCommandV() {
        postCommandKey(9)
    }

    private static func postCommandC() {
        postCommandKey(8)
    }

    private func selectedTextQuestionDetectionUsingClipboardFallback(
        in targetApplication: NSRunningApplication?,
        accessibilityDetection: SelectedTextQuestionDetection
    ) async -> SelectedTextQuestionDetection {
        guard canPostKeyboardEvents else { return accessibilityDetection }

        let startedAt = Date()
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let marker = "__NEXVOICE_SELECTED_TEXT_PROBE__\(UUID().uuidString)__"
        pasteboard.clearContents()
        guard pasteboard.setString(marker, forType: .string) else {
            return accessibilityDetection
        }
        let markerChangeCount = pasteboard.changeCount

        targetApplication?.activate(options: [.activateIgnoringOtherApps])
        Self.postCommandC()
        try? await Task.sleep(nanoseconds: 160_000_000)

        let copiedText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let didChange = pasteboard.changeCount != markerChangeCount
        let restoreSucceeded = snapshot.restore(to: pasteboard)
        let durationMs = Date().timeIntervalSince(startedAt) * 1_000

        if didChange,
           let copiedText,
           !copiedText.isEmpty,
           copiedText != marker {
            return SelectedTextQuestionDetection(
                context: SelectedTextContext(
                    text: copiedText,
                    anchorRect: CGRect(origin: NSEvent.mouseLocation, size: .zero)
                ),
                source: "clipboard_copy",
                shouldFallbackToMouseContext: false,
                focusedChainCount: accessibilityDetection.focusedChainCount,
                searchRootCount: accessibilityDetection.searchRootCount,
                scannedNodeCount: accessibilityDetection.scannedNodeCount,
                didUseRecursiveScan: accessibilityDetection.didUseRecursiveScan,
                didSeeAXSelectionSignal: accessibilityDetection.didSeeAXSelectionSignal,
                clipboardDurationMs: durationMs,
                clipboardDidChange: didChange,
                clipboardTextCharacters: copiedText.count,
                clipboardRestoreSucceeded: restoreSucceeded
            )
        }

        let likelyTextSelectionReadFailure = accessibilityDetection.didSeeAXSelectionSignal && didChange
        return SelectedTextQuestionDetection(
            context: nil,
            source: likelyTextSelectionReadFailure ? "selection_read_failed" : accessibilityDetection.source,
            shouldFallbackToMouseContext: !likelyTextSelectionReadFailure,
            focusedChainCount: accessibilityDetection.focusedChainCount,
            searchRootCount: accessibilityDetection.searchRootCount,
            scannedNodeCount: accessibilityDetection.scannedNodeCount,
            didUseRecursiveScan: accessibilityDetection.didUseRecursiveScan,
            didSeeAXSelectionSignal: accessibilityDetection.didSeeAXSelectionSignal,
            clipboardDurationMs: durationMs,
            clipboardDidChange: didChange,
            clipboardTextCharacters: copiedText?.count,
            clipboardRestoreSucceeded: restoreSucceeded
        )
    }

    private static func hasEditableSelectedText(in targetApplication: NSRunningApplication?) -> Bool {
        guard let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement() else {
            return false
        }

        return elementAndParents(from: focusedElement, maxDepth: 4).contains { element in
            selectedTextLength(on: element) > 0 && isEditableTextElement(element)
        }
    }

    private static func hasFocusedEditableElement(in targetApplication: NSRunningApplication?) -> Bool {
        guard let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement() else {
            return false
        }

        return elementAndParents(from: focusedElement, maxDepth: 4).contains(where: isEditableTextElement)
    }

    private static func nonEditableSelectedTextContext(
        in targetApplication: NSRunningApplication?
    ) -> SelectedTextContext? {
        let roots = selectionSearchRoots(in: targetApplication)
        var visited = 0
        var didTimeOut = false
        var didSeeSelectionSignal = false
        for root in roots {
            if let context = nonEditableSelectedTextContext(
                from: root,
                visited: &visited,
                maxNodes: 700,
                didTimeOut: &didTimeOut,
                didSeeSelectionSignal: &didSeeSelectionSignal
            ) {
                return context
            }
        }
        return nil
    }

    private static func selectedTextQuestionDetection(
        in targetApplication: NSRunningApplication?
    ) -> SelectedTextQuestionDetection {
        let startedAt = Date()
        let recursiveScanTimeoutSeconds: TimeInterval = 0.25
        var focusedChainCount = 0
        var didSeeAXSelectionSignal = false
        if let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement() {
            let chain = elementAndParents(from: focusedElement, maxDepth: 4)
            focusedChainCount = chain.count
            for element in chain {
                if selectedTextLength(on: element) > 0 {
                    didSeeAXSelectionSignal = true
                }
                if let context = selectedTextContext(from: element) {
                    return SelectedTextQuestionDetection(
                        context: context,
                        source: "focused_chain",
                        shouldFallbackToMouseContext: false,
                        focusedChainCount: focusedChainCount,
                        searchRootCount: 0,
                        scannedNodeCount: 0,
                        didUseRecursiveScan: false,
                        didSeeAXSelectionSignal: true,
                        clipboardDurationMs: nil,
                        clipboardDidChange: nil,
                        clipboardTextCharacters: nil,
                        clipboardRestoreSucceeded: nil
                    )
                }
            }
        }

        let roots = selectionSearchRoots(in: targetApplication)
        var visited = 0
        var didTimeOut = false
        for root in roots {
            if let context = nonEditableSelectedTextContext(
                from: root,
                visited: &visited,
                maxNodes: 700,
                startedAt: startedAt,
                timeoutSeconds: recursiveScanTimeoutSeconds,
                didTimeOut: &didTimeOut,
                didSeeSelectionSignal: &didSeeAXSelectionSignal
            ) {
                return SelectedTextQuestionDetection(
                    context: context,
                    source: "non_editable_scan",
                    shouldFallbackToMouseContext: false,
                    focusedChainCount: focusedChainCount,
                    searchRootCount: roots.count,
                    scannedNodeCount: visited,
                    didUseRecursiveScan: true,
                    didSeeAXSelectionSignal: true,
                    clipboardDurationMs: nil,
                    clipboardDidChange: nil,
                    clipboardTextCharacters: nil,
                    clipboardRestoreSucceeded: nil
                )
            }
            if didTimeOut {
                return SelectedTextQuestionDetection(
                    context: nil,
                    source: "timed_out",
                    shouldFallbackToMouseContext: true,
                    focusedChainCount: focusedChainCount,
                    searchRootCount: roots.count,
                    scannedNodeCount: visited,
                    didUseRecursiveScan: true,
                    didSeeAXSelectionSignal: didSeeAXSelectionSignal,
                    clipboardDurationMs: nil,
                    clipboardDidChange: nil,
                    clipboardTextCharacters: nil,
                    clipboardRestoreSucceeded: nil
                )
            }
        }

        return SelectedTextQuestionDetection(
            context: nil,
            source: "not_found",
            shouldFallbackToMouseContext: true,
            focusedChainCount: focusedChainCount,
            searchRootCount: roots.count,
            scannedNodeCount: visited,
            didUseRecursiveScan: true,
            didSeeAXSelectionSignal: didSeeAXSelectionSignal,
            clipboardDurationMs: nil,
            clipboardDidChange: nil,
            clipboardTextCharacters: nil,
            clipboardRestoreSucceeded: nil
        )
    }

    private static func selectedTextContext(from element: AXUIElement) -> SelectedTextContext? {
        guard let selectedText = selectedText(on: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedText.isEmpty else {
            return nil
        }

        return SelectedTextContext(
            text: selectedText,
            anchorRect: frameAttribute(on: element) ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        )
    }

    private static func nonEditableSelectedTextContext(
        from element: AXUIElement,
        visited: inout Int,
        maxNodes: Int,
        startedAt: Date? = nil,
        timeoutSeconds: TimeInterval? = nil,
        didTimeOut: inout Bool,
        didSeeSelectionSignal: inout Bool
    ) -> SelectedTextContext? {
        guard visited < maxNodes else { return nil }
        if let startedAt,
           let timeoutSeconds,
           Date().timeIntervalSince(startedAt) >= timeoutSeconds {
            didTimeOut = true
            return nil
        }
        visited += 1

        if selectedTextLength(on: element) > 0 {
            didSeeSelectionSignal = true
        }

        if !isEditableTextElement(element),
           !isDraftWritableElement(element),
           let selectedText = selectedText(on: element),
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let anchorRect = frameAttribute(on: element)
                ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
            return SelectedTextContext(
                text: selectedText.trimmingCharacters(in: .whitespacesAndNewlines),
                anchorRect: anchorRect
            )
        }

        for child in elementArrayAttribute(kAXChildrenAttribute as String, on: element) {
            if let context = nonEditableSelectedTextContext(
                from: child,
                visited: &visited,
                maxNodes: maxNodes,
                startedAt: startedAt,
                timeoutSeconds: timeoutSeconds,
                didTimeOut: &didTimeOut,
                didSeeSelectionSignal: &didSeeSelectionSignal
            ) {
                return context
            }
            if didTimeOut { return nil }
        }
        return nil
    }

    private static func selectionSearchRoots(in targetApplication: NSRunningApplication?) -> [AXUIElement] {
        var roots: [AXUIElement] = []
        if let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement() {
            roots.append(contentsOf: elementAndParents(from: focusedElement, maxDepth: 4))
        }
        guard let processIdentifier = targetApplication?.processIdentifier else { return roots }
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        if let focusedWindow = elementAttribute(kAXFocusedWindowAttribute as String, on: applicationElement) {
            roots.append(focusedWindow)
        }
        roots.append(contentsOf: elementArrayAttribute(kAXWindowsAttribute as String, on: applicationElement))
        return roots
    }

    private static func focusedElement(in targetApplication: NSRunningApplication?) -> AXUIElement? {
        guard let processIdentifier = targetApplication?.processIdentifier else { return nil }
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var focusedObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success, let focusedObject else {
            return nil
        }
        return (focusedObject as! AXUIElement)
    }

    private static func focusedEditableElement(in targetApplication: NSRunningApplication?) -> AXUIElement? {
        let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement()
        let elementChain = focusedElement.map { elementAndParents(from: $0, maxDepth: 4) } ?? []
        return elementChain.first(where: isDraftWritableElement)
            ?? bottomEditableInputElement(in: targetApplication)
    }

    private static func replaceFocusedDraftUsingAXValue(
        _ text: String,
        in targetApplication: NSRunningApplication?
    ) -> Bool {
        guard let element = focusedEditableElement(in: targetApplication),
              isAttributeSettable(kAXValueAttribute as String, on: element) else {
            return false
        }

        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        ) == .success else {
            return false
        }

        repairInsertionPointToEndOnce(of: element, text: text)
        return true
    }

    private static func bottomEditableInputFrame(in targetApplication: NSRunningApplication?) -> CGRect? {
        bottomEditableInputCandidate(in: targetApplication)?.frame
    }

    private static func bottomEditableInputElement(in targetApplication: NSRunningApplication?) -> AXUIElement? {
        bottomEditableInputCandidate(in: targetApplication)?.element
    }

    private static func bottomEditableInputCandidate(in targetApplication: NSRunningApplication?) -> EditableInputCandidate? {
        guard let processIdentifier = targetApplication?.processIdentifier else { return nil }
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var roots: [AXUIElement] = []
        if let focusedWindow = elementAttribute(kAXFocusedWindowAttribute as String, on: applicationElement) {
            roots.append(focusedWindow)
        }
        roots.append(contentsOf: elementArrayAttribute(kAXWindowsAttribute as String, on: applicationElement))

        var candidates: [EditableInputCandidate] = []
        var visited = 0
        for root in roots {
            let windowFrame = frameAttribute(on: root)
            collectEditableInputCandidates(
                from: root,
                windowFrame: windowFrame,
                candidates: &candidates,
                visited: &visited,
                maxNodes: 500
            )
        }

        return candidates.max { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 8 {
                return lhs.frame.minY < rhs.frame.minY
            }
            return lhs.frame.width < rhs.frame.width
        }
    }

    private static func collectEditableInputCandidates(
        from element: AXUIElement,
        windowFrame: CGRect?,
        candidates: inout [EditableInputCandidate],
        visited: inout Int,
        maxNodes: Int
    ) {
        guard visited < maxNodes else { return }
        visited += 1

        if (isEditableTextElement(element) || isDraftWritableElement(element)),
           let frame = frameAttribute(on: element),
           isLikelyBottomInputFrame(frame, in: windowFrame) {
            candidates.append(EditableInputCandidate(element: element, frame: frame))
        }

        for child in elementArrayAttribute(kAXChildrenAttribute as String, on: element) {
            collectEditableInputCandidates(
                from: child,
                windowFrame: windowFrame,
                candidates: &candidates,
                visited: &visited,
                maxNodes: maxNodes
            )
        }
    }

    private struct EditableInputCandidate {
        let element: AXUIElement
        let frame: CGRect
    }

    private static func isLikelyBottomInputFrame(_ frame: CGRect, in windowFrame: CGRect?) -> Bool {
        guard frame.width >= 120, frame.height >= 18, frame.height <= 520 else { return false }
        guard let windowFrame else { return true }
        guard frame.intersects(windowFrame) else { return false }
        guard frame.minY >= windowFrame.minY + windowFrame.height * 0.45 else { return false }
        return true
    }

    private static func systemFocusedElement() -> AXUIElement? {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        ) == .success, let focusedObject else {
            return nil
        }
        return (focusedObject as! AXUIElement)
    }

    private static func elementAndParents(from element: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        var elements = [element]
        var cursor: AXUIElement? = element
        var depth = 0

        while depth < maxDepth, let current = cursor, let parent = parent(of: current) {
            elements.append(parent)
            cursor = parent
            depth += 1
        }

        return elements
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var parentObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &parentObject
        ) == .success, let parentObject else {
            return nil
        }
        return (parentObject as! AXUIElement)
    }

    private static func selectedTextLength(on element: AXUIElement) -> Int {
        if let selectedText = stringAttribute(kAXSelectedTextAttribute as String, on: element),
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedText.count
        }

        if let range = rangeAttribute(kAXSelectedTextRangeAttribute as String, on: element) {
            return max(0, range.length)
        }

        var rangesObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangesAttribute as CFString,
            &rangesObject
        ) == .success,
              let ranges = rangesObject as? [AnyObject] else {
            return 0
        }

        return ranges.compactMap { range(from: $0) }.map(\.length).reduce(0, +)
    }

    private static func selectedText(on element: AXUIElement) -> String? {
        if let selectedText = stringAttribute(kAXSelectedTextAttribute as String, on: element),
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedText
        }

        if let range = rangeAttribute(kAXSelectedTextRangeAttribute as String, on: element),
           range.length > 0,
           let text = stringForRange(range, on: element),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        var rangesObject: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangesAttribute as CFString,
            &rangesObject
        ) == .success,
              let ranges = rangesObject as? [AnyObject] else {
            return nil
        }

        let parts = ranges
            .compactMap { range(from: $0) }
            .compactMap { stringForRange($0, on: element) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private static func focusedTextSnapshot(
        from elements: [AXUIElement],
        targetApplication: NSRunningApplication?
    ) -> FocusedDraftSnapshot? {
        for element in elements where isDraftReadableElement(element) {
            if let selectedText = stringAttribute(kAXSelectedTextAttribute as String, on: element),
               isRealFocusedDraft(selectedText, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(
                    text: selectedText,
                    method: .axValue,
                    requiresTrustValidation: requiresTrustValidation(
                        for: element,
                        in: elements,
                        targetApplication: targetApplication
                    )
                )
            }
            if let value = stringAttribute(kAXValueAttribute as String, on: element),
               isRealFocusedDraft(value, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(
                    text: value,
                    method: .axValue,
                    requiresTrustValidation: requiresTrustValidation(
                        for: element,
                        in: elements,
                        targetApplication: targetApplication
                    )
                )
            }
            if let text = stringForFullRange(on: element),
               isRealFocusedDraft(text, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(
                    text: text,
                    method: .axStringForRange,
                    requiresTrustValidation: requiresTrustValidation(
                        for: element,
                        in: elements,
                        targetApplication: targetApplication
                    )
                )
            }
        }
        return nil
    }

    private static func requiresTrustValidation(
        for element: AXUIElement,
        in candidateElements: [AXUIElement],
        targetApplication: NSRunningApplication?
    ) -> Bool {
        if isKnownWeakDraftApplication(targetApplication?.bundleIdentifier) {
            return true
        }

        let contextElements = candidateElements + elementAndParents(from: element, maxDepth: 8)
        return contextElements.contains { element in
            stringAttribute(kAXRoleAttribute as String, on: element) == "AXWebArea"
        }
    }

    private static func isKnownWeakDraftApplication(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        let weakDraftBundleIdentifiers: Set<String> = [
            "com.openai.codex",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "com.apple.Safari",
            "com.apple.SafariTechnologyPreview",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",
            "com.brave.Browser",
            "org.mozilla.firefox"
        ]
        return weakDraftBundleIdentifiers.contains(bundleIdentifier)
    }

    private static func isRealFocusedDraft(
        _ text: String,
        on element: AXUIElement,
        targetApplication: NSRunningApplication?
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let placeholder = stringAttribute("AXPlaceholderValue", on: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !placeholder.isEmpty,
           trimmed == placeholder {
            return false
        }

        let nonDraftLabels = [
            stringAttribute(kAXDescriptionAttribute as String, on: element),
            stringAttribute(kAXTitleAttribute as String, on: element),
            stringAttribute(kAXHelpAttribute as String, on: element)
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if nonDraftLabels.contains(trimmed) {
            return false
        }

        return true
    }

    private static func stringForFullRange(on element: AXUIElement) -> String? {
        let characterCount = integerAttribute("AXNumberOfCharacters", on: element)
        let fullRange: CFRange
        if let characterCount, characterCount > 0 {
            fullRange = CFRange(location: 0, length: characterCount)
        } else if let visibleRange = rangeAttribute("AXVisibleCharacterRange", on: element),
                  visibleRange.length > 0 {
            fullRange = visibleRange
        } else {
            return nil
        }

        return stringForRange(fullRange, on: element)
    }

    private static func stringForRange(_ requestedRange: CFRange, on element: AXUIElement) -> String? {
        var range = requestedRange
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            return nil
        }

        var object: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXStringForRange" as CFString,
            rangeValue,
            &object
        ) == .success else {
            return nil
        }
        return object as? String
    }

    private static func isEditableTextElement(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute as String, on: element)
        let editableRoles: Set<String> = [
            kAXTextAreaRole as String,
            kAXTextFieldRole as String,
            kAXComboBoxRole as String
        ]
        if let role, editableRoles.contains(role) {
            return true
        }

        if boolAttribute("AXEditable", on: element) == true {
            return true
        }

        return isAttributeSettable(kAXSelectedTextAttribute as String, on: element)
            || isAttributeSettable(kAXSelectedTextRangeAttribute as String, on: element)
    }

    private static func isDraftReadableElement(_ element: AXUIElement) -> Bool {
        isEditableTextElement(element) || isDraftWritableElement(element)
    }

    private static func isDraftWritableElement(_ element: AXUIElement) -> Bool {
        isAttributeSettable(kAXValueAttribute as String, on: element)
    }

    private static func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success else {
            return nil
        }
        return object as? String
    }

    private static func elementAttribute(_ attribute: String, on element: AXUIElement) -> AXUIElement? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object else {
            return nil
        }
        return (object as! AXUIElement)
    }

    private static func elementArrayAttribute(_ attribute: String, on element: AXUIElement) -> [AXUIElement] {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let objects = object as? [AnyObject] else {
            return []
        }
        return objects.map { $0 as! AXUIElement }
    }

    private static func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object else {
            return nil
        }
        return (object as? Bool) ?? ((object as? NSNumber)?.boolValue)
    }

    private static func integerAttribute(_ attribute: String, on element: AXUIElement) -> Int? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object else {
            return nil
        }
        return (object as? Int) ?? (object as? NSNumber)?.intValue
    }

    private static func rangeAttribute(_ attribute: String, on element: AXUIElement) -> CFRange? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success else {
            return nil
        }
        return range(from: object)
    }

    private static func frameAttribute(on element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as String, on: element),
              let size = sizeAttribute(kAXSizeAttribute as String, on: element),
              size.width > 20,
              size.height > 10 else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func pointAttribute(_ attribute: String, on element: AXUIElement) -> CGPoint? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object,
              CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }
        let value = object as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private static func sizeAttribute(_ attribute: String, on element: AXUIElement) -> CGSize? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object,
              CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }
        let value = object as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }
        return size
    }

    private static func range(from object: Any?) -> CFRange? {
        guard let object = object as CFTypeRef?,
              CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }
        let value = object as! AXValue
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func isAttributeSettable(_ attribute: String, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else {
            return false
        }
        return settable.boolValue
    }

    private static func repairInsertionPointToEndOnce(of element: AXUIElement, text: String) {
        setInsertionPointToEnd(of: element, text: text)

        // Codex/Electron can accept AXValue and then move the caret to the
        // start on the next UI tick. One short follow-up keeps the default
        // post-insert caret at the end without continuing to fight the user.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            setInsertionPointToEnd(of: element, text: text)
        }
    }

    private static func repairInsertionPointToEndForTypedInsertion(of element: AXUIElement, text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            setInsertionPointToEnd(of: element, text: text)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            setInsertionPointToEnd(of: element, text: text)
        }
    }

    @discardableResult
    private static func setInsertionPointToEnd(of element: AXUIElement, text: String) -> Bool {
        guard isAttributeSettable(kAXSelectedTextRangeAttribute as String, on: element) else {
            return false
        }
        var range = CFRange(location: (text as NSString).length, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            return false
        }
        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success
    }

    private static func postCommandKey(_ keyCode: CGKeyCode, flags: CGEventFlags = .maskCommand) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

}

private struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]

    init(pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            let copiedItem = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type) else { continue }
                copiedItem.setData(data, forType: type)
            }
            return copiedItem
        } ?? []
    }

    @discardableResult
    func restore(to pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        guard !items.isEmpty else { return true }
        return pasteboard.writeObjects(items)
    }
}
