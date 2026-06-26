import AppKit
import QuartzCore

@MainActor
final class OCRRegionOverlayController {
    private let panel: NSPanel
    private let highlightView = OCRRegionHighlightView()
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: .zero,
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
        panel.contentView = highlightView
    }

    func show(region: CGRect, autoHideAfter delay: TimeInterval? = nil) {
        guard region.width > 4, region.height > 4 else { return }
        hideWorkItem?.cancel()
        let paddedRegion = region.insetBy(dx: -6, dy: -6)
        panel.setFrame(paddedRegion, display: true)
        highlightView.frame = NSRect(origin: .zero, size: paddedRegion.size)
        highlightView.needsDisplay = true
        panel.orderFrontRegardless()

        if let delay {
            let workItem = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel.orderOut(nil)
    }
}

private final class OCRRegionHighlightView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)

        NSColor.systemBlue.withAlphaComponent(0.10).setFill()
        path.fill()

        NSColor.systemBlue.withAlphaComponent(0.88).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
