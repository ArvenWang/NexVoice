import AppKit
import ApplicationServices
import CoreGraphics

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
        let keyV: CGKeyCode = 9
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
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
