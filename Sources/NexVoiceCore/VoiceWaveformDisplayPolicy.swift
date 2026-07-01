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
        let voiceInput = clamp(amplitude, min: 0, max: 1)
        // 低音量阶段必须压住亮度，把主要对比留给正常说话时的中心爆亮。
        let voiceLevel = voiceResponseLevel(for: voiceInput)
        let responseLevel = pow(voiceLevel, 0.58)

        return (0..<(gridColumnCount * gridRowCount)).map { index in
            let column = index % gridColumnCount
            let row = index / gridColumnCount
            let columnPosition = CGFloat(column)
            let rowPosition = CGFloat(row)
            let horizontalDistance = abs(columnPosition - centerColumn) / max(centerColumn, 1)
            let verticalDistance = abs(rowPosition - centerRow) / max(centerRow, 1)

            let seedA = seededNoise(column: column, row: row)
            let seedB = seededNoise(column: row + 31, row: column + 17)
            let seedC = seededNoise(column: column + 53, row: row + 89)
            let rowWeight = 1 - verticalDistance * 0.52
            let spindleWidth = 0.18 + rowWeight * 0.58
            let spindle = exp(-pow(horizontalDistance / max(spindleWidth, 0.12), 2.35))
                * rowWeight
            let expandedSpindle = pow(spindle, 1.25 - responseLevel * 0.45)
            let centerCore = exp(-pow(horizontalDistance / 0.18, 2.1))
                * (0.55 + rowWeight * 0.45)

            let noiseA = normalizedSine(phase * (0.90 + seedA * 2.60) + seedA * .pi * 2)
            let noiseB = normalizedSine(phase * (1.85 + seedB * 2.40) + seedB * .pi * 2)
            let noiseC = normalizedSine(phase * (3.10 + seedC * 2.10) + seedC * .pi * 2)
            let noise = clamp(noiseA * 0.36 + noiseB * 0.34 + noiseC * 0.30, min: 0, max: 1)
            let voiceWidth = 0.22 + responseLevel * 0.34
            let sparseNoise = smoothstep(
                edge0: 0.61 - responseLevel * 0.31 - spindle * 0.15 + horizontalDistance * 0.10,
                edge1: 0.96,
                value: noise
            )
            let ambientGrain = smoothstep(
                edge0: 0.28,
                edge1: 0.74,
                value: seedC + seedB * 0.16 + (1 - horizontalDistance) * 0.10 + rowWeight * 0.06
            )
            let ambientEdge = 0.70 + (1 - horizontalDistance) * 0.20 + rowWeight * 0.10
            let ambientPresence = ambientEdge * (0.08 + ambientGrain * 0.68 + noise * 0.24)
            let ambientLevel = isActive
                ? 0.075 + smoothstep(edge0: 0.04, edge1: 0.22, value: voiceInput) * 0.040
                : 0
            let ambientNoise = ambientPresence
                * ambientLevel
                * (1 - responseLevel * 0.78)
            let centerEnergy = centerCore
                * responseLevel
                * (0.40 + noise * 1.14)
            let spindleEnergy = expandedSpindle
                * responseLevel
                * sparseNoise
                * (0.24 + voiceWidth + noise * 0.84)
            let edgeSparkle = sparseNoise
                * responseLevel
                * (1 - centerCore)
                * 0.10
                * (0.35 + noise * 0.65)
            let intensity = clamp(
                ambientNoise + centerEnergy + spindleEnergy + edgeSparkle,
                min: 0,
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

    public static func voiceMotionLevel(for amplitude: CGFloat) -> CGFloat {
        smoothstep(edge0: 0.24, edge1: 0.62, value: clamp(amplitude, min: 0, max: 1))
    }

    public static func voiceResponseLevel(for amplitude: CGFloat) -> CGFloat {
        smoothstep(edge0: 0.26, edge1: 0.62, value: clamp(amplitude, min: 0, max: 1))
    }

    public static func phaseIncrement(for amplitude: CGFloat) -> CGFloat {
        let level = voiceMotionLevel(for: amplitude)
        return 0.075 + level * (0.030 + min(0.27, clamp(amplitude, min: 0, max: 1) * 0.30))
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

private func smoothstep(edge0: CGFloat, edge1: CGFloat, value: CGFloat) -> CGFloat {
    guard edge0 != edge1 else { return value >= edge1 ? 1 : 0 }
    let x = clamp((value - edge0) / (edge1 - edge0), min: 0, max: 1)
    return x * x * (3 - 2 * x)
}

private func seededNoise(column: Int, row: Int) -> CGFloat {
    let mixed = (column &* 73_856_093) ^ (row &* 19_349_663)
    let positive = abs(mixed % 10_000)
    return CGFloat(positive) / 10_000
}
