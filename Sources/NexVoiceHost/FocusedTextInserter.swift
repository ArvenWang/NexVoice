import AppKit
import ApplicationServices
import CoreGraphics
import NexVoiceCore

struct SelectedTextContext {
    let text: String
    let anchorRect: CGRect
}

enum FocusedTextInsertionError: LocalizedError {
    case emptyText
    case accessibilityPermissionRequired
    case pasteboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "没有可输入的文本。"
        case .accessibilityPermissionRequired:
            return "需要辅助功能权限，才能把文字输入到当前文本框。"
        case .pasteboardWriteFailed:
            return "写入系统剪贴板失败。"
        }
    }
}

@MainActor
final class FocusedTextInserter {
    private let pasteboard: NSPasteboard
    private var restoreWorkItem: DispatchWorkItem?

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
            focusedTextPreview: Self.focusedTextPreview(from: elementChain),
            selectedTextMode: selectedTextMode,
            personalDictionary: personalDictionary
        )
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

    private static func focusedTextPreview(from elements: [AXUIElement]) -> String? {
        for element in elements where isEditableTextElement(element) {
            if let selectedText = stringAttribute(kAXSelectedTextAttribute as String, on: element),
               !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selectedText
            }
            if let value = stringAttribute(kAXValueAttribute as String, on: element),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
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

    private static func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success,
              let object else {
            return nil
        }
        return (object as? Bool) ?? ((object as? NSNumber)?.boolValue)
    }

    private static func rangeAttribute(_ attribute: String, on element: AXUIElement) -> CFRange? {
        var object: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &object) == .success else {
            return nil
        }
        return range(from: object)
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

    private static func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
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

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}
