import CoreGraphics
import Testing
@testable import NexVoiceCore

@Test func waveformDisplayPolicyKeepsPanelCompact() {
    #expect(VoiceWaveformDisplayPolicy.waveformSize == CGSize(width: 236, height: 28))
    #expect(VoiceWaveformDisplayPolicy.compactPanelSize == CGSize(width: 264, height: 56))
    #expect(VoiceWaveformDisplayPolicy.loadingPanelSize == CGSize(width: 156, height: 44))
    #expect(VoiceWaveformDisplayPolicy.statusPanelSize == CGSize(width: 188, height: 44))
    #expect(VoiceWaveformDisplayPolicy.stageSize == CGSize(width: 420, height: 300))
    #expect(VoiceWaveformDisplayPolicy.panelSize == CGSize(width: 264, height: 56))
    #expect(VoiceWaveformDisplayPolicy.bottomOffset == 8)
    #expect(VoiceWaveformDisplayPolicy.screenEdgeInset == 8)
    #expect(VoiceWaveformDisplayPolicy.topPadding == VoiceWaveformDisplayPolicy.horizontalPadding)
    #expect(VoiceWaveformDisplayPolicy.bottomPadding == VoiceWaveformDisplayPolicy.horizontalPadding)
    #expect(
        VoiceWaveformDisplayPolicy.compactPanelSize.height
            == VoiceWaveformDisplayPolicy.topPadding
                + VoiceWaveformDisplayPolicy.waveformSize.height
                + VoiceWaveformDisplayPolicy.bottomPadding
    )
}

@Test func waveformDisplayPolicyGrowsAndCapsTextAreaHeight() {
    #expect(VoiceWaveformDisplayPolicy.expandedPanelWidth == 420)
    #expect(VoiceWaveformDisplayPolicy.expandedPanelHeight(for: 12) == 92)
    #expect(VoiceWaveformDisplayPolicy.expandedPanelHeight(for: 90) == 154)
    #expect(VoiceWaveformDisplayPolicy.expandedPanelHeight(for: 400) == VoiceWaveformDisplayPolicy.maximumPanelHeight)
}

@Test func waveformDisplayPolicyGivesContextualResultsMoreRoom() {
    #expect(VoiceWaveformDisplayPolicy.maximumPanelHeight == 180)
    #expect(VoiceWaveformDisplayPolicy.maximumResultPanelHeight == 300)
    #expect(VoiceWaveformDisplayPolicy.contextualResultActionHeight == 22)
    #expect(VoiceWaveformDisplayPolicy.maximumResultTextHeight > VoiceWaveformDisplayPolicy.maximumTextHeight)
    #expect(
        VoiceWaveformDisplayPolicy.maximumResultTextHeight
            == VoiceWaveformDisplayPolicy.maximumResultPanelHeight
                - VoiceWaveformDisplayPolicy.topPadding
                - VoiceWaveformDisplayPolicy.textWaveformSpacing
                - VoiceWaveformDisplayPolicy.contextualResultActionHeight
                - VoiceWaveformDisplayPolicy.bottomPadding
    )
    #expect(VoiceWaveformDisplayPolicy.resultPanelHeight(for: 400) == VoiceWaveformDisplayPolicy.maximumResultPanelHeight)
    #expect(VoiceWaveformDisplayPolicy.floatingScrollerGutter == 24)
    #expect(VoiceWaveformDisplayPolicy.transcriptLayoutWidth < VoiceWaveformDisplayPolicy.textContentWidth)
}

@Test func waveformDisplayPolicyUsesLongNoiseGrid() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    #expect(cells.count == VoiceWaveformDisplayPolicy.gridColumnCount * VoiceWaveformDisplayPolicy.gridRowCount)
    #expect(cells.allSatisfy { $0.rect.width == 3.2 && $0.rect.height == 3.2 })
    #expect(cells.first?.rect.midX ?? 0 < cells.last?.rect.midX ?? 0)
    #expect(((cells.last?.rect.maxX ?? 0) - (cells.first?.rect.minX ?? 0)) >= 210)
}

@Test func waveformUsesLayeredBrightnessNoise() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    #expect(Set(cells.map { round($0.intensity * 100) / 100 }).count > 12)
}

@Test func silentWaveformKeepsVisibleAmbientNoise() {
    let idleCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: false
    )
    let activeCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: true
    )

    #expect((idleCells.map(\.intensity).max() ?? 0) > 0.02)
    #expect((activeCells.map(\.intensity).max() ?? 0) > (idleCells.map(\.intensity).max() ?? 0))
}

@Test func quietAudioCreatesVisibleWaveMovement() {
    let quietCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.18,
        phase: 0,
        isActive: true
    )
    let idleCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: true
    )

    let quietBrightest = quietCells.map(\.intensity).max() ?? 0
    let idleBrightest = idleCells.map(\.intensity).max() ?? 0
    #expect(quietBrightest - idleBrightest >= 0.08)
}

@Test func silentActiveWaveformKeepsFlowingNoiseMotion() {
    let firstFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: true
    )
    let laterFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 3.4,
        isActive: true
    )

    #expect(firstFrame != laterFrame)
    #expect(Set(firstFrame.map { round($0.intensity * 100) / 100 }).count > 6)
}

@Test func louderAudioExpandsBrightnessAwayFromCenter() {
    let quietCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: true
    )
    let loudCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.82,
        phase: 0,
        isActive: true
    )

    let quietOuterAverage = averageOuterIntensity(quietCells)
    let loudOuterAverage = averageOuterIntensity(loudCells)
    #expect(loudOuterAverage > quietOuterAverage * 2)
}

@Test func waveformEnergyStaysFocusedNearCenter() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.34,
        phase: 1.2,
        isActive: true
    )

    #expect(averageCenterIntensity(cells) > averageOuterIntensity(cells) * 4)
}

@Test func waveformEdgesFadeOutNaturally() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.62,
        phase: 0.8,
        isActive: true
    )

    let edgeCells = cells.filter { $0.distanceFromCenter > 0.92 }
    #expect((edgeCells.map(\.intensity).max() ?? 1) < 0.04)
}

@Test func waveformFeedbackHidesImmediatelyAfterInsertion() {
    #expect(VoiceWaveformDisplayPolicy.insertedTextHideDelay == 0)
}

private func averageCenterIntensity(_ cells: [VoiceWaveformGridCell]) -> CGFloat {
    let centerCells = cells.filter { $0.distanceFromCenter < 0.20 }
    let total = centerCells.reduce(CGFloat(0)) { $0 + $1.intensity }
    return total / CGFloat(max(centerCells.count, 1))
}

private func averageOuterIntensity(_ cells: [VoiceWaveformGridCell]) -> CGFloat {
    let outerCells = cells.filter { $0.distanceFromCenter > 0.55 }
    let total = outerCells.reduce(CGFloat(0)) { $0 + $1.intensity }
    return total / CGFloat(max(outerCells.count, 1))
}
