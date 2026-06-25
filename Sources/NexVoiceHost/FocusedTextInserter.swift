import AppKit
import ApplicationServices
import CoreGraphics
import NexVoiceCore

struct SelectedTextContext {
    let text: String
    let anchorRect: CGRect
}

enum FocusedTextAccessMethod: String {
    case axValue
    case axStringForRange
    case axSetValue
    case axClearThenUnicodeTyping
    case keyboardInsert
}

struct FocusedDraftSnapshot {
    let text: String
    let method: FocusedTextAccessMethod
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
        if Self.shouldUseCodexMultilineTypingReplacement(insertionText, in: targetApplication),
           Self.replaceFocusedDraftUsingAXClearThenUnicodeTyping(insertionText, in: targetApplication) {
            latestInsertionMethod = .axClearThenUnicodeTyping
            return
        }
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
        guard canPostKeyboardEvents else { return nil }
        guard !Self.hasEditableSelectedText(in: targetApplication) else { return nil }

        restoreWorkItem?.cancel()
        let activationAnchorRect = CGRect(origin: NSEvent.mouseLocation, size: .zero)
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        let baselineChangeCount = pasteboard.changeCount

        targetApplication?.activate(options: [.activateIgnoringOtherApps])
        try? await Task.sleep(nanoseconds: 80_000_000)
        Self.postCommandC()
        try? await Task.sleep(nanoseconds: 180_000_000)

        let selectedText = pasteboard.changeCount != baselineChangeCount
            ? pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        snapshot.restore(to: pasteboard)

        guard let selectedText, !selectedText.isEmpty else { return nil }
        return SelectedTextContext(text: selectedText, anchorRect: activationAnchorRect)
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
        return Self.focusedTextSnapshot(from: elementChain, targetApplication: targetApplication)?.text
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

    private static func hasEditableSelectedText(in targetApplication: NSRunningApplication?) -> Bool {
        guard let focusedElement = focusedElement(in: targetApplication) ?? systemFocusedElement() else {
            return false
        }

        return elementAndParents(from: focusedElement, maxDepth: 4).contains { element in
            selectedTextLength(on: element) > 0 && isEditableTextElement(element)
        }
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
        return elementChain.first(where: isEditableTextElement)
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

    private static func shouldUseCodexMultilineTypingReplacement(
        _ text: String,
        in targetApplication: NSRunningApplication?
    ) -> Bool {
        targetApplication?.bundleIdentifier == "com.openai.codex"
            && (text.contains("\n") || text.contains("\r"))
    }

    private static func replaceFocusedDraftUsingAXClearThenUnicodeTyping(
        _ text: String,
        in targetApplication: NSRunningApplication?
    ) -> Bool {
        guard let element = focusedEditableElement(in: targetApplication),
              isAttributeSettable(kAXValueAttribute as String, on: element),
              AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                "" as CFTypeRef
              ) == .success else {
            return false
        }

        setInsertionPointToEnd(of: element, text: "")
        targetApplication?.activate(options: [.activateIgnoringOtherApps])
        guard postUnicodeText(text) else {
            return false
        }

        repairInsertionPointToEndOnce(of: element, text: text)
        return true
    }

    private static func bottomEditableInputFrame(in targetApplication: NSRunningApplication?) -> CGRect? {
        guard let processIdentifier = targetApplication?.processIdentifier else { return nil }
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var roots: [AXUIElement] = []
        if let focusedWindow = elementAttribute(kAXFocusedWindowAttribute as String, on: applicationElement) {
            roots.append(focusedWindow)
        }
        roots.append(contentsOf: elementArrayAttribute(kAXWindowsAttribute as String, on: applicationElement))

        var candidates: [CGRect] = []
        var visited = 0
        for root in roots {
            let windowFrame = frameAttribute(on: root)
            collectEditableInputFrames(
                from: root,
                windowFrame: windowFrame,
                candidates: &candidates,
                visited: &visited,
                maxNodes: 500
            )
        }

        return candidates.max { lhs, rhs in
            if abs(lhs.minY - rhs.minY) > 8 {
                return lhs.minY < rhs.minY
            }
            return lhs.width < rhs.width
        }
    }

    private static func collectEditableInputFrames(
        from element: AXUIElement,
        windowFrame: CGRect?,
        candidates: inout [CGRect],
        visited: inout Int,
        maxNodes: Int
    ) {
        guard visited < maxNodes else { return }
        visited += 1

        if isEditableTextElement(element), let frame = frameAttribute(on: element),
           isLikelyBottomInputFrame(frame, in: windowFrame) {
            candidates.append(frame)
        }

        for child in elementArrayAttribute(kAXChildrenAttribute as String, on: element) {
            collectEditableInputFrames(
                from: child,
                windowFrame: windowFrame,
                candidates: &candidates,
                visited: &visited,
                maxNodes: maxNodes
            )
        }
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

    private static func focusedTextSnapshot(
        from elements: [AXUIElement],
        targetApplication: NSRunningApplication?
    ) -> FocusedDraftSnapshot? {
        for element in elements where isEditableTextElement(element) {
            if let selectedText = stringAttribute(kAXSelectedTextAttribute as String, on: element),
               isRealFocusedDraft(selectedText, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(text: selectedText, method: .axValue)
            }
            if let value = stringAttribute(kAXValueAttribute as String, on: element),
               isRealFocusedDraft(value, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(text: value, method: .axValue)
            }
            if let text = stringForFullRange(on: element),
               isRealFocusedDraft(text, on: element, targetApplication: targetApplication) {
                return FocusedDraftSnapshot(text: text, method: .axStringForRange)
            }
        }
        return nil
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

        if targetApplication?.bundleIdentifier == "com.openai.codex" {
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
        }

        return !isKnownNonDraftPlaceholder(trimmed, targetApplication: targetApplication)
    }

    private static func isKnownNonDraftPlaceholder(
        _ text: String,
        targetApplication: NSRunningApplication?
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard targetApplication?.bundleIdentifier == "com.openai.codex" else { return false }
        return codexNonDraftPlaceholderTexts.contains(trimmed)
    }

    private static let codexNonDraftPlaceholderTexts: Set<String> = [
        "要求后续变更"
    ]

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

        var range = fullRange
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

        return isAttributeSettable(kAXValueAttribute as String, on: element)
            || isAttributeSettable(kAXSelectedTextAttribute as String, on: element)
            || isAttributeSettable(kAXSelectedTextRangeAttribute as String, on: element)
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

    private static func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func postUnicodeText(_ text: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        for chunk in unicodeInputChunks(from: text) {
            let utf16 = Array(chunk.utf16)
            guard !utf16.isEmpty,
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }

            utf16.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buffer.baseAddress)
            }
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.001)
        }
        return true
    }

    private static func unicodeInputChunks(from text: String, maxUTF16Units: Int = 64) -> [String] {
        var chunks: [String] = []
        var current = ""
        var currentLength = 0

        for character in text {
            let fragment = String(character)
            let fragmentLength = fragment.utf16.count
            if currentLength > 0, currentLength + fragmentLength > maxUTF16Units {
                chunks.append(current)
                current = ""
                currentLength = 0
            }
            current.append(fragment)
            currentLength += fragmentLength
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
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

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}
