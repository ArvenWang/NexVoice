import CoreGraphics
import Foundation

public enum VoiceWaveformDisplayPolicy {
    public static let panelSize = CGSize(width: 176, height: 52)
    public static let bottomOffset: CGFloat = 34
    public static let insertedTextHideDelay: TimeInterval = 0
    public static let endedWithoutInsertionHideDelay: TimeInterval = 0
    public static let wavePointCount = 21

    public static func waveBarRects(
        in bounds: CGRect,
        amplitude: CGFloat,
        phase: CGFloat,
        isActive: Bool
    ) -> [CGRect] {
        let dotWidth: CGFloat = 3
        let minDotHeight: CGFloat = 4
        let maxDotHeight: CGFloat = 32
        let dotSpacing: CGFloat = 3
        let totalWidth = CGFloat(wavePointCount) * dotWidth + CGFloat(wavePointCount - 1) * dotSpacing
        let startX = bounds.midX - totalWidth / 2
        let visualAmplitude = pow(clamp(amplitude, min: 0, max: 1), 0.55)
        let activeLevel = isActive ? visualAmplitude : 0

        return (0..<wavePointCount).map { index in
            let progress = CGFloat(index) / CGFloat(max(1, wavePointCount - 1))
            let distanceFromCenter = abs(progress - 0.5) * 2
            let envelope = 0.28 + 0.72 * pow(max(0, cos(distanceFromCenter * .pi / 2)), 1.35)
            let motion = activeLevel > 0
                ? 0.82 + 0.18 * sin(phase + CGFloat(index) * 0.64)
                : 0
            let shapedLevel = clamp(activeLevel * envelope * motion, min: 0, max: 1)
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
