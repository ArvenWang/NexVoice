import AppKit
import NexVoiceCore

@MainActor
final class VoiceSettingsWindowController: NSWindowController, NSWindowDelegate {
    private enum Token {
        static let contentSize = NSSize(width: 760, height: 472)
        static let sidebarWidth: CGFloat = 164
        static let pageWidth: CGFloat = 496
        static let pageTop: CGFloat = 33
        static let pageBottom: CGFloat = 22
        static let rowValueWidth: CGFloat = 168
        static let controlHeight: CGFloat = 30
        static let tabHeight: CGFloat = 34
        static let primaryButtonHeight: CGFloat = 32
        static let inputPrimaryButtonHeight: CGFloat = 26
        static let buttonHeight: CGFloat = 28
        static let buttonMinWidth: CGFloat = 62
        static let radiusSmall: CGFloat = 7
        static let radiusMedium: CGFloat = 9
        static let radiusLarge: CGFloat = 11
        static let rowPaddingX: CGFloat = 17
        static let rowPaddingY: CGFloat = 15
        static let rowGap: CGFloat = 14

        static let window = NSColor(hex: 0x111112)
        static let sidebar = NSColor(hex: 0x151516)
        static let panel = NSColor(hex: 0x171718)
        static let field = NSColor(hex: 0x252527)
        static let text = NSColor.white.withAlphaComponent(0.93)
        static let muted = NSColor.white.withAlphaComponent(0.58)
        static let faint = NSColor.white.withAlphaComponent(0.38)
        static let line = NSColor.white.withAlphaComponent(0.045)
        static let lineStrong = NSColor.white.withAlphaComponent(0.065)
        static let selected = NSColor.white.withAlphaComponent(0.105)
        static let navSelected = NSColor.white.withAlphaComponent(0.075)
        static let hover = NSColor.white.withAlphaComponent(0.09)
        static let active = NSColor.white.withAlphaComponent(0.14)
        static let focusFill = NSColor.white.withAlphaComponent(0.055)
        static let focusBorder = NSColor.white.withAlphaComponent(0.18)
        static let hoverBorder = NSColor.white.withAlphaComponent(0.14)
        static let green = NSColor(hex: 0x68D76E)
        static let blue = NSColor(hex: 0x58AEEA)
        static let blueSoft = NSColor(hex: 0x58AEEA).withAlphaComponent(0.16)
        static let blueHover = NSColor(hex: 0x58AEEA).withAlphaComponent(0.23)
        static let primaryFill = NSColor.white.withAlphaComponent(0.105)
        static let primaryHover = NSColor.white.withAlphaComponent(0.17)
        static let primaryActive = NSColor.white.withAlphaComponent(0.22)
    }

    enum Tab: Int {
        case input
        case modes
        case workflow
        case dictionary
        case permissions

        var title: String {
            switch self {
            case .input: return "输入"
            case .modes: return "输出模式"
            case .workflow: return "工作流"
            case .dictionary: return "词库"
            case .permissions: return "权限"
            }
        }

        var icon: String {
            switch self {
            case .input: return "⌘"
            case .modes: return "✦"
            case .workflow: return "◇"
            case .dictionary: return "▦"
            case .permissions: return "●"
            }
        }
    }

    private enum WorkflowOption: CaseIterable {
        case agentCollaboration
        case emailReply
        case social
        case workChat
        case general

        var title: String {
            switch self {
            case .agentCollaboration: return "开发协作"
            case .emailReply: return "邮件回复"
            case .social: return "社交发布"
            case .workChat: return "即时沟通"
            case .general: return "通用输入"
            }
        }

        var identifier: String {
            switch self {
            case .agentCollaboration: return "agent-collaboration"
            case .emailReply: return "email-reply"
            case .social: return "social"
            case .workChat: return "work-chat"
            case .general: return "general"
            }
        }

        var promptHint: String {
            switch self {
            case .agentCollaboration:
                return "保留用户的任务、约束、判断和问题边界；不要把需求改成泛泛建议。"
            case .emailReply:
                return "表达礼貌清楚、有分寸；补齐必要称呼或收尾时要克制，不要模板化。"
            case .social:
                return "像真人自然发言，避免翻译腔、营销腔和过度正式；允许更强的网感。"
            case .workChat:
                return "简洁自然，行动明确，少铺垫；不要把短消息扩写成正式文档。"
            case .general:
                return "清晰自然，少加工，可直接发送。"
            }
        }

        var likelySources: String {
            switch self {
            case .agentCollaboration: return "Codex、Cursor、Xcode、VS Code、ChatGPT"
            case .emailReply: return "Mail、Outlook、Gmail、Spark"
            case .social: return "X、Reddit、Threads、评论框"
            case .workChat: return "微信、飞书、Slack、Telegram"
            case .general: return "普通输入框和文本编辑器"
            }
        }

        init(workflow: VoiceAppWorkflow) {
            switch workflow.identifier {
            case "agent-collaboration":
                self = .agentCollaboration
            case "email-reply":
                self = .emailReply
            case "social":
                self = .social
            case "work-chat":
                self = .workChat
            default:
                self = .general
            }
        }
    }

    private enum DictionaryFilter: CaseIterable {
        case all
        case automatic
        case manual

        var title: String {
            switch self {
            case .all: return "全部"
            case .automatic: return "自动学习"
            case .manual: return "手动添加"
            }
        }
    }

    private struct ModeDescriptor {
        let style: VoiceRewriteStyle
        let title: String
        let description: String
        let fidelity: Int
        let emotion: Int
        let divergence: Int
    }

    private static let modeDescriptors: [ModeDescriptor] = [
        ModeDescriptor(
            style: .standard,
            title: "标准模式",
            description: "修正吞字、断词和重复，让表达自然清晰；严格贴合原意，不添加新观点。",
            fidelity: 95,
            emotion: 30,
            divergence: 10
        ),
        ModeDescriptor(
            style: .socialExpert,
            title: "社交达人",
            description: "适合聊天、评论和社媒；表达轻松有网感，英文更地道。",
            fidelity: 78,
            emotion: 58,
            divergence: 42
        ),
        ModeDescriptor(
            style: .amplifiedSpokesperson,
            title: "强化嘴替",
            description: "放大原本情绪和态度，表达更锋利、更有冲击力。",
            fidelity: 62,
            emotion: 96,
            divergence: 76
        ),
        ModeDescriptor(
            style: .calm,
            title: "冷静模式",
            description: "压低攻击性和混乱表达，用更少的字保留核心诉求。",
            fidelity: 88,
            emotion: 18,
            divergence: 14
        )
    ]

    private let contentContainer = NSView()
    private var tabButtons: [Tab: SidebarNavButton] = [:]
    private var activeContentView: NSView?
    private var localShortcutMonitor: Any?
    private var languageButtons: [VoiceOutputLanguage: NSButton] = [:]
    private var modeCards: [VoiceRewriteStyle: ClickablePanelView] = [:]
    private var workflowButtons: [WorkflowOption: NSButton] = [:]
    private var dictionaryFilterButtons: [DictionaryFilter: NSButton] = [:]
    private let shortcutFieldLabel = NSTextField(labelWithString: "")
    private let dictionaryListStack = FlippedStackView()
    private let dictionaryListContainer = FlippedView()
    private let microphoneStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let screenRecordingStatusLabel = NSTextField(labelWithString: "")
    private var dictionaryOverlay: NSView?
    private weak var dictionaryTermInput: NSTextField?
    private var dictionaryOverlayKeyMonitor: Any?
    private var dictionaryListLayoutConstraints: [NSLayoutConstraint] = []
    private var isWindowSuspendingGlobalShortcut = false
    private var isRecordingShortcut = false

    private var selectedTab: Tab
    private var selectedWorkflow: WorkflowOption = .agentCollaboration
    private var workflowWasManuallySelected = false
    private var dictionaryFilter: DictionaryFilter = .all
    private var shortcut: VoiceShortcut
    private var outputLanguage: VoiceOutputLanguage
    private var rewriteStyle: VoiceRewriteStyle

    private let workflowContextProvider: () -> VoiceRewriteContext
    private let canChangeInputSettings: () -> Bool
    private let onShortcutChanged: (VoiceShortcut) -> Void
    private let onOutputLanguageChanged: (VoiceOutputLanguage) -> Void
    private let onRewriteStyleChanged: (VoiceRewriteStyle) -> Void
    private let onShortcutRecordingStateChanged: (Bool) -> Void
    private let onRequestMicrophonePermission: () -> Void
    private let onRequestAccessibilityPermission: () -> Void
    private let onRequestScreenRecordingPermission: () -> Void

    init(
        selectedTab: Tab = .input,
        shortcut: VoiceShortcut,
        outputLanguage: VoiceOutputLanguage,
        rewriteStyle: VoiceRewriteStyle,
        workflowContextProvider: @escaping () -> VoiceRewriteContext,
        canChangeInputSettings: @escaping () -> Bool,
        onShortcutChanged: @escaping (VoiceShortcut) -> Void,
        onOutputLanguageChanged: @escaping (VoiceOutputLanguage) -> Void,
        onRewriteStyleChanged: @escaping (VoiceRewriteStyle) -> Void,
        onShortcutRecordingStateChanged: @escaping (Bool) -> Void = { _ in },
        onRequestMicrophonePermission: @escaping () -> Void,
        onRequestAccessibilityPermission: @escaping () -> Void,
        onRequestScreenRecordingPermission: @escaping () -> Void
    ) {
        self.selectedTab = selectedTab
        self.shortcut = shortcut
        self.outputLanguage = outputLanguage
        self.rewriteStyle = rewriteStyle
        self.workflowContextProvider = workflowContextProvider
        self.canChangeInputSettings = canChangeInputSettings
        self.onShortcutChanged = onShortcutChanged
        self.onOutputLanguageChanged = onOutputLanguageChanged
        self.onRewriteStyleChanged = onRewriteStyleChanged
        self.onShortcutRecordingStateChanged = onShortcutRecordingStateChanged
        self.onRequestMicrophonePermission = onRequestMicrophonePermission
        self.onRequestAccessibilityPermission = onRequestAccessibilityPermission
        self.onRequestScreenRecordingPermission = onRequestScreenRecordingPermission

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Token.contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = SettingsRootView(frame: NSRect(origin: .zero, size: Token.contentSize))
        window.title = "NexVoice 设置"
        window.minSize = Token.contentSize
        window.maxSize = Token.contentSize
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        select(tab: selectedTab)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        refreshAll()
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
        isWindowSuspendingGlobalShortcut = true
        updateGlobalShortcutSuspension()
    }

    func windowWillClose(_ notification: Notification) {
        stopShortcutRecording()
        cancelDictionaryOverlay()
        isWindowSuspendingGlobalShortcut = false
        updateGlobalShortcutSuspension()
    }

    func update(
        shortcut: VoiceShortcut,
        outputLanguage: VoiceOutputLanguage,
        rewriteStyle: VoiceRewriteStyle
    ) {
        self.shortcut = shortcut
        self.outputLanguage = outputLanguage
        self.rewriteStyle = rewriteStyle
        refreshAll()
    }

    func select(tab: Tab) {
        selectedTab = tab
        refreshNavigation()
        activeContentView?.removeFromSuperview()

        let view: NSView
        switch tab {
        case .input:
            view = makeInputView()
        case .modes:
            view = makeModesView()
        case .workflow:
            view = makeWorkflowView()
        case .dictionary:
            view = makeDictionaryView()
        case .permissions:
            view = makePermissionsView()
        }

        activeContentView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor)
        ])
        refreshAll()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }
        if let rootView = contentView as? SettingsRootView {
            rootView.fallbackClickHandler = { [weak self, weak rootView] point in
                guard let self, let rootView else { return false }
                return self.routeFallbackClick(at: point, in: rootView)
            }
        }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Token.window.cgColor

        let sidebar = makeSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(sidebar)
        contentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: Token.sidebarWidth),

            contentContainer.widthAnchor.constraint(equalToConstant: Token.pageWidth),
            contentContainer.centerXAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Token.sidebarWidth + ((Token.contentSize.width - Token.sidebarWidth) / 2)),
            contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Token.pageTop),
            contentContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Token.pageBottom)
        ])
    }

    private func makeSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = Token.sidebar.cgColor
        sidebar.layer?.borderColor = Token.line.cgColor
        sidebar.layer?.borderWidth = 1

        let brand = text("NexVoice", size: 13, weight: .bold, color: Token.text)
        var navButtons: [SidebarNavButton] = []
        for tab in Tab.allCases {
            let button = navButton(tab)
            tabButtons[tab] = button
            navButtons.append(button)
        }

        let plan = makePlanView()
        ([brand, plan] + navButtons).forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            sidebar.addSubview($0)
        }

        var constraints: [NSLayoutConstraint] = [
            brand.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            brand.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            brand.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 31),
            brand.heightAnchor.constraint(equalToConstant: 16),

            plan.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            plan.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            plan.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -14),
            plan.heightAnchor.constraint(equalToConstant: 100)
        ]
        for (index, button) in navButtons.enumerated() {
            constraints.append(contentsOf: [
                button.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
                button.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
                button.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 11 + CGFloat(index * 32)),
                button.heightAnchor.constraint(equalToConstant: 28)
            ])
        }
        NSLayoutConstraint.activate(constraints)

        refreshNavigation()
        return sidebar
    }

    private func navButton(_ tab: Tab) -> SidebarNavButton {
        let button = SidebarNavButton(icon: tab.icon, title: tab.title)
        button.target = self
        button.action = #selector(tabButtonClicked(_:))
        button.identifier = NSUserInterfaceItemIdentifier("\(tab.rawValue)")
        button.setAccessibilityLabel(tab.title)
        button.setButtonType(.momentaryChange)
        button.widthAnchor.constraint(equalToConstant: Token.sidebarWidth - 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func makePlanView() -> NSView {
        let view = roundedPanel(background: NSColor.white.withAlphaComponent(0.045), radius: Token.radiusMedium, border: Token.line)
        let title = text("本地测试版本", size: 12, weight: .semibold, color: Token.text)
        let detail = text("API 配置已嵌入，仅用于当前私用构建。", size: 10, weight: .regular, color: Token.muted, lines: 2)
        let version = text(appVersionText(), size: 11, weight: .bold, color: Token.blue)

        [title, detail, version].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 13),
            title.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -13),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 13),

            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7),

            version.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            version.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            version.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 9)
        ])
        return view
    }

    @objc private func tabButtonClicked(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let index = Int(rawValue),
              let tab = Tab(rawValue: index) else {
            return
        }
        select(tab: tab)
    }

    private func refreshNavigation() {
        for (tab, button) in tabButtons {
            let selected = tab == selectedTab
            button.setSelected(
                selected,
                iconColor: Token.faint,
                titleColor: selected ? Token.text : Token.muted,
                selectedBackground: Token.navSelected
            )
        }
    }

    private func makeInputView() -> NSView {
        let page = pageView(title: "输入设置")
        let card = cardView(rows: [
            settingRow(
                title: "快捷键",
                detail: "短按开始语音输入，长按进入看屏回复。",
                value: makeShortcutField()
            ),
            settingRow(
                title: "快捷键操作",
                detail: "重新录制快捷键，或恢复默认右 Alt。",
                value: makeShortcutButtons()
            ),
            settingRow(
                title: "输出语言",
                detail: "用于语音输入、选中文本指令和看屏回复。",
                value: makeLanguageControl()
            )
        ])
        placeContent(card, in: page, belowTitleBy: 16)
        return page
    }

    private func makeShortcutField() -> NSView {
        let field = roundedPanel(background: Token.field, radius: Token.radiusSmall, border: Token.lineStrong)
        field.translatesAutoresizingMaskIntoConstraints = false
        if isRecordingShortcut {
            field.layer?.backgroundColor = Token.focusFill.cgColor
            field.layer?.borderColor = Token.focusBorder.cgColor
            field.layer?.borderWidth = 1
        }
        shortcutFieldLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        shortcutFieldLabel.textColor = NSColor.white.withAlphaComponent(0.78)
        shortcutFieldLabel.lineBreakMode = .byTruncatingTail
        configureLabel(shortcutFieldLabel)
        shortcutFieldLabel.translatesAutoresizingMaskIntoConstraints = false
        field.addSubview(shortcutFieldLabel)
        NSLayoutConstraint.activate([
            field.widthAnchor.constraint(equalToConstant: Token.rowValueWidth),
            field.heightAnchor.constraint(equalToConstant: Token.controlHeight),
            shortcutFieldLabel.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 10),
            shortcutFieldLabel.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -10),
            shortcutFieldLabel.centerYAnchor.constraint(equalTo: field.centerYAnchor)
        ])
        return field
    }

    private func makeShortcutButtons() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8

        let record = button(title: "录制", style: .primary, width: Token.buttonMinWidth, height: Token.inputPrimaryButtonHeight)
        record.target = self
        record.action = #selector(beginShortcutRecording)
        record.identifier = NSUserInterfaceItemIdentifier("recordShortcut")

        let reset = button(title: "恢复", style: .secondary, width: Token.buttonMinWidth, height: Token.buttonHeight)
        reset.target = self
        reset.action = #selector(resetShortcut)
        reset.identifier = NSUserInterfaceItemIdentifier("resetShortcut")

        stack.addArrangedSubview(record)
        stack.addArrangedSubview(reset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: Token.rowValueWidth).isActive = true
        return stack
    }

    private func makeLanguageControl() -> NSView {
        let control = segmentedControl(width: Token.rowValueWidth, height: Token.controlHeight)
        languageButtons.removeAll()
        for language in VoiceOutputLanguage.allCases {
            let button = segmentButton(title: language.menuTitle, selected: language == outputLanguage, height: Token.controlHeight - 6)
            button.identifier = NSUserInterfaceItemIdentifier(language.rawValue)
            button.target = self
            button.action = #selector(outputLanguageButtonClicked(_:))
            languageButtons[language] = button
            control.addArrangedSubview(button)
        }
        return control
    }

    private func makeModesView() -> NSView {
        let page = pageView(title: "输出模式")
        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.xPlacement = .fill
        grid.yPlacement = .fill

        modeCards.removeAll()
        let rows = stride(from: 0, to: Self.modeDescriptors.count, by: 2).map { start -> [NSView] in
            let first = makeModeCard(Self.modeDescriptors[start])
            let second = makeModeCard(Self.modeDescriptors[start + 1])
            return [first, second]
        }
        for row in rows {
            grid.addRow(with: row)
        }

        page.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            grid.topAnchor.constraint(equalTo: page.topAnchor, constant: 38),
            grid.heightAnchor.constraint(equalToConstant: 356)
        ])
        return page
    }

    private func makeModeCard(_ descriptor: ModeDescriptor) -> ClickablePanelView {
        let selected = descriptor.style == rewriteStyle
        let card = ClickablePanelView()
        card.wantsLayer = true
        card.layer?.cornerRadius = Token.radiusLarge
        card.layer?.backgroundColor = (selected ? Token.focusFill : Token.panel).cgColor
        card.layer?.borderColor = (selected ? Token.focusBorder : Token.lineStrong).cgColor
        card.layer?.borderWidth = 1
        card.setFeedbackColors(
            normal: selected ? Token.focusFill : Token.panel,
            hover: selected ? NSColor.white.withAlphaComponent(0.075) : Token.hover,
            active: selected ? NSColor.white.withAlphaComponent(0.105) : Token.active,
            border: selected ? Token.focusBorder : Token.lineStrong,
            hoverBorder: selected ? Token.focusBorder : Token.hoverBorder
        )
        card.onClick = { [weak self] in
            self?.setRewriteStyle(descriptor.style)
        }
        modeCards[descriptor.style] = card

        let title = text(descriptor.title, size: 13, weight: .semibold, color: Token.text)
        let detail = text(descriptor.description, size: 11, weight: .regular, color: Token.muted, lines: 2)
        let metrics = metricStack([
            ("原意", descriptor.fidelity),
            ("情绪", descriptor.emotion),
            ("发散", descriptor.divergence)
        ], highlighted: selected)
        card.identifier = NSUserInterfaceItemIdentifier(descriptor.style.rawValue)
        card.setAccessibilityLabel(descriptor.title)

        [title, detail, metrics].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview($0)
        }
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 244),
            card.heightAnchor.constraint(equalToConstant: 174),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 17),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -17),
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),

            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),

            metrics.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            metrics.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            metrics.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        return card
    }

    private func makeWorkflowView() -> NSView {
        let context = workflowContextProvider()
        if !workflowWasManuallySelected {
            selectedWorkflow = WorkflowOption(workflow: context.applicationWorkflow)
        }

        let page = pageView(title: "工作流")
        let tabs = workflowTabControl()
        let detail = workflowDetailCard(context: context)
        [tabs, detail].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            page.addSubview($0)
        }
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            tabs.topAnchor.constraint(equalTo: page.topAnchor, constant: 38),
            tabs.heightAnchor.constraint(equalToConstant: Token.tabHeight),

            detail.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            detail.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 12)
        ])
        return page
    }

    private func workflowTabControl() -> NSStackView {
        let tabs = segmentedControl(width: Token.pageWidth, height: Token.tabHeight)
        workflowButtons.removeAll()
        for option in WorkflowOption.allCases {
            let button = segmentButton(title: option.title, selected: option == selectedWorkflow, height: Token.tabHeight - 6)
            button.identifier = NSUserInterfaceItemIdentifier(option.identifier)
            button.target = self
            button.action = #selector(workflowTabClicked(_:))
            workflowButtons[option] = button
            tabs.addArrangedSubview(button)
        }
        return tabs
    }

    private func workflowDetailCard(context: VoiceRewriteContext) -> NSView {
        let popup = rewriteStylePopup()
        popup.widthAnchor.constraint(equalToConstant: 128).isActive = true
        let card = cardView(rows: [
            settingRow(
                title: "当前应用",
                detail: "打开设置时读取前台应用和焦点输入框。",
                value: valueText(context.sourceApplicationName ?? "未知")
            ),
            settingRow(
                title: "识别场景",
                detail: "根据当前应用判断你更像在写哪类内容。",
                value: valueText(selectedWorkflow.title)
            ),
            settingRow(
                title: "输出模式",
                detail: "选择当前默认改写风格。",
                value: popup
            ),
            settingRow(
                title: "工作流规则",
                detail: selectedWorkflow.promptHint,
                value: statusLabel("已识别")
            )
        ])
        return card
    }

    private func makeDictionaryView() -> NSView {
        let page = pageView(title: "个人词库")
        let controls = dictionaryControls()
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        NSLayoutConstraint.deactivate(dictionaryListLayoutConstraints)
        dictionaryListLayoutConstraints.removeAll()
        dictionaryListStack.removeFromSuperview()
        dictionaryListContainer.removeFromSuperview()
        dictionaryListStack.orientation = .vertical
        dictionaryListStack.alignment = .width
        dictionaryListStack.spacing = 8
        dictionaryListStack.translatesAutoresizingMaskIntoConstraints = false
        dictionaryListContainer.translatesAutoresizingMaskIntoConstraints = false
        dictionaryListContainer.addSubview(dictionaryListStack)
        scrollView.documentView = dictionaryListContainer
        dictionaryListLayoutConstraints = [
            dictionaryListContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            dictionaryListContainer.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            dictionaryListStack.leadingAnchor.constraint(equalTo: dictionaryListContainer.leadingAnchor),
            dictionaryListStack.trailingAnchor.constraint(equalTo: dictionaryListContainer.trailingAnchor),
            dictionaryListStack.topAnchor.constraint(equalTo: dictionaryListContainer.topAnchor),
            dictionaryListStack.bottomAnchor.constraint(lessThanOrEqualTo: dictionaryListContainer.bottomAnchor)
        ]
        NSLayoutConstraint.activate(dictionaryListLayoutConstraints)

        [controls, scrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            page.addSubview($0)
        }
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            controls.topAnchor.constraint(equalTo: page.topAnchor, constant: 38),
            controls.heightAnchor.constraint(equalToConstant: Token.tabHeight),

            scrollView.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            scrollView.heightAnchor.constraint(equalToConstant: 190),
            scrollView.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor)
        ])
        refreshDictionary()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return page
    }

    private func dictionaryControls() -> NSView {
        let view = NSView()
        let tabs = segmentedControl(width: 360, height: Token.tabHeight)
        dictionaryFilterButtons.removeAll()
        for filter in DictionaryFilter.allCases {
            let button = segmentButton(title: filter.title, selected: filter == dictionaryFilter, height: Token.tabHeight - 6)
            button.identifier = NSUserInterfaceItemIdentifier(filter.title)
            button.target = self
            button.action = #selector(dictionaryFilterClicked(_:))
            dictionaryFilterButtons[filter] = button
            tabs.addArrangedSubview(button)
        }

        let addButton = button(title: "添加词条", style: .primary, width: 90, height: Token.primaryButtonHeight)
        addButton.target = self
        addButton.action = #selector(addDictionaryTerm)

        [tabs, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabs.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            tabs.widthAnchor.constraint(equalToConstant: 360),
            tabs.heightAnchor.constraint(equalToConstant: Token.tabHeight),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 90),
            addButton.heightAnchor.constraint(equalToConstant: Token.primaryButtonHeight)
        ])
        return view
    }

    private func makePermissionsView() -> NSView {
        let page = pageView(title: "权限")
        let card = cardView(rows: [
            settingRow(
                title: "麦克风",
                detail: "用于录音和语音指令识别。",
                value: permissionValue(label: microphoneStatusLabel, action: #selector(requestMicrophonePermission))
            ),
            settingRow(
                title: "辅助功能",
                detail: "把最终文本写入当前输入框。",
                value: permissionValue(label: accessibilityStatusLabel, action: #selector(requestAccessibilityPermission))
            ),
            settingRow(
                title: "屏幕录制",
                detail: "看屏回复只读取当前屏幕可见内容。",
                value: permissionValue(label: screenRecordingStatusLabel, action: #selector(requestScreenRecordingPermission))
            )
        ])
        placeContent(card, in: page, belowTitleBy: 16)
        return page
    }

    private func pageView(title: String) -> NSView {
        let page = NSView()
        let titleLabel = text(title, size: 18, weight: .semibold, color: Token.text)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            page.widthAnchor.constraint(equalToConstant: Token.pageWidth),
            titleLabel.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: page.topAnchor)
        ])
        return page
    }

    private func placeContent(_ content: NSView, in page: NSView, belowTitleBy spacing: CGFloat) {
        content.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            content.topAnchor.constraint(equalTo: page.topAnchor, constant: 22 + spacing)
        ])
    }

    private func cardView(rows: [NSView]) -> NSView {
        let card = roundedPanel(background: Token.panel, radius: Token.radiusLarge, border: Token.lineStrong)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for (index, row) in rows.enumerated() {
            if index > 0 {
                stack.addArrangedSubview(separator())
            }
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    private func settingRow(title: String, detail: String, value: NSView) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.018).cgColor

        let titleLabel = text(title, size: 13, weight: .semibold, color: Token.text)
        let detailLabel = text(detail, size: 11, weight: .regular, color: Token.muted, lines: 2)
        let labels = NSStackView()
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        labels.addArrangedSubview(titleLabel)
        labels.addArrangedSubview(detailLabel)

        [labels, value].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            labels.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: Token.rowPaddingX),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: value.leadingAnchor, constant: -Token.rowGap),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            value.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -Token.rowPaddingX),
            value.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            value.widthAnchor.constraint(lessThanOrEqualToConstant: Token.rowValueWidth)
        ])
        return row
    }

    private func metricStack(_ metrics: [(String, Int)], highlighted: Bool) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 6
        for metric in metrics {
            stack.addArrangedSubview(metricRow(title: metric.0, value: metric.1, highlighted: highlighted))
        }
        return stack
    }

    private func metricRow(title: String, value: Int, highlighted: Bool) -> NSView {
        let row = NSView()
        let name = text(title, size: 9, weight: .semibold, color: Token.faint)
        let track = MetricBarView(value: value, fillColor: highlighted ? Token.blue : NSColor.white.withAlphaComponent(0.62), animate: highlighted)
        let number = text("\(value)", size: 10, weight: .bold, color: Token.text)
        number.font = .monospacedSystemFont(ofSize: 10, weight: .bold)

        [name, track, number].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 12),
            name.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            name.widthAnchor.constraint(equalToConstant: 38),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            track.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
            track.trailingAnchor.constraint(equalTo: number.leadingAnchor, constant: -8),
            track.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            track.heightAnchor.constraint(equalToConstant: 5),

            number.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            number.widthAnchor.constraint(equalToConstant: 26),
            number.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func segmentedControl(width: CGFloat, height: CGFloat) -> NSStackView {
        let control = NSStackView()
        control.orientation = .horizontal
        control.alignment = .centerY
        control.distribution = .fillEqually
        control.spacing = 3
        control.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        control.wantsLayer = true
        control.layer?.cornerRadius = Token.radiusSmall
        control.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.035).cgColor
        control.layer?.borderColor = Token.lineStrong.cgColor
        control.layer?.borderWidth = 1
        control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            control.widthAnchor.constraint(equalToConstant: width),
            control.heightAnchor.constraint(equalToConstant: height)
        ])
        return control
    }

    private func segmentButton(title: String, selected: Bool, height: CGFloat) -> NSButton {
        let button = StyledButton(title: title, target: nil, action: nil)
        button.setFeedbackColors(
            resting: selected ? Token.selected : .clear,
            hover: selected ? NSColor.white.withAlphaComponent(0.14) : Token.hover,
            active: selected ? Token.primaryActive : Token.active
        )
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.alignment = .center
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.layer?.backgroundColor = selected ? Token.selected.cgColor : NSColor.clear.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: height).isActive = true
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: selected ? Token.text : Token.muted
            ]
        )
        return button
    }

    private enum ButtonStyle {
        case primary
        case secondary
    }

    private func button(title: String, style: ButtonStyle, width: CGFloat, height: CGFloat) -> NSButton {
        let button = StyledButton(title: title, target: nil, action: nil)
        let restingBackground = style == .primary ? Token.primaryFill : Token.field
        let hoverBackground = style == .primary ? Token.primaryHover : NSColor.white.withAlphaComponent(0.075)
        let activeBackground = style == .primary ? Token.primaryActive : Token.active
        button.setFeedbackColors(resting: restingBackground, hover: hoverBackground, active: activeBackground)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.alignment = .center
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.wantsLayer = true
        button.layer?.cornerRadius = Token.radiusSmall
        button.layer?.backgroundColor = restingBackground.cgColor
        button.layer?.borderColor = Token.lineStrong.cgColor
        button.layer?.borderWidth = 1
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: style == .primary ? Token.text : NSColor.white.withAlphaComponent(0.82)
            ]
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
        return button
    }

    private func rewriteStylePopup() -> NSPopUpButton {
        let popup = StyledPopUpButton()
        popup.removeAllItems()
        for style in VoiceRewriteStyle.allCases {
            popup.addItem(withTitle: Self.shortModeTitle(style))
            popup.lastItem?.representedObject = style.rawValue
        }
        if let index = VoiceRewriteStyle.allCases.firstIndex(of: rewriteStyle) {
            popup.selectItem(at: index)
        }
        popup.target = self
        popup.action = #selector(rewriteStylePopupChanged(_:))
        popup.controlSize = .small
        popup.isBordered = false
        popup.wantsLayer = true
        popup.layer?.cornerRadius = Token.radiusSmall
        popup.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.045).cgColor
        popup.layer?.borderColor = Token.lineStrong.cgColor
        popup.layer?.borderWidth = 1
        popup.setFeedbackColors(
            resting: NSColor.white.withAlphaComponent(0.045),
            hover: Token.hover,
            active: Token.active,
            border: Token.lineStrong,
            hoverBorder: Token.hoverBorder
        )
        popup.heightAnchor.constraint(equalToConstant: Token.controlHeight).isActive = true
        return popup
    }

    private func valueText(_ value: String) -> NSTextField {
        let label = text(value, size: 12, weight: .semibold, color: Token.text)
        label.alignment = .right
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func statusLabel(_ value: String) -> NSTextField {
        let label = text(value, size: 12, weight: .bold, color: Token.green)
        label.alignment = .right
        return label
    }

    private func permissionValue(label: NSTextField, action: Selector) -> NSView {
        let view = NSView()
        configureLabel(label)
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.alignment = .right
        label.cell?.alignment = .right
        let openButton = button(title: "打开", style: .secondary, width: 54, height: Token.buttonHeight)
        openButton.target = self
        openButton.action = action
        openButton.identifier = NSUserInterfaceItemIdentifier("permissionButton")
        [label, openButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Token.rowValueWidth),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 72),

            openButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            openButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            openButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])
        return view
    }

    private func separator() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Token.line.cgColor
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func roundedPanel(background: NSColor, radius: CGFloat, border: NSColor?) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.backgroundColor = background.cgColor
        if let border {
            view.layer?.borderColor = border.cgColor
            view.layer?.borderWidth = 1
        }
        return view
    }

    private func text(
        _ value: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor,
        lines: Int = 1
    ) -> NSTextField {
        let label = lines == 1 ? NSTextField(labelWithString: value) : NSTextField(wrappingLabelWithString: value)
        configureLabel(label)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.maximumNumberOfLines = lines
        label.lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        label.cell?.wraps = lines > 1
        label.cell?.isScrollable = false
        return label
    }

    private func configureLabel(_ label: NSTextField) {
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBordered = false
        label.alignment = .left
        label.cell?.alignment = .left
        label.cell?.baseWritingDirection = .leftToRight
        label.lineBreakMode = .byTruncatingTail
    }

    private func routeFallbackClick(at point: NSPoint, in rootView: NSView) -> Bool {
        if let button = interactiveButtons(in: rootView, at: point, rootView: rootView).first?.view {
            guard button.isEnabled, !button.isHidden, button.alphaValue > 0 else { return false }
            button.sendAction(button.action, to: button.target)
            return true
        }
        if let panel = interactivePanels(in: rootView, at: point, rootView: rootView).first?.view {
            panel.onClick?()
            return true
        }
        return false
    }

    private func interactiveButtons(in view: NSView, at point: NSPoint, rootView: NSView) -> [(view: NSButton, area: CGFloat)] {
        var matches: [(view: NSButton, area: CGFloat)] = []
        if let button = view as? NSButton,
           button.isEnabled,
           !button.isHidden,
           button.alphaValue > 0 {
            let frame = button.convert(button.bounds, to: rootView)
            if frame.contains(point) {
                matches.append((button, frame.width * frame.height))
            }
        }
        for subview in view.subviews {
            matches.append(contentsOf: interactiveButtons(in: subview, at: point, rootView: rootView))
        }
        return matches.sorted { $0.area < $1.area }
    }

    private func interactivePanels(in view: NSView, at point: NSPoint, rootView: NSView) -> [(view: ClickablePanelView, area: CGFloat)] {
        var matches: [(view: ClickablePanelView, area: CGFloat)] = []
        if let panel = view as? ClickablePanelView,
           !panel.isHidden,
           panel.alphaValue > 0 {
            let frame = panel.convert(panel.bounds, to: rootView)
            if frame.contains(point) {
                matches.append((panel, frame.width * frame.height))
            }
        }
        for subview in view.subviews {
            matches.append(contentsOf: interactivePanels(in: subview, at: point, rootView: rootView))
        }
        return matches.sorted { $0.area < $1.area }
    }

    private func refreshAll() {
        refreshInput()
        refreshWorkflowIfNeeded()
        refreshDictionary()
        refreshPermissions()
    }

    private func refreshInput() {
        shortcutFieldLabel.stringValue = isRecordingShortcut ? "按下快捷键" : settingsShortcutTitle(shortcut)
        for (language, button) in languageButtons {
            updateSegmentButton(button, selected: language == outputLanguage)
        }
        let canChange = canChangeInputSettings()
        setButtonEnabled("recordShortcut", in: activeContentView, isEnabled: canChange)
        setButtonEnabled("resetShortcut", in: activeContentView, isEnabled: canChange)
        for button in languageButtons.values {
            button.isEnabled = canChange
        }
    }

    private func refreshWorkflowIfNeeded() {
        guard selectedTab == .workflow else { return }
        for (option, button) in workflowButtons {
            updateSegmentButton(button, selected: option == selectedWorkflow)
        }
    }

    @objc private func refreshDictionary() {
        guard selectedTab == .dictionary else { return }
        dictionaryListStack.arrangedSubviews.forEach {
            dictionaryListStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (filter, button) in dictionaryFilterButtons {
            updateSegmentButton(button, selected: filter == dictionaryFilter)
        }

        let dictionary = VoicePersonalDictionaryStore.load()
        let terms = filteredTerms(dictionary.terms.sorted {
            if $0.weight == $1.weight {
                return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
            return $0.weight > $1.weight
        })

        guard !terms.isEmpty else {
            let empty = roundedPanel(background: Token.panel, radius: Token.radiusMedium, border: Token.lineStrong)
            let label = text("暂时没有词条。", size: 11, weight: .semibold, color: Token.muted)
            label.translatesAutoresizingMaskIntoConstraints = false
            empty.addSubview(label)
            NSLayoutConstraint.activate([
                empty.heightAnchor.constraint(equalToConstant: 44),
                label.leadingAnchor.constraint(equalTo: empty.leadingAnchor, constant: 17),
                label.centerYAnchor.constraint(equalTo: empty.centerYAnchor)
            ])
            dictionaryListStack.addArrangedSubview(empty)
            return
        }

        for term in terms {
            dictionaryListStack.addArrangedSubview(dictionaryTermRow(term))
        }
    }

    private func filteredTerms(_ terms: [VoicePersonalDictionaryTerm]) -> [VoicePersonalDictionaryTerm] {
        switch dictionaryFilter {
        case .all:
            return terms
        case .automatic:
            return terms.filter { !isManualTerm($0) }
        case .manual:
            return terms.filter { isManualTerm($0) }
        }
    }

    private func isManualTerm(_ term: VoicePersonalDictionaryTerm) -> Bool {
        term.note?.localizedCaseInsensitiveContains("手动") == true
    }

    private func dictionaryTermRow(_ term: VoicePersonalDictionaryTerm) -> NSView {
        let row = roundedPanel(background: Token.panel, radius: Token.radiusMedium, border: Token.lineStrong)
        let title = text(term.phrase, size: 12, weight: .semibold, color: Token.text)
        let facts = NSStackView()
        facts.orientation = .horizontal
        facts.alignment = .firstBaseline
        facts.distribution = .fill
        facts.spacing = 24
        facts.addArrangedSubview(dictionaryFact(label: "权重", value: "\(term.weight)"))
        facts.addArrangedSubview(dictionaryFact(label: "场景", value: contextDisplay(term.contextWeights)))
        [title, facts].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 44),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 17),
            title.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: facts.leadingAnchor, constant: -16),

            facts.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -17),
            facts.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            facts.widthAnchor.constraint(equalToConstant: 210)
        ])
        return row
    }

    private func dictionaryFact(label: String, value: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 6
        stack.addArrangedSubview(text(label, size: 9, weight: .semibold, color: Token.faint))
        stack.addArrangedSubview(text(value, size: 11, weight: .semibold, color: Token.muted))
        return stack
    }

    private func contextDisplay(_ contextWeights: [String: Int]) -> String {
        guard !contextWeights.isEmpty else { return "全局" }
        let first = contextWeights.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }.first?.key ?? ""
        if first.contains("com.openai.codex") { return "Codex" }
        if first.contains("agent-collaboration") { return "开发协作" }
        if first.hasPrefix("bundle:") {
            return first.replacingOccurrences(of: "bundle:", with: "")
        }
        if first.hasPrefix("workflow:") {
            return first.replacingOccurrences(of: "workflow:", with: "")
        }
        return first
    }

    private func refreshPermissions() {
        let microphoneStatus = MicrophonePermissionService().authorizationStatus()
        setPermissionStatus(
            microphoneStatusLabel,
            allowed: microphoneStatus == .authorized,
            denied: microphoneStatus == .denied || microphoneStatus == .restricted
        )
        setPermissionStatus(
            accessibilityStatusLabel,
            allowed: SystemPermissionRequester.hasAccessibilityPermission,
            denied: false
        )
        setPermissionStatus(
            screenRecordingStatusLabel,
            allowed: SystemPermissionRequester.hasScreenRecordingPermission,
            denied: false
        )
    }

    private func setPermissionStatus(_ label: NSTextField, allowed: Bool, denied: Bool) {
        label.stringValue = allowed ? "已允许" : (denied ? "未允许" : "待授权")
        label.textColor = allowed ? Token.green : Token.muted
        if let container = label.superview,
           let button = container.subviews.compactMap({ $0 as? NSButton }).first {
            button.isHidden = allowed
        }
    }

    private func updateSegmentButton(_ button: NSButton, selected: Bool) {
        if let button = button as? StyledButton {
            button.setFeedbackColors(
                resting: selected ? Token.selected : .clear,
                hover: selected ? NSColor.white.withAlphaComponent(0.14) : Token.hover,
                active: selected ? Token.primaryActive : Token.active
            )
        }
        button.layer?.backgroundColor = selected ? Token.selected.cgColor : NSColor.clear.cgColor
        button.attributedTitle = NSAttributedString(
            string: button.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: selected ? Token.text : Token.muted
            ]
        )
    }

    private func setButtonEnabled(_ identifier: String, in view: NSView?, isEnabled: Bool) {
        guard let view else { return }
        if let button = view as? NSButton, button.identifier?.rawValue == identifier {
            button.isEnabled = isEnabled
            return
        }
        for subview in view.subviews {
            setButtonEnabled(identifier, in: subview, isEnabled: isEnabled)
        }
    }

    private static func shortModeTitle(_ style: VoiceRewriteStyle) -> String {
        switch style {
        case .standard: return "标准模式"
        case .socialExpert: return "社交达人"
        case .amplifiedSpokesperson: return "强化嘴替"
        case .calm: return "冷静模式"
        }
    }

    private func setRewriteStyle(_ style: VoiceRewriteStyle) {
        guard style != rewriteStyle else { return }
        rewriteStyle = style
        onRewriteStyleChanged(style)
        select(tab: selectedTab)
    }

    @objc private func modeCardClicked(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let style = VoiceRewriteStyle(rawValue: rawValue) else {
            return
        }
        setRewriteStyle(style)
    }

    @objc private func outputLanguageButtonClicked(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let language = VoiceOutputLanguage(rawValue: rawValue) else {
            return
        }
        outputLanguage = language
        onOutputLanguageChanged(language)
        select(tab: selectedTab)
    }

    @objc private func rewriteStylePopupChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let style = VoiceRewriteStyle(rawValue: rawValue) else {
            return
        }
        rewriteStyle = style
        onRewriteStyleChanged(style)
        select(tab: selectedTab)
    }

    @objc private func workflowTabClicked(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let option = WorkflowOption.allCases.first(where: { $0.identifier == identifier }) else {
            return
        }
        selectedWorkflow = option
        workflowWasManuallySelected = true
        select(tab: .workflow)
    }

    @objc private func dictionaryFilterClicked(_ sender: NSButton) {
        guard let filter = DictionaryFilter.allCases.first(where: { $0.title == sender.identifier?.rawValue }) else {
            return
        }
        dictionaryFilter = filter
        refreshDictionary()
    }

    @objc private func addDictionaryTerm() {
        showDictionaryTermOverlay()
    }

    private func showDictionaryTermOverlay() {
        guard dictionaryOverlay == nil,
              let contentView = window?.contentView else { return }

        let overlay = NSView()
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let panel = roundedPanel(background: Token.panel, radius: Token.radiusLarge, border: Token.lineStrong)
        panel.translatesAutoresizingMaskIntoConstraints = false

        let title = text("添加词条", size: 16, weight: .semibold, color: Token.text)
        let detail = text("输入需要加入个人词库的专有名词。默认权重为 8，全局生效。", size: 11, weight: .regular, color: Token.muted, lines: 2)
        let input = NSTextField()
        input.cell = CenteredTextFieldCell(textCell: "")
        input.placeholderString = "例如 Typeless"
        input.font = .systemFont(ofSize: 12, weight: .semibold)
        input.textColor = Token.text
        input.backgroundColor = Token.field
        input.drawsBackground = true
        input.isBordered = false
        input.focusRingType = .none
        input.wantsLayer = true
        input.layer?.cornerRadius = Token.radiusSmall
        input.layer?.borderColor = Token.lineStrong.cgColor
        input.layer?.borderWidth = 1

        let cancel = button(title: "取消", style: .secondary, width: Token.buttonMinWidth, height: Token.buttonHeight)
        cancel.target = self
        cancel.action = #selector(cancelDictionaryOverlay)
        let add = button(title: "添加", style: .primary, width: Token.buttonMinWidth, height: Token.inputPrimaryButtonHeight)
        add.target = self
        add.action = #selector(confirmDictionaryOverlay)

        let buttons = NSStackView(views: [cancel, add])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        [title, detail, input, buttons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview($0)
        }
        overlay.addSubview(panel)
        contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            panel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 360),
            panel.heightAnchor.constraint(equalToConstant: 178),

            title.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            title.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18),
            title.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),

            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 7),

            input.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            input.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            input.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 13),
            input.heightAnchor.constraint(equalToConstant: Token.controlHeight),

            buttons.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16)
        ])

        dictionaryOverlay = overlay
        dictionaryTermInput = input
        dictionaryOverlayKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.dictionaryOverlay != nil else { return event }
            if event.keyCode == 53 {
                self.cancelDictionaryOverlay()
                return nil
            }
            if event.keyCode == 36 {
                self.confirmDictionaryOverlay()
                return nil
            }
            return event
        }
        window?.makeFirstResponder(input)
    }

    @objc private func cancelDictionaryOverlay() {
        if let dictionaryOverlayKeyMonitor {
            NSEvent.removeMonitor(dictionaryOverlayKeyMonitor)
        }
        dictionaryOverlayKeyMonitor = nil
        dictionaryOverlay?.removeFromSuperview()
        dictionaryOverlay = nil
        dictionaryTermInput = nil
    }

    @objc private func confirmDictionaryOverlay() {
        let phrase = normalizedManualDictionaryPhrase(dictionaryTermInput?.stringValue ?? "")
        guard !phrase.isEmpty else { return }

        do {
            try VoicePersonalDictionaryStore.upsert(
                VoicePersonalDictionaryTerm(
                    phrase: phrase,
                    weight: 8,
                    note: "手动添加"
                )
            )
            dictionaryFilter = .manual
            cancelDictionaryOverlay()
            refreshDictionary()
        } catch {
            showError("添加失败：\(error.localizedDescription)")
        }
    }

    private func normalizedManualDictionaryPhrase(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let apostropheCount = trimmed.filter { $0 == "'" || $0 == "’" }.count
        guard apostropheCount >= 2 else { return trimmed }

        let collapsed = trimmed
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 中文输入法有时会把英文专名拆成 ne'xv'o'i'c'e 这类形式；只对明显的英文/数字词做清理。
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._- ")
        if !collapsed.isEmpty,
           collapsed.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return collapsed
        }
        return trimmed
    }

    @objc private func beginShortcutRecording() {
        stopShortcutRecording()
        isRecordingShortcut = true
        updateGlobalShortcutSuspension()
        select(tab: selectedTab)
        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .flagsChanged,
               event.keyCode == VoiceShortcut.rightOptionKeyCode,
               event.modifierFlags.contains(.option) {
                self.applyShortcut(.rightOptionKey)
                return nil
            }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.stopShortcutRecording()
                    self.select(tab: self.selectedTab)
                    return nil
                }
                self.applyShortcut(.keyCombo(keyCode: event.keyCode, modifiers: Self.modifiers(from: event.modifierFlags)))
                return nil
            }
            return event
        }
    }

    @objc private func resetShortcut() {
        applyShortcut(.default)
    }

    private func applyShortcut(_ shortcut: VoiceShortcut) {
        self.shortcut = shortcut
        onShortcutChanged(shortcut)
        stopShortcutRecording()
        select(tab: selectedTab)
    }

    private func stopShortcutRecording() {
        if let localShortcutMonitor {
            NSEvent.removeMonitor(localShortcutMonitor)
        }
        localShortcutMonitor = nil
        isRecordingShortcut = false
        updateGlobalShortcutSuspension()
    }

    private func updateGlobalShortcutSuspension() {
        onShortcutRecordingStateChanged(isWindowSuspendingGlobalShortcut || isRecordingShortcut)
    }

    @objc private func requestMicrophonePermission() {
        onRequestMicrophonePermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshPermissions()
        }
    }

    @objc private func requestAccessibilityPermission() {
        onRequestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshPermissions()
        }
    }

    @objc private func requestScreenRecordingPermission() {
        onRequestScreenRecordingPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshPermissions()
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "NexVoice 设置"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func appVersionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.7"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "8"
        return "\(version) (\(build))"
    }

    private func settingsShortcutTitle(_ shortcut: VoiceShortcut) -> String {
        switch shortcut {
        case .rightOptionKey:
            return "Right Alt"
        default:
            return shortcut.displayTitle
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<VoiceShortcutModifier> {
        var modifiers: Set<VoiceShortcutModifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }
}

extension VoiceSettingsWindowController.Tab: CaseIterable {}

private final class SettingsRootView: NSView {
    var fallbackClickHandler: ((NSPoint) -> Bool)?
    private var didReceiveMouseDown = false

    override func mouseDown(with event: NSEvent) {
        didReceiveMouseDown = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if didReceiveMouseDown, fallbackClickHandler?(point) == true {
            didReceiveMouseDown = false
            return
        }
        didReceiveMouseDown = false
        super.mouseUp(with: event)
    }
}

private final class CenteredTextFieldCell: NSTextFieldCell {
    private func verticallyCenteredFrame(_ frame: NSRect) -> NSRect {
        let cellHeight = min(cellSize.height, frame.height)
        let y = frame.origin.y + max(0, (frame.height - cellHeight) / 2)
        return NSRect(x: frame.origin.x, y: y, width: frame.width, height: cellHeight)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        verticallyCenteredFrame(super.drawingRect(forBounds: rect))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: verticallyCenteredFrame(rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: verticallyCenteredFrame(rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

private final class SidebarNavButton: StyledButton {
    private let icon: String
    private let displayTitle: String
    private var normalTitleColor = NSColor.white.withAlphaComponent(0.58)
    private var selectedTitleColor = NSColor.white.withAlphaComponent(0.93)
    private var normalIconColor = NSColor.white.withAlphaComponent(0.38)

    init(icon: String, title: String) {
        self.icon = icon
        self.displayTitle = title
        super.init(frame: .zero)
        self.title = "\(icon)  \(title)"
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .left
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.clear.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        setButtonType(.momentaryChange)
        imagePosition = .noImage
        contentTintColor = .clear
        setTitleColor(normalTitleColor, iconColor: normalIconColor)
        setFeedbackColors(
            resting: .clear,
            hover: NSColor.white.withAlphaComponent(0.045),
            active: NSColor.white.withAlphaComponent(0.13)
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool, iconColor: NSColor, titleColor: NSColor, selectedBackground: NSColor) {
        normalIconColor = iconColor
        normalTitleColor = titleColor
        selectedTitleColor = titleColor
        setTitleColor(titleColor, iconColor: iconColor)
        setFeedbackColors(
            resting: selected ? selectedBackground : .clear,
            hover: selected ? selectedBackground : NSColor.white.withAlphaComponent(0.045),
            active: NSColor.white.withAlphaComponent(0.13)
        )
        layer?.backgroundColor = (selected ? selectedBackground : .clear).cgColor
    }

    private func setTitleColor(_ titleColor: NSColor, iconColor: NSColor) {
        let padding = "   "
        let full = "\(padding)\(icon)  \(displayTitle)"
        let attributed = NSMutableAttributedString(
            string: full,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: titleColor
            ]
        )
        attributed.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: iconColor
            ],
            range: NSRange(location: (padding as NSString).length, length: (icon as NSString).length)
        )
        attributedTitle = attributed
    }
}

private final class MetricBarView: NSView {
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private let targetProgress: CGFloat
    private let shouldAnimate: Bool
    private var didAnimate = false

    init(value: Int, fillColor: NSColor, animate: Bool) {
        targetProgress = max(0, min(1, CGFloat(value) / 100))
        shouldAnimate = animate
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        trackLayer.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        trackLayer.cornerRadius = 2.5
        fillLayer.backgroundColor = fillColor.cgColor
        fillLayer.cornerRadius = 2.5
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        trackLayer.frame = bounds
        let targetWidth = bounds.width * targetProgress
        if shouldAnimate, !didAnimate, window != nil {
            fillLayer.frame = CGRect(x: 0, y: 0, width: 0, height: bounds.height)
            didAnimate = true
            DispatchQueue.main.async { [weak self] in
                self?.animateFill(to: targetWidth)
            }
        } else if !didAnimate {
            fillLayer.frame = CGRect(x: 0, y: 0, width: targetWidth, height: bounds.height)
        }
    }

    private func animateFill(to width: CGFloat) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.42)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        fillLayer.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
    }
}

private class StyledButton: NSButton {
    private var restingBackground = NSColor.clear
    private var hoverBackground: NSColor?
    private var activeBackground = NSColor.white.withAlphaComponent(0.1)
    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false
    private var isPressedInside = false

    func setFeedbackColors(resting: NSColor, hover: NSColor? = nil, active: NSColor) {
        restingBackground = resting
        hoverBackground = hover
        activeBackground = active
        layer?.backgroundColor = (isMouseInside ? (hoverBackground ?? restingBackground) : restingBackground).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        guard isEnabled else { return }
        layer?.backgroundColor = (hoverBackground ?? restingBackground).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        layer?.backgroundColor = restingBackground.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, isEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressedInside = true
        layer?.backgroundColor = activeBackground.cgColor
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let localPoint = convert(event.locationInWindow, from: nil)
        isPressedInside = bounds.contains(localPoint)
        layer?.backgroundColor = (isPressedInside ? activeBackground : restingBackground).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let localPoint = convert(event.locationInWindow, from: nil)
        let shouldSend = isPressedInside && bounds.contains(localPoint)
        isPressedInside = false
        layer?.backgroundColor = (isMouseInside ? (hoverBackground ?? restingBackground) : restingBackground).cgColor
        if shouldSend {
            sendAction(action, to: target)
        }
    }
}

private final class StyledPopUpButton: NSPopUpButton {
    private var restingBackground = NSColor.clear
    private var hoverBackground = NSColor.white.withAlphaComponent(0.09)
    private var activeBackground = NSColor.white.withAlphaComponent(0.14)
    private var normalBorder = NSColor.white.withAlphaComponent(0.065)
    private var hoverBorder = NSColor.white.withAlphaComponent(0.14)
    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false

    init() {
        super.init(frame: .zero, pullsDown: false)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isBordered = false
        wantsLayer = true
    }

    func setFeedbackColors(resting: NSColor, hover: NSColor, active: NSColor, border: NSColor, hoverBorder: NSColor) {
        restingBackground = resting
        hoverBackground = hover
        activeBackground = active
        normalBorder = border
        self.hoverBorder = hoverBorder
        layer?.backgroundColor = (isMouseInside ? hoverBackground : restingBackground).cgColor
        layer?.borderColor = (isMouseInside ? hoverBorder : normalBorder).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        guard isEnabled else { return }
        layer?.backgroundColor = hoverBackground.cgColor
        layer?.borderColor = hoverBorder.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        layer?.backgroundColor = restingBackground.cgColor
        layer?.borderColor = normalBorder.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, isEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        layer?.backgroundColor = activeBackground.cgColor
        super.mouseDown(with: event)
        layer?.backgroundColor = (isMouseInside ? hoverBackground : restingBackground).cgColor
        layer?.borderColor = (isMouseInside ? hoverBorder : normalBorder).cgColor
    }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class ClickablePanelView: NSView {
    var onClick: (() -> Void)?
    private var normalBackground = NSColor.clear
    private var hoverBackground = NSColor.white.withAlphaComponent(0.045)
    private var activeBackground = NSColor.white.withAlphaComponent(0.075)
    private var normalBorder = NSColor.white.withAlphaComponent(0.065)
    private var hoverBorder = NSColor.white.withAlphaComponent(0.12)
    private var trackingArea: NSTrackingArea?
    private var isMouseInside = false

    func setFeedbackColors(normal: NSColor, hover: NSColor, active: NSColor, border: NSColor, hoverBorder: NSColor) {
        normalBackground = normal
        hoverBackground = hover
        activeBackground = active
        normalBorder = border
        self.hoverBorder = hoverBorder
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        normalBackground = layer?.backgroundColor.flatMap { NSColor(cgColor: $0) } ?? .clear
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        layer?.backgroundColor = hoverBackground.cgColor
        layer?.borderColor = hoverBorder.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        layer?.backgroundColor = normalBackground.cgColor
        layer?.borderColor = normalBorder.cgColor
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if let layer {
            layer.backgroundColor = activeBackground.cgColor
        }
    }

    override func mouseUp(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            onClick?()
        }
        layer?.backgroundColor = (isMouseInside ? hoverBackground : normalBackground).cgColor
        layer?.borderColor = (isMouseInside ? hoverBorder : normalBorder).cgColor
    }
}

private extension NSView {
    func firstSuperview<T: NSView>(of type: T.Type) -> T? {
        var view = superview
        while let current = view {
            if let matched = current as? T {
                return matched
            }
            view = current.superview
        }
        return nil
    }
}

private extension ClickablePanelView {
    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
