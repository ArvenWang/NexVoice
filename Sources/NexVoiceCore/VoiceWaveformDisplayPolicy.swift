import CoreGraphics
import Foundation

public enum VoiceWaveformDisplayPolicy {
    public static let waveformSize = CGSize(width: 236, height: 28)
    public static let compactPanelSize = CGSize(width: 264, height: 56)
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
    public static let contextualResultActionHeight: CGFloat = 22
    public static let topPadding: CGFloat = horizontalPadding
    public static let textWaveformSpacing: CGFloat = 8
    public static let bottomPadding: CGFloat = horizontalPadding
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
    public static let gridColumnCount = 44
    public static let gridRowCount = 5
    public static let textContentWidth = expandedPanelWidth - horizontalPadding * 2
    public static let transcriptLayoutWidth = textContentWidth
        - transcriptTextInset * 2
        - floatingScrollerGutter

    public static var maximumTextHeight: CGFloat {
        maximumPanelHeight - topPadding - textWaveformSpacing - waveformSize.height - bottomPadding
    }

    public static var maximumResultTextHeight: CGFloat {
        maximumResultPanelHeight
            - topPadding
            - textWaveformSpacing
            - contextualResultActionHeight
            - bottomPadding
    }

    public static func expandedPanelHeight(for measuredTextHeight: CGFloat) -> CGFloat {
        let textHeight = clamp(measuredTextHeight, min: 28, max: maximumTextHeight)
        return topPadding + textHeight + textWaveformSpacing + waveformSize.height + bottomPadding
    }

    public static func resultPanelHeight(for measuredTextHeight: CGFloat) -> CGFloat {
        let textHeight = clamp(measuredTextHeight, min: 28, max: maximumResultTextHeight)
        return topPadding
            + textHeight
            + textWaveformSpacing
            + contextualResultActionHeight
            + bottomPadding
    }

    public static func waveformGridCells(
        in bounds: CGRect,
        amplitude: CGFloat,
        phase: CGFloat,
        isActive: Bool
    ) -> [VoiceWaveformGridCell] {
        let dotSize: CGFloat = 3.2
        let dotSpacing: CGFloat = 1.8
        let totalWidth = CGFloat(gridColumnCount) * dotSize + CGFloat(gridColumnCount - 1) * dotSpacing
        let totalHeight = CGFloat(gridRowCount) * dotSize + CGFloat(gridRowCount - 1) * dotSpacing
        let startX = bounds.midX - totalWidth / 2
        let startY = bounds.midY - totalHeight / 2
        let centerColumn = CGFloat(gridColumnCount - 1) / 2
        let centerRow = CGFloat(gridRowCount - 1) / 2
        let visualAmplitude = pow(clamp(amplitude, min: 0, max: 1), 0.62)

        return (0..<(gridColumnCount * gridRowCount)).map { index in
            let column = index % gridColumnCount
            let row = index / gridColumnCount
            let columnPosition = CGFloat(column)
            let rowPosition = CGFloat(row)
            let horizontalDistance = abs(columnPosition - centerColumn) / max(centerColumn, 1)
            let verticalDistance = abs(rowPosition - centerRow) / max(centerRow, 1)

            let centerGlow = exp(-pow(horizontalDistance / 0.34, 2.15))
            let rowFalloff = 1 - verticalDistance * 0.30
            let seedA = seededNoise(column: column, row: row)
            let seedB = seededNoise(column: row + 31, row: column + 17)
            let seedC = seededNoise(column: column + 53, row: row + 89)
            let noiseA = normalizedSine(phase * (0.75 + seedA * 1.85) + seedA * .pi * 2)
            let noiseB = normalizedSine(phase * (1.45 + seedB * 2.10) + seedB * .pi * 2)
            let noiseC = normalizedSine(phase * (2.65 + seedC * 1.35) + seedC * .pi * 2)
            let noise = noiseA * 0.44 + noiseB * 0.36 + noiseC * 0.20
            let baseEnergy = (isActive ? 0.060 : 0.040)
                + noise * (isActive ? 0.055 : 0.020)
            let centerEnergy = centerGlow
                * (0.060 + visualAmplitude * 0.760)
                * (0.70 + noise * 0.62)
            let sparkleEnergy = pow(noise, 5.0)
                * (0.030 + visualAmplitude * 0.145)
                * (0.36 + centerGlow * 0.64)
            let intensity = clamp(
                (baseEnergy + centerEnergy + sparkleEnergy) * rowFalloff,
                min: isActive ? 0.045 : 0.030,
                max: 1
            )
            let x = startX + columnPosition * (dotSize + dotSpacing)
            let y = startY + rowPosition * (dotSize + dotSpacing)
            return VoiceWaveformGridCell(
                rect: CGRect(x: x, y: y, width: dotSize, height: dotSize),
                intensity: intensity,
                distanceFromCenter: horizontalDistance
            )
        }
    }
}

public struct VoiceWaveformGridCell: Equatable {
    public let rect: CGRect
    public let intensity: CGFloat
    public let distanceFromCenter: CGFloat
}

private func clamp(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
    Swift.max(lowerBound, Swift.min(upperBound, value))
}

private func normalizedSine(_ value: CGFloat) -> CGFloat {
    (sin(value) + 1) / 2
}

private func seededNoise(column: Int, row: Int) -> CGFloat {
    let mixed = (column &* 73_856_093) ^ (row &* 19_349_663)
    let positive = abs(mixed % 10_000)
    return CGFloat(positive) / 10_000
}
