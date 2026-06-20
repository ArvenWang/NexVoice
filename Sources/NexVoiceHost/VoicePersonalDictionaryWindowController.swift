import AppKit
import NexVoiceCore

@MainActor
final class VoicePersonalDictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let summaryLabel = NSTextField(labelWithString: "")
    private let deleteButton = NSButton(title: "删除所选", target: nil, action: nil)
    private var terms: [VoicePersonalDictionaryTerm] = []

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
        terms.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < terms.count, let identifier = tableColumn?.identifier else { return nil }
        let textField = NSTextField(labelWithString: value(for: identifier.rawValue, term: terms[row]))
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

        addColumn(id: "phrase", title: "词条", width: 140)
        addColumn(id: "aliases", title: "别名", width: 160)
        addColumn(id: "weight", title: "基础权重", width: 70)
        addColumn(id: "contexts", title: "场景权重", width: 180)
        addColumn(id: "note", title: "说明 / 状态", width: 190)
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
        let selectedTerms = selectedRows.compactMap { row in
            row >= 0 && row < terms.count ? terms[row] : nil
        }
        guard !selectedTerms.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = selectedTerms.count == 1 ? "删除这个词条？" : "删除 \(selectedTerms.count) 个词条？"
        alert.informativeText = selectedTerms
            .prefix(6)
            .map(\.phrase)
            .joined(separator: "、")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            for term in selectedTerms {
                try VoicePersonalDictionaryStore.delete(phrase: term.phrase)
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
        terms = VoicePersonalDictionaryStore.load().terms.sorted {
            if $0.weight == $1.weight {
                return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
            return $0.weight > $1.weight
        }
        summaryLabel.stringValue = terms.isEmpty ? "暂无词条" : "\(terms.count) 个词条"
        tableView.reloadData()
        deleteButton.isEnabled = tableView.numberOfSelectedRows > 0
    }

    private func value(for columnID: String, term: VoicePersonalDictionaryTerm) -> String {
        switch columnID {
        case "phrase":
            return term.phrase
        case "aliases":
            return term.aliases.isEmpty ? "-" : term.aliases.joined(separator: "、")
        case "weight":
            return "\(term.weight)"
        case "contexts":
            guard !term.contextWeights.isEmpty else { return "-" }
            return term.contextWeights
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value > rhs.value
                }
                .prefix(4)
                .map { "\($0.key.replacingOccurrences(of: "bundle:", with: "")) ×\($0.value)" }
                .joined(separator: "，")
        case "note":
            let note = term.note?.isEmpty == false ? term.note! : "已启用"
            return "\(note)"
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
