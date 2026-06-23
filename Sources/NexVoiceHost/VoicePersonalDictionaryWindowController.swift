import AppKit
import NexVoiceCore

@MainActor
final class VoicePersonalDictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private enum Row {
        case term(VoicePersonalDictionaryTerm)
        case correction(VoicePersonalDictionaryCorrection)
    }

    private let tableView = NSTableView()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let deleteButton = NSButton(title: "删除所选", target: nil, action: nil)
    private var rows: [Row] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NexVoice 个人词库"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        reloadDictionary()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        reloadDictionary()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count, let identifier = tableColumn?.identifier else { return nil }
        let textField = NSTextField(labelWithString: value(for: identifier.rawValue, row: rows[row]))
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 2
        textField.font = .systemFont(ofSize: 12)
        return textField
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.spacing = 12
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let title = NSTextField(labelWithString: "个人词库")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.font = .systemFont(ofSize: 12)

        deleteButton.target = self
        deleteButton.action = #selector(deleteSelectedTerms)
        deleteButton.isEnabled = false

        let refreshButton = NSButton(title: "刷新", target: self, action: #selector(refreshDictionary))
        header.addArrangedSubview(title)
        header.addArrangedSubview(summaryLabel)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(deleteButton)
        header.addArrangedSubview(refreshButton)
        header.setHuggingPriority(.defaultLow, for: .horizontal)

        configureTable()
        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        rootStack.addArrangedSubview(header)
        rootStack.addArrangedSubview(scrollView)
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
    }

    private func configureTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.headerView = NSTableHeaderView()
        tableView.allowsMultipleSelection = true

        addColumn(id: "type", title: "类型", width: 70)
        addColumn(id: "phrase", title: "内容", width: 210)
        addColumn(id: "weight", title: "权重 / 目标", width: 100)
        addColumn(id: "contexts", title: "场景权重", width: 180)
        addColumn(id: "note", title: "说明 / 状态", width: 220)
    }

    private func addColumn(id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        column.minWidth = 60
        tableView.addTableColumn(column)
    }

    @objc private func refreshDictionary() {
        reloadDictionary()
    }

    @objc private func deleteSelectedTerms() {
        let selectedRows = tableView.selectedRowIndexes
        let selectedTerms = selectedRows.compactMap { row -> VoicePersonalDictionaryTerm? in
            guard row >= 0 && row < rows.count else { return nil }
            if case .term(let term) = rows[row] { return term }
            return nil
        }
        let selectedCorrections = selectedRows.compactMap { row -> VoicePersonalDictionaryCorrection? in
            guard row >= 0 && row < rows.count else { return nil }
            if case .correction(let correction) = rows[row] { return correction }
            return nil
        }
        guard !selectedTerms.isEmpty || !selectedCorrections.isEmpty else { return }

        let alert = NSAlert()
        let selectedCount = selectedTerms.count + selectedCorrections.count
        alert.messageText = selectedCount == 1 ? "删除这一项？" : "删除 \(selectedCount) 项？"
        let previewItems = selectedTerms
            .prefix(6)
            .map(\.phrase)
            + selectedCorrections
                .prefix(max(0, 6 - selectedTerms.count))
                .map { "\($0.observedText) -> \($0.targetTerm)" }
        alert.informativeText = previewItems.joined(separator: "、")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            for term in selectedTerms {
                try VoicePersonalDictionaryStore.delete(phrase: term.phrase)
            }
            for correction in selectedCorrections {
                try VoicePersonalDictionaryStore.deleteCorrection(
                    observedText: correction.observedText,
                    targetTerm: correction.targetTerm
                )
            }
            reloadDictionary()
        } catch {
            showError("删除词条失败：\(error.localizedDescription)")
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        deleteButton.isEnabled = tableView.numberOfSelectedRows > 0
    }

    private func reloadDictionary() {
        let dictionary = VoicePersonalDictionaryStore.load()
        let terms = dictionary.terms.sorted {
            if $0.weight == $1.weight {
                return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
            return $0.weight > $1.weight
        }
        let corrections = dictionary.corrections.sorted {
            if $0.targetTerm == $1.targetTerm {
                return $0.observedText.localizedCaseInsensitiveCompare($1.observedText) == .orderedAscending
            }
            return $0.targetTerm.localizedCaseInsensitiveCompare($1.targetTerm) == .orderedAscending
        }
        rows = terms.map(Row.term) + corrections.map(Row.correction)
        if rows.isEmpty {
            summaryLabel.stringValue = "暂无词条"
        } else {
            summaryLabel.stringValue = "\(terms.count) 个热词，\(corrections.count) 条纠错"
        }
        tableView.reloadData()
        deleteButton.isEnabled = tableView.numberOfSelectedRows > 0
    }

    private func value(for columnID: String, row: Row) -> String {
        switch columnID {
        case "type":
            switch row {
            case .term:
                return "热词"
            case .correction:
                return "纠错"
            }
        case "phrase":
            switch row {
            case .term(let term):
                return term.phrase
            case .correction(let correction):
                return correction.observedText
            }
        case "weight":
            switch row {
            case .term(let term):
                return "\(term.weight)"
            case .correction(let correction):
                return correction.targetTerm
            }
        case "contexts":
            let contextWeights: [String: Int]
            switch row {
            case .term(let term):
                contextWeights = term.contextWeights
            case .correction(let correction):
                contextWeights = correction.contextWeights
            }
            guard !contextWeights.isEmpty else { return "-" }
            return contextWeights
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value > rhs.value
                }
                .prefix(4)
                .map { "\($0.key.replacingOccurrences(of: "bundle:", with: "")) ×\($0.value)" }
                .joined(separator: "，")
        case "note":
            switch row {
            case .term(let term):
                return term.note?.isEmpty == false ? term.note! : "已启用"
            case .correction(let correction):
                let note = correction.note?.isEmpty == false ? correction.note! : "已启用"
                return "\(String(format: "%.0f%%", correction.confidence * 100)) · \(note)"
            }
        default:
            return ""
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "个人词库"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
