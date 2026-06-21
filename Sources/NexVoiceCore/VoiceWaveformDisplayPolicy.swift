import CoreGraphics
import Foundation

public enum VoiceWaveformDisplayPolicy {
    public static let waveformSize = CGSize(width: 64, height: 28)
    public static let compactPanelSize = CGSize(width: 92, height: 44)
    public static let loadingPanelSize = CGSize(width: 156, height: 44)
    public static let statusPanelSize = CGSize(width: 188, height: 44)
    public static let expandedPanelWidth: CGFloat = 420
    public static let maximumPanelHeight: CGFloat = 180
    public static let maximumResultPanelHeight: CGFloat = 300
    public static let stageSize = CGSize(width: expandedPanelWidth, height: maximumResultPanelHeight)
    public static let horizontalPadding: CGFloat = 14
    public static let transcriptTextInset: CGFloat = 6
    public static let floatingScrollerGutter: CGFloat = 24
    public static let floatingScrollerRightInset: CGFloat = 8
    public static let topPadding: CGFloat = 8
    public static let textWaveformSpacing: CGFloat = 8
    public static let bottomPadding: CGFloat = 8
    public static let transcriptFontSize: CGFloat = 13
    public static let panelSize = compactPanelSize
    public static let bottomOffset: CGFloat = 8
    public static let screenEdgeInset: CGFloat = 8
    public static let insertedTextHideDelay: TimeInterval = 0
    public static let endedWithoutInsertionHideDelay: TimeInterval = 0
    public static let panelTransitionDuration: TimeInterval = 0.24
    public static let panelRevealDuration: TimeInterval = 0.30
    public static let contentCrossfadeDuration: TimeInterval = 0.18
    public static let textFadeDuration: TimeInterval = 0.2
    public static let wavePointCount = 5
    public static let textContentWidth = expandedPanelWidth - horizontalPadding * 2
    public static let transcriptLayoutWidth = textContentWidth
        - transcriptTextInset * 2
        - floatingScrollerGutter

    public static var maximumTextHeight: CGFloat {
        maximumPanelHeight - topPadding - textWaveformSpacing - waveformSize.height - bottomPadding
    }

    public static var maximumResultTextHeight: CGFloat {
        maximumResultPanelHeight - topPadding - bottomPadding
    }

    public static func expandedPanelHeight(for measuredTextHeight: CGFloat) -> CGFloat {
        let textHeight = clamp(measuredTextHeight, min: 28, max: maximumTextHeight)
        return topPadding + textHeight + textWaveformSpacing + waveformSize.height + bottomPadding
    }

    public static func resultPanelHeight(for measuredTextHeight: CGFloat) -> CGFloat {
        let textHeight = clamp(measuredTextHeight, min: 28, max: maximumResultTextHeight)
        return topPadding + textHeight + bottomPadding
    }

    public static func waveBarRects(
        in bounds: CGRect,
        amplitude: CGFloat,
        phase: CGFloat,
        isActive: Bool
    ) -> [CGRect] {
        let dotWidth: CGFloat = 5
        let minDotHeight: CGFloat = 4
        let maxDotHeight: CGFloat = 18
        let dotSpacing: CGFloat = 3
        let totalWidth = CGFloat(wavePointCount) * dotWidth + CGFloat(wavePointCount - 1) * dotSpacing
        let startX = bounds.midX - totalWidth / 2
        let visualAmplitude = pow(clamp(amplitude, min: 0, max: 1), 0.55)
        let activeLevel = isActive ? max(visualAmplitude, 0.14) : 0.06

        return (0..<wavePointCount).map { index in
            let wave = (sin(phase + CGFloat(index) * 0.78) + 1) / 2
            let shapedLevel = clamp(activeLevel * (0.46 + wave * 0.78), min: 0, max: 1)
            let dotHeight = minDotHeight + (maxDotHeight - minDotHeight) * shapedLevel
            let centerX = startX
                + dotWidth / 2
                + CGFloat(index) * (dotWidth + dotSpacing)
            return CGRect(
                x: centerX - dotWidth / 2,
                y: bounds.midY - dotHeight / 2,
                width: dotWidth,
                height: dotHeight
            )
        }
    }
}

private func clamp(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
    Swift.max(lowerBound, Swift.min(upperBound, value))
}
