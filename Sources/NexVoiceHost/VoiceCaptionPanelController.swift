import AppKit
import NexVoiceCore

@MainActor
final class VoiceCaptionPanelController {
    private let panel: NSPanel
    private let waveformView = VoiceWaveformView()
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: VoiceWaveformDisplayPolicy.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        buildContent()
    }

    func showOverlay(language: SpeechRecognitionLanguage, shortcut: VoiceShortcut) {
        cancelScheduledHide()
        waveformView.setActive(true)
        positionOverlay()
        panel.orderFrontRegardless()
    }

    func apply(_ event: VoiceRealtimeEvent) {
        switch event {
        case .sessionStarted:
            showActiveWaveform()
        case .partialTranscript, .finalTranscript, .partialTranslation, .finalTranslation, .latencyUpdated:
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

    func reset(language: SpeechRecognitionLanguage, shortcut: VoiceShortcut) {
        cancelScheduledHide()
        waveformView.setAmplitude(0)
        waveformView.setActive(false)
    }

    func showPreparing(language: SpeechRecognitionLanguage, shortcut: VoiceShortcut) {
        reset(language: language, shortcut: shortcut)
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

    func showOutputFailed(_ message: String) {
        hideImmediately()
    }

    func showPermissionNotice(_ guidance: VoicePermissionGuidance) {
        hideImmediately()
    }

    private func buildContent() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        root.frame = NSRect(origin: .zero, size: VoiceWaveformDisplayPolicy.panelSize)
        root.autoresizingMask = [.width, .height]
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.cornerRadius = VoiceWaveformDisplayPolicy.panelSize.height / 2
        root.layer?.cornerCurve = .continuous
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor(
            calibratedRed: 0.095,
            green: 0.092,
            blue: 0.112,
            alpha: 0.92
        ).cgColor
        root.layer?.borderWidth = 0.5
        root.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(waveformView)
        panel.contentView = root

        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            waveformView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            waveformView.topAnchor.constraint(equalTo: root.topAnchor),
            waveformView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    private func showActiveWaveform() {
        cancelScheduledHide()
        waveformView.setActive(true)
        positionOverlay()
        panel.orderFrontRegardless()
    }

    private func positionOverlay() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let size = VoiceWaveformDisplayPolicy.panelSize
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.minY + VoiceWaveformDisplayPolicy.bottomOffset
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
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
        waveformView.setActive(false)
        waveformView.setAmplitude(0)
        panel.orderOut(nil)
    }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
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
