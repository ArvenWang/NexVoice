import AppKit
import NexVoiceCore
import QuartzCore

@MainActor
final class VoiceCaptionPanelController {
    private let panel: NSPanel
    private let stageView = NSView()
    private let rootView = NexVoicePanelSurfaceView()
    private let stackView = NSStackView()
    private let transcriptScrollView = NSScrollView()
    private let transcriptTextView = NSTextView()
    private let waveformContainer = NSView()
    private let waveformView = VoiceWaveformView()
    private let loadingStackView = NSStackView()
    private let loadingIndicator = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "AI 整理中")
    private var currentPanelSize = VoiceWaveformDisplayPolicy.panelSize
    private var rootWidthConstraint: NSLayoutConstraint?
    private var rootHeightConstraint: NSLayoutConstraint?
    private var textHeightConstraint: NSLayoutConstraint?
    private var waveformHeightConstraint: NSLayoutConstraint?
    private var panelResizeAnimationTask: Task<Void, Never>?
    private var hideWorkItem: DispatchWorkItem?
    private var lastTranscriptText = ""
    private var transcriptRevealTask: Task<Void, Never>?
    private var transcriptRevealText = ""
    private var transcriptRevealPrefixLength = 0
    private var transcriptRevealStartTime = Date()
    private var showsWaveformInTextPanel = true
    private var contextualAnchorRect: CGRect?
    private var isInteractiveContextualResult = false
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: VoiceWaveformDisplayPolicy.stageSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        buildContent()
    }

    func showOverlay() {
        cancelScheduledHide()
        configurePassivePanel()
        let shouldAnimateEntrance = !panel.isVisible
        showRecordingContent()
        waveformView.setActive(true)
        positionOverlay()
        if shouldAnimateEntrance {
            preparePanelEntrance()
        }
        panel.orderFrontRegardless()
        if shouldAnimateEntrance {
            animatePanelEntranceIfNeeded()
        }
    }

    func showLoading(_ message: String, anchorRect: CGRect? = nil) {
        cancelScheduledHide()
        configurePassivePanel(anchorRect: anchorRect)
        loadingLabel.stringValue = message
        loadingLabel.textColor = NSColor.white.withAlphaComponent(0.82)
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimation(nil)
        waveformView.setActive(false)
        waveformView.setAmplitude(0)
        if !panel.isVisible {
            positionOverlay()
            preparePanelEntrance()
            panel.orderFrontRegardless()
            animatePanelEntranceIfNeeded()
        }
        transition(from: stackView, to: loadingStackView)
        updatePanelSize(to: VoiceWaveformDisplayPolicy.loadingPanelSize, animated: true)
    }

    func showStatus(_ message: String, isError: Bool, autoHideDelay: TimeInterval = 1.0) {
        cancelScheduledHide()
        configurePassivePanel()
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        loadingLabel.stringValue = message
        loadingLabel.textColor = isError
            ? NSColor.systemRed.withAlphaComponent(0.9)
            : NSColor.white.withAlphaComponent(0.78)
        waveformView.setActive(false)
        waveformView.setAmplitude(0)
        if !panel.isVisible {
            positionOverlay()
            preparePanelEntrance()
            panel.orderFrontRegardless()
            animatePanelEntranceIfNeeded()
        }
        transition(from: stackView, to: loadingStackView)
        updatePanelSize(to: statusPanelSize(for: message), animated: true)
        scheduleHide(after: autoHideDelay)
    }

    func apply(_ event: VoiceRealtimeEvent) {
        switch event {
        case .sessionStarted:
            setTranscriptText("")
            showActiveWaveform()
        case .partialTranscript(let text, _):
            setTranscriptText(text)
            waveformView.setActive(true)
        case .finalTranscript(let text):
            setTranscriptText(text)
            waveformView.setActive(true)
        case .partialTranslation(let sourceText, let targetText):
            setTranscriptText(targetText.isEmpty ? sourceText : targetText)
            waveformView.setActive(true)
        case .finalTranslation(_, let targetText):
            setTranscriptText(targetText)
            waveformView.setActive(true)
        case .latencyUpdated:
            waveformView.setActive(true)
        case .audioLevelUpdated(let level):
            waveformView.setAmplitude(CGFloat(level))
        case .sessionEnded:
            waveformView.setActive(false)
            scheduleHide(after: VoiceWaveformDisplayPolicy.endedWithoutInsertionHideDelay)
        case .failed:
            hideImmediately()
        }
    }

    func reset() {
        cancelScheduledHide()
        configurePassivePanel()
        loadingIndicator.stopAnimation(nil)
        loadingStackView.isHidden = true
        loadingStackView.alphaValue = 0
        stackView.isHidden = false
        stackView.alphaValue = 1
        rootView.alphaValue = 1
        rootView.layer?.setAffineTransform(.identity)
        panelResizeAnimationTask?.cancel()
        panelResizeAnimationTask = nil
        waveformView.setAmplitude(0)
        waveformView.setActive(false)
        showsWaveformInTextPanel = true
        waveformContainer.isHidden = false
        waveformHeightConstraint?.constant = VoiceWaveformDisplayPolicy.waveformSize.height
        cancelTranscriptReveal()
        setTranscriptText("")
    }

    func showPreparing() {
        reset()
    }

    func hideRecordingOverlay() {
        hideImmediately()
    }

    func showInsertedText(_ text: String) {
        if VoiceWaveformDisplayPolicy.insertedTextHideDelay <= 0 {
            hideImmediately()
        } else {
            scheduleHide(after: VoiceWaveformDisplayPolicy.insertedTextHideDelay)
        }
    }

    func showContextualResult(_ text: String, anchorRect: CGRect? = nil) {
        cancelScheduledHide()
        configureInteractiveContextualResult(anchorRect: anchorRect)
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = false
        waveformView.setActive(false)
        waveformView.setAmplitude(0)
        showsWaveformInTextPanel = false
        waveformContainer.isHidden = true
        waveformHeightConstraint?.constant = 0
        showRecordingContent()
        let shouldAnimateEntrance = !panel.isVisible
        setTranscriptText(text)
        positionOverlay(size: currentPanelSize)
        if shouldAnimateEntrance {
            preparePanelEntrance()
        }
        panel.orderFrontRegardless()
        if shouldAnimateEntrance {
            animatePanelEntranceIfNeeded()
        }
        installOutsideClickMonitor()
    }

    func showOutputFailed(_ message: String) {
        hideImmediately()
    }

    func showPermissionNotice(_ guidance: VoicePermissionGuidance) {
        hideImmediately()
    }

    private func buildContent() {
        rootView.frame = NSRect(origin: .zero, size: VoiceWaveformDisplayPolicy.panelSize)
        rootView.translatesAutoresizingMaskIntoConstraints = false
        rootView.layer?.cornerRadius = VoiceWaveformDisplayPolicy.compactPanelSize.height / 2
        stageView.frame = NSRect(origin: .zero, size: VoiceWaveformDisplayPolicy.stageSize)
        stageView.autoresizingMask = [.width, .height]
        stageView.wantsLayer = true
        stageView.layer?.backgroundColor = NSColor.clear.cgColor

        configureTranscriptView()
        configureWaveformContainer()
        configureLoadingView()
        stackView.alphaValue = 1

        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        stackView.spacing = VoiceWaveformDisplayPolicy.textWaveformSpacing
        stackView.edgeInsets = NSEdgeInsets(
            top: VoiceWaveformDisplayPolicy.topPadding,
            left: VoiceWaveformDisplayPolicy.horizontalPadding,
            bottom: VoiceWaveformDisplayPolicy.bottomPadding,
            right: VoiceWaveformDisplayPolicy.horizontalPadding
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(transcriptScrollView)
        stackView.addArrangedSubview(waveformContainer)

        rootView.addSubview(stackView)
        rootView.addSubview(loadingStackView)
        stageView.addSubview(rootView)
        panel.contentView = stageView

        let width = rootView.widthAnchor.constraint(equalToConstant: VoiceWaveformDisplayPolicy.panelSize.width)
        let height = rootView.heightAnchor.constraint(equalToConstant: VoiceWaveformDisplayPolicy.panelSize.height)
        rootWidthConstraint = width
        rootHeightConstraint = height
        textHeightConstraint = transcriptScrollView.heightAnchor.constraint(equalToConstant: 0)
        waveformHeightConstraint = waveformContainer.heightAnchor.constraint(equalToConstant: VoiceWaveformDisplayPolicy.waveformSize.height)

        NSLayoutConstraint.activate([
            width,
            height,
            textHeightConstraint,
            waveformHeightConstraint,

            rootView.centerXAnchor.constraint(equalTo: stageView.centerXAnchor),
            rootView.bottomAnchor.constraint(equalTo: stageView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            transcriptScrollView.widthAnchor.constraint(equalToConstant: VoiceWaveformDisplayPolicy.textContentWidth),
            waveformContainer.widthAnchor.constraint(equalToConstant: VoiceWaveformDisplayPolicy.waveformSize.width),

            loadingStackView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            loadingStackView.centerYAnchor.constraint(equalTo: rootView.centerYAnchor)
        ].compactMap { $0 })

        updatePanelSize(to: VoiceWaveformDisplayPolicy.panelSize)
    }

    private func configureTranscriptView() {
        transcriptScrollView.translatesAutoresizingMaskIntoConstraints = false
        transcriptScrollView.borderType = .noBorder
        transcriptScrollView.hasVerticalScroller = false
        transcriptScrollView.hasHorizontalScroller = false
        transcriptScrollView.autohidesScrollers = true
        transcriptScrollView.scrollerStyle = .overlay
        transcriptScrollView.scrollerInsets = NSEdgeInsets(
            top: 4,
            left: 0,
            bottom: 4,
            right: VoiceWaveformDisplayPolicy.floatingScrollerRightInset
        )
        transcriptScrollView.drawsBackground = false
        transcriptScrollView.isHidden = true

        transcriptTextView.isEditable = false
        transcriptTextView.isSelectable = false
        transcriptTextView.drawsBackground = false
        applyTranscriptTextInsets(verticalInset: VoiceWaveformDisplayPolicy.transcriptTextInset)
        transcriptTextView.textContainer?.lineFragmentPadding = 0
        transcriptTextView.textContainer?.widthTracksTextView = true
        transcriptTextView.textContainer?.containerSize = NSSize(
            width: VoiceWaveformDisplayPolicy.transcriptLayoutWidth,
            height: .greatestFiniteMagnitude
        )
        transcriptTextView.minSize = NSSize(width: VoiceWaveformDisplayPolicy.textContentWidth, height: 0)
        transcriptTextView.maxSize = NSSize(
            width: VoiceWaveformDisplayPolicy.textContentWidth,
            height: .greatestFiniteMagnitude
        )
        transcriptTextView.isVerticallyResizable = true
        transcriptTextView.isHorizontallyResizable = false
        transcriptTextView.font = .systemFont(ofSize: VoiceWaveformDisplayPolicy.transcriptFontSize, weight: .medium)
        transcriptTextView.textColor = NSColor.white.withAlphaComponent(0.94)
        transcriptScrollView.documentView = transcriptTextView
    }

    private func configureWaveformContainer() {
        waveformContainer.translatesAutoresizingMaskIntoConstraints = false

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformContainer.addSubview(waveformView)

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: waveformContainer.leadingAnchor),
            waveformView.trailingAnchor.constraint(equalTo: waveformContainer.trailingAnchor),
            waveformView.topAnchor.constraint(equalTo: waveformContainer.topAnchor),
            waveformView.bottomAnchor.constraint(equalTo: waveformContainer.bottomAnchor)
        ])
    }

    private func configureLoadingView() {
        loadingStackView.orientation = .horizontal
        loadingStackView.alignment = .centerY
        loadingStackView.distribution = .gravityAreas
        loadingStackView.spacing = 8
        loadingStackView.translatesAutoresizingMaskIntoConstraints = false
        loadingStackView.isHidden = true
        loadingStackView.alphaValue = 0

        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .small
        loadingIndicator.isIndeterminate = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel.font = .systemFont(ofSize: VoiceWaveformDisplayPolicy.transcriptFontSize, weight: .medium)
        loadingLabel.textColor = NSColor.white.withAlphaComponent(0.82)
        loadingLabel.lineBreakMode = .byTruncatingTail

        loadingStackView.addArrangedSubview(loadingIndicator)
        loadingStackView.addArrangedSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingIndicator.widthAnchor.constraint(equalToConstant: 14),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func statusPanelSize(for message: String) -> CGSize {
        let font = NSFont.systemFont(ofSize: VoiceWaveformDisplayPolicy.transcriptFontSize, weight: .medium)
        let measuredWidth = ceil((message as NSString).size(withAttributes: [.font: font]).width)
        let width = min(
            VoiceWaveformDisplayPolicy.expandedPanelWidth,
            max(VoiceWaveformDisplayPolicy.statusPanelSize.width, measuredWidth + 40)
        )
        return CGSize(width: width, height: VoiceWaveformDisplayPolicy.statusPanelSize.height)
    }

    private func setTranscriptText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousText = lastTranscriptText
        let wasEmpty = previousText.isEmpty
        let didChangeText = trimmed != lastTranscriptText
        lastTranscriptText = trimmed

        guard !trimmed.isEmpty else {
            cancelTranscriptReveal()
            transcriptTextView.string = ""
            applyTranscriptTextInsets(verticalInset: VoiceWaveformDisplayPolicy.transcriptTextInset)
            transcriptScrollView.hasVerticalScroller = false
            textHeightConstraint?.constant = 0
            transcriptScrollView.alphaValue = 0
            transcriptScrollView.isHidden = true
            updatePanelSize(to: VoiceWaveformDisplayPolicy.panelSize, animated: true)
            return
        }

        if wasEmpty {
            transcriptScrollView.alphaValue = 0
        }
        transcriptScrollView.isHidden = false

        if didChangeText {
            startTranscriptReveal(text: trimmed, previousText: previousText)
        } else {
            renderTranscript(text: trimmed, revealPrefixLength: trimmed.count, progress: 1)
        }

        let rawTextHeight = rawMeasuredTextHeight(for: trimmed)
        let measuredHeight = rawTextHeight + VoiceWaveformDisplayPolicy.transcriptTextInset * 2
        let maximumTextHeight = showsWaveformInTextPanel
            ? VoiceWaveformDisplayPolicy.maximumTextHeight
            : VoiceWaveformDisplayPolicy.maximumResultTextHeight
        let textHeight = min(measuredHeight, maximumTextHeight)
        transcriptScrollView.hasVerticalScroller = measuredHeight > maximumTextHeight
        let verticalInset = max(
            VoiceWaveformDisplayPolicy.transcriptTextInset,
            floor((textHeight - rawTextHeight) / 2)
        )
        applyTranscriptTextInsets(verticalInset: verticalInset)
        textHeightConstraint?.constant = textHeight
        transcriptTextView.frame = NSRect(
            x: 0,
            y: 0,
            width: VoiceWaveformDisplayPolicy.textContentWidth,
            height: max(textHeight, measuredHeight)
        )
        transcriptTextView.scrollToEndOfDocument(nil)
        let panelHeight = showsWaveformInTextPanel
            ? VoiceWaveformDisplayPolicy.expandedPanelHeight(for: measuredHeight)
            : VoiceWaveformDisplayPolicy.resultPanelHeight(for: measuredHeight)
        updatePanelSize(to: CGSize(
            width: VoiceWaveformDisplayPolicy.expandedPanelWidth,
            height: panelHeight
        ), animated: true)
        revealTranscriptContainerIfNeeded(wasEmpty: wasEmpty)
    }

    private func rawMeasuredTextHeight(for text: String) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: VoiceWaveformDisplayPolicy.transcriptFontSize, weight: .medium),
                .paragraphStyle: paragraphStyle
            ]
        )
        let rect = attributed.boundingRect(
            with: NSSize(
                width: VoiceWaveformDisplayPolicy.transcriptLayoutWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height)
    }

    private func applyTranscriptTextInsets(verticalInset: CGFloat) {
        transcriptTextView.textContainerInset = NSSize(
            width: VoiceWaveformDisplayPolicy.transcriptTextInset,
            height: verticalInset
        )
    }

    private func updatePanelSize(to size: CGSize, animated: Bool = false) {
        let oldSize = currentPanelSize
        guard abs(oldSize.width - size.width) > 0.5 || abs(oldSize.height - size.height) > 0.5 else {
            return
        }
        currentPanelSize = size
        rootView.layer?.cornerRadius = min(18, size.height / 2)
        guard animated, panel.isVisible, !shouldReduceMotion else {
            panelResizeAnimationTask?.cancel()
            panelResizeAnimationTask = nil
            applyRootSize(size)
            return
        }

        animateRootResize(from: oldSize, to: size)
    }

    private func animateRootResize(from oldSize: CGSize, to newSize: CGSize) {
        panelResizeAnimationTask?.cancel()
        panelResizeAnimationTask = nil

        let startTime = CACurrentMediaTime()
        let duration = VoiceWaveformDisplayPolicy.panelTransitionDuration
        panelResizeAnimationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(max(elapsed / duration, 0), 1)
                let eased = easeOutCubic(progress)
                let size = interpolatedSize(from: oldSize, to: newSize, progress: eased)
                self.applyRootSize(size)
                if progress >= 1 {
                    self.panelResizeAnimationTask = nil
                    self.applyRootSize(newSize)
                    return
                }
                try? await Task.sleep(nanoseconds: 8_333_333)
            }
        }
    }

    private func applyRootSize(_ size: CGSize) {
        rootWidthConstraint?.constant = size.width
        rootHeightConstraint?.constant = size.height
        rootView.layer?.cornerRadius = min(18, size.height / 2)
        stageView.layoutSubtreeIfNeeded()
        if contextualAnchorRect != nil {
            positionOverlay(size: size)
        }
        panel.displayIfNeeded()
    }

    private func revealTranscriptContainerIfNeeded(wasEmpty: Bool) {
        guard wasEmpty else { return }
        guard panel.isVisible, !shouldReduceMotion else {
            transcriptScrollView.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = VoiceWaveformDisplayPolicy.contentCrossfadeDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            transcriptScrollView.animator().alphaValue = 1
        }
    }

    private func showActiveWaveform() {
        cancelScheduledHide()
        configurePassivePanel()
        let shouldAnimateEntrance = !panel.isVisible
        showRecordingContent()
        waveformView.setActive(true)
        positionOverlay()
        if shouldAnimateEntrance {
            preparePanelEntrance()
        }
        panel.orderFrontRegardless()
        if shouldAnimateEntrance {
            animatePanelEntranceIfNeeded()
        }
    }

    private func showRecordingContent() {
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = false
        if showsWaveformInTextPanel {
            waveformContainer.isHidden = false
            waveformHeightConstraint?.constant = VoiceWaveformDisplayPolicy.waveformSize.height
        }
        transition(from: loadingStackView, to: stackView)
    }

    private func positionOverlay() {
        positionOverlay(size: currentPanelSize)
    }

    private func positionOverlay(size: CGSize) {
        let frame: NSRect
        if let contextualAnchorRect {
            frame = frameForContextualOverlay(anchorRect: contextualAnchorRect, visualSize: size)
        } else {
            frame = frameForOverlay()
        }
        panel.setFrame(frame, display: true)
    }

    private func frameForOverlay() -> NSRect {
        let size = VoiceWaveformDisplayPolicy.stageSize
        guard let screen = NSScreen.main else {
            return NSRect(origin: .zero, size: size)
        }
        let visibleFrame = screen.visibleFrame
        let x = clamp(
            visibleFrame.midX - size.width / 2,
            min: visibleFrame.minX + VoiceWaveformDisplayPolicy.screenEdgeInset,
            max: visibleFrame.maxX - size.width - VoiceWaveformDisplayPolicy.screenEdgeInset
        )
        let y = visibleFrame.minY + VoiceWaveformDisplayPolicy.bottomOffset
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func frameForContextualOverlay(anchorRect: CGRect, visualSize: CGSize) -> NSRect {
        let stageSize = VoiceWaveformDisplayPolicy.stageSize
        let screen = screen(containing: anchorRect) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            return frameForOverlay()
        }

        let edgeInset = VoiceWaveformDisplayPolicy.screenEdgeInset
        let gap: CGFloat = 8
        let x = clamp(
            anchorRect.midX - stageSize.width / 2,
            min: visibleFrame.minX + edgeInset,
            max: visibleFrame.maxX - stageSize.width - edgeInset
        )
        let rootHeight = min(max(visualSize.height, VoiceWaveformDisplayPolicy.compactPanelSize.height), stageSize.height)
        let preferredRootY = anchorRect.minY - rootHeight - gap
        let resolvedRootY = preferredRootY < visibleFrame.minY + edgeInset
            ? anchorRect.maxY + gap
            : preferredRootY
        let rootY = clamp(
            resolvedRootY,
            min: visibleFrame.minY + edgeInset,
            max: visibleFrame.maxY - rootHeight - edgeInset
        )
        return NSRect(x: x, y: rootY, width: stageSize.width, height: stageSize.height)
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    private func animatePanelResize(to targetFrame: NSRect, duration: TimeInterval) {
        panelResizeAnimationTask?.cancel()

        let sourceFrame = panel.frame
        guard abs(sourceFrame.width - targetFrame.width) > 0.5
            || abs(sourceFrame.height - targetFrame.height) > 0.5
            || abs(sourceFrame.minX - targetFrame.minX) > 0.5
            || abs(sourceFrame.minY - targetFrame.minY) > 0.5 else {
            panel.setFrame(targetFrame, display: true)
            return
        }

        let startTime = CACurrentMediaTime()
        panelResizeAnimationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(max(elapsed / duration, 0), 1)
                let frame = interpolatedRect(
                    from: sourceFrame,
                    to: targetFrame,
                    progress: easeOutCubic(progress)
                )
                self.panel.setFrame(frame, display: true)
                self.panel.contentView?.layoutSubtreeIfNeeded()
                self.panel.displayIfNeeded()

                if progress >= 1 {
                    self.panelResizeAnimationTask = nil
                    self.panel.setFrame(targetFrame, display: true)
                    self.panel.displayIfNeeded()
                    return
                }
                try? await Task.sleep(nanoseconds: 8_333_333)
            }
        }
    }

    private func configurePassivePanel(anchorRect: CGRect? = nil) {
        isInteractiveContextualResult = false
        contextualAnchorRect = anchorRect
        panel.ignoresMouseEvents = true
        transcriptTextView.isSelectable = false
        removeOutsideClickMonitor()
    }

    private func configureInteractiveContextualResult(anchorRect: CGRect?) {
        isInteractiveContextualResult = true
        contextualAnchorRect = anchorRect
        panel.ignoresMouseEvents = false
        transcriptTextView.isSelectable = true
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideContextualResultIfMouseIsOutside()
            }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.hideContextualResultIfMouseIsOutside()
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickGlobalMonitor {
            NSEvent.removeMonitor(outsideClickGlobalMonitor)
            self.outsideClickGlobalMonitor = nil
        }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
    }

    private func hideContextualResultIfMouseIsOutside() {
        guard isInteractiveContextualResult, panel.isVisible else { return }
        let mouseLocation = NSEvent.mouseLocation
        if !rootFrameInScreen().contains(mouseLocation) {
            hideImmediately()
        }
    }

    private func rootFrameInScreen() -> CGRect {
        stageView.layoutSubtreeIfNeeded()
        let rootFrameInWindow = rootView.convert(rootView.bounds, to: nil)
        return panel.convertToScreen(rootFrameInWindow)
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelScheduledHide()
        guard delay > 0 else {
            hideImmediately()
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.hideImmediately()
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func hideImmediately() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        configurePassivePanel()
        waveformView.setActive(false)
        waveformView.setAmplitude(0)
        loadingIndicator.stopAnimation(nil)
        panelResizeAnimationTask?.cancel()
        panelResizeAnimationTask = nil
        cancelTranscriptReveal()
        loadingStackView.isHidden = true
        loadingStackView.alphaValue = 0
        stackView.isHidden = false
        stackView.alphaValue = 1
        setTranscriptText("")
        guard panel.isVisible, !shouldReduceMotion else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = VoiceWaveformDisplayPolicy.contentCrossfadeDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            rootView.animator().alphaValue = 0
        } completionHandler: { [weak panel, weak rootView] in
            Task { @MainActor in
                panel?.orderOut(nil)
                rootView?.alphaValue = 1
            }
        }
    }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func transition(from outgoing: NSView, to incoming: NSView) {
        guard outgoing !== incoming else { return }
        incoming.isHidden = false
        guard !shouldReduceMotion else {
            outgoing.isHidden = true
            outgoing.alphaValue = 0
            incoming.alphaValue = 1
            return
        }

        incoming.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = VoiceWaveformDisplayPolicy.contentCrossfadeDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            outgoing.animator().alphaValue = 0
            incoming.animator().alphaValue = 1
        } completionHandler: { [weak outgoing] in
            Task { @MainActor in
                outgoing?.isHidden = true
            }
        }
    }

    private func preparePanelEntrance() {
        guard !shouldReduceMotion else {
            rootView.alphaValue = 1
            rootView.layer?.setAffineTransform(.identity)
            return
        }
        rootView.alphaValue = 0
        rootView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.96, y: 0.96))
    }

    private func animatePanelEntranceIfNeeded() {
        guard !shouldReduceMotion else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = VoiceWaveformDisplayPolicy.panelRevealDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            rootView.animator().alphaValue = 1
            rootView.layer?.setAffineTransform(.identity)
        }
    }

    private func startTranscriptReveal(text: String, previousText: String) {
        cancelTranscriptReveal()
        let prefixLength = commonPrefixLength(previousText, text)
        transcriptRevealText = text
        transcriptRevealPrefixLength = prefixLength
        transcriptRevealStartTime = Date()

        guard panel.isVisible, !shouldReduceMotion, prefixLength < text.count else {
            renderTranscript(text: text, revealPrefixLength: text.count, progress: 1)
            return
        }

        renderTranscript(text: text, revealPrefixLength: prefixLength, progress: 0)
        transcriptRevealTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }
                let elapsed = Date().timeIntervalSince(self.transcriptRevealStartTime)
                let progress = CGFloat(min(1, elapsed / VoiceWaveformDisplayPolicy.textFadeDuration))
                self.renderTranscript(
                    text: self.transcriptRevealText,
                    revealPrefixLength: self.transcriptRevealPrefixLength,
                    progress: progress
                )
                if progress >= 1 {
                    self.transcriptRevealTask = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    private func renderTranscript(text: String, revealPrefixLength: Int, progress: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2

        let resolvedProgress = max(0, min(1, progress))
        let suffixAlpha = 0.34 + 0.6 * resolvedProgress
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: VoiceWaveformDisplayPolicy.transcriptFontSize, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
        )

        let safePrefixLength = max(0, min(revealPrefixLength, text.count))
        if safePrefixLength < text.count {
            attributed.addAttribute(
                .foregroundColor,
                value: NSColor.white.withAlphaComponent(suffixAlpha),
                range: NSRange(location: safePrefixLength, length: text.count - safePrefixLength)
            )
        }
        transcriptTextView.textStorage?.setAttributedString(attributed)
    }

    private func commonPrefixLength(_ oldText: String, _ newText: String) -> Int {
        var count = 0
        var oldIndex = oldText.startIndex
        var newIndex = newText.startIndex
        while oldIndex < oldText.endIndex, newIndex < newText.endIndex {
            guard oldText[oldIndex] == newText[newIndex] else { break }
            count += 1
            oldIndex = oldText.index(after: oldIndex)
            newIndex = newText.index(after: newIndex)
        }
        return count
    }

    private func cancelTranscriptReveal() {
        transcriptRevealTask?.cancel()
        transcriptRevealTask = nil
    }
}

private final class VoiceWaveformView: NSView {
    private var isActive = false
    private var amplitude: CGFloat = 0
    private var phase: CGFloat = 0
    private var animationTimer: Timer?
    private var levelSmoother = VoiceAudioLevelSmoother()

    override var acceptsFirstResponder: Bool { false }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if active {
            startAnimation()
        } else {
            levelSmoother.reset()
            stopAnimation()
        }
        needsDisplay = true
    }

    func setAmplitude(_ value: CGFloat) {
        amplitude = CGFloat(levelSmoother.process(rawLevel: Double(value)))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let tint = NSColor(calibratedWhite: 0.94, alpha: isActive ? 0.96 : 0.36)
        tint.setFill()

        for rect in VoiceWaveformDisplayPolicy.waveBarRects(
            in: bounds,
            amplitude: amplitude,
            phase: phase,
            isActive: isActive
        ) {
            NSBezierPath(
                roundedRect: rect,
                xRadius: rect.width / 2,
                yRadius: rect.width / 2
            ).fill()
        }
    }

    private func startAnimation() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.amplitude > 0 {
                    self.phase += 0.12
                    self.amplitude = max(0, self.amplitude * 0.96)
                } else {
                    self.phase = 0
                }
                self.needsDisplay = true
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        phase = 0
        needsDisplay = true
    }
}

private final class NexVoicePanelSurfaceView: NSView {
    private let blurView = NSVisualEffectView()
    private let tintView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    func refreshAppearance() {
        blurView.material = .hudWindow
        tintView.layer?.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 0.84).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.state = .active
        blurView.blendingMode = .behindWindow
        blurView.wantsLayer = true

        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true

        addSubview(blurView)
        addSubview(tintView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintView.topAnchor.constraint(equalTo: topAnchor),
            tintView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        refreshAppearance()
    }
}

private func interpolatedRect(from source: NSRect, to target: NSRect, progress: CGFloat) -> NSRect {
    NSRect(
        x: source.minX + (target.minX - source.minX) * progress,
        y: source.minY + (target.minY - source.minY) * progress,
        width: source.width + (target.width - source.width) * progress,
        height: source.height + (target.height - source.height) * progress
    )
}

private func interpolatedSize(from source: CGSize, to target: CGSize, progress: CGFloat) -> CGSize {
    CGSize(
        width: source.width + (target.width - source.width) * progress,
        height: source.height + (target.height - source.height) * progress
    )
}

private func easeOutCubic(_ progress: CGFloat) -> CGFloat {
    let t = clamp(progress, min: 0, max: 1)
    return 1 - pow(1 - t, 3)
}

private func clamp(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
    Swift.max(lowerBound, Swift.min(upperBound, value))
}
