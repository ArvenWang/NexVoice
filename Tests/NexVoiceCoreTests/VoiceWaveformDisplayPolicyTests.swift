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

@Test func silentWaveformHasNoDarkPixelBase() {
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

    #expect((idleCells.map(\.intensity).max() ?? 1) == 0)
    #expect((activeCells.map(\.intensity).max() ?? 0) > (idleCells.map(\.intensity).max() ?? 0))
    #expect((activeCells.map(\.intensity).max() ?? 1) < 0.04)
}

@Test func silentActiveWaveformAvoidsStrobeDropouts() {
    let firstFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0,
        isActive: true
    )
    let nextFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0,
        phase: 0.030,
        isActive: true
    )

    #expect(totalIntensity(nextFrame) > totalIntensity(firstFrame) * 0.94)
    #expect(totalIntensity(nextFrame) < totalIntensity(firstFrame) * 1.06)
    #expect((firstFrame.map(\.intensity).max() ?? 1) < 0.04)
}

@Test func silentActiveWaveformKeepsIndividualPixelsStable() {
    let frames = (0..<60).map { frame in
        VoiceWaveformDisplayPolicy.waveformGridCells(
            in: CGRect(x: 0, y: 0, width: 236, height: 28),
            amplitude: 0,
            phase: CGFloat(frame) * 0.018,
            isActive: true
        )
    }
    let cellCount = frames.first?.count ?? 0
    let stableVisibleCells = (0..<cellCount).filter { index in
        let values = frames.map { $0[index].intensity }
        let maximum = values.max() ?? 0
        let minimum = values.min() ?? 0
        return maximum > 0.006 && minimum > maximum * 0.68
    }
    let visibleCells = (0..<cellCount).filter { index in
        frames.map { $0[index].intensity }.max() ?? 0 > 0.006
    }

    #expect(stableVisibleCells.count == visibleCells.count)
    #expect(visibleCells.count < cellCount)
}

@Test func waveformMotionFreezesBelowVoiceThreshold() {
    #expect(VoiceWaveformDisplayPolicy.voiceMotionLevel(for: 0) == 0)
    #expect(VoiceWaveformDisplayPolicy.voiceMotionLevel(for: 0.18) == 0)
    #expect(VoiceWaveformDisplayPolicy.voiceMotionLevel(for: 0.34) > 0.10)
    #expect(VoiceWaveformDisplayPolicy.voiceMotionLevel(for: 0.62) == 1)
    #expect(VoiceWaveformDisplayPolicy.voiceResponseLevel(for: 0.34) > VoiceWaveformDisplayPolicy.voiceMotionLevel(for: 0.34))
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
    #expect(quietBrightest - idleBrightest >= 0.025)
    #expect(quietBrightest < 0.36)
}

@Test func quietActiveWaveformKeepsFlowingNoiseMotion() {
    let firstFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.12,
        phase: 0,
        isActive: true
    )
    let laterFrame = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.12,
        phase: 3.4,
        isActive: true
    )

    #expect(firstFrame != laterFrame)
    #expect(Set(firstFrame.map { round($0.intensity * 100) / 100 }).count >= 6)
}

@Test func louderAudioBrightensCenterWithNoiseFalloff() {
    let quietCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.18,
        phase: 0,
        isActive: true
    )
    let loudCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.82,
        phase: 0,
        isActive: true
    )

    #expect(averageCenterIntensity(loudCells) > averageCenterIntensity(quietCells) + 0.44)
    #expect(averageOuterIntensity(loudCells) < averageCenterIntensity(loudCells) * 0.35)
}

@Test func loudAudioKeepsNearWhiteCoreCompact() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.82,
        phase: 0,
        isActive: true
    )

    #expect(brightCellCount(cells, threshold: 0.88) > 0)
    #expect(brightCellCount(cells, threshold: 0.88) < cells.count / 5)
}

@Test func normalVoiceExpandsBrightRegionBeyondIdleShape() {
    let quietCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.12,
        phase: 1.1,
        isActive: true
    )
    let speakingCells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.52,
        phase: 1.1,
        isActive: true
    )

    #expect(brightCellCount(speakingCells, threshold: 0.18) > brightCellCount(quietCells, threshold: 0.18) * 3)
}

@Test func waveformEnergyStaysFocusedNearCenter() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.34,
        phase: 1.2,
        isActive: true
    )

    #expect(averageCenterIntensity(cells) > averageOuterIntensity(cells) * 3)
}

@Test func waveformFormsSpindleRatherThanUniformRows() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.58,
        phase: 0.8,
        isActive: true
    )

    #expect(averageMiddleRowIntensity(cells) > averageOuterRowIntensity(cells) * 1.45)
}

@Test func waveformNoiseAvoidsDirectionalSweep() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.4,
        phase: 1.7,
        isActive: true
    )
    let centerRowCells = cells
        .filter { abs($0.rect.midY - 14) < 3 }
        .sorted { $0.rect.midX < $1.rect.midX }
        .map(\.intensity)

    #expect(signChangeCount(in: centerRowCells) >= 10)
}

@Test func waveformNoiseLeavesSparseSideHighlights() {
    let cells = VoiceWaveformDisplayPolicy.waveformGridCells(
        in: CGRect(x: 0, y: 0, width: 236, height: 28),
        amplitude: 0.72,
        phase: 2.4,
        isActive: true
    )
    let sideCells = cells.filter { $0.distanceFromCenter > 0.56 }

    #expect(sideCells.contains { $0.intensity > 0.08 })
    #expect(sideCells.filter { $0.intensity > 0.08 }.count < sideCells.count / 3)
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

private func averageMiddleRowIntensity(_ cells: [VoiceWaveformGridCell]) -> CGFloat {
    let middleRowCells = cells.filter { abs($0.rect.midY - 14) < 3 }
    let total = middleRowCells.reduce(CGFloat(0)) { $0 + $1.intensity }
    return total / CGFloat(max(middleRowCells.count, 1))
}

private func averageOuterRowIntensity(_ cells: [VoiceWaveformGridCell]) -> CGFloat {
    let outerRowCells = cells.filter { abs($0.rect.midY - 14) > 8 }
    let total = outerRowCells.reduce(CGFloat(0)) { $0 + $1.intensity }
    return total / CGFloat(max(outerRowCells.count, 1))
}

private func signChangeCount(in values: [CGFloat]) -> Int {
    guard values.count >= 3 else { return 0 }
    var changes = 0
    var previousDirection = 0
    for index in 1..<values.count {
        let diff = values[index] - values[index - 1]
        let direction = diff > 0 ? 1 : (diff < 0 ? -1 : 0)
        if direction != 0, previousDirection != 0, direction != previousDirection {
            changes += 1
        }
        if direction != 0 {
            previousDirection = direction
        }
    }
    return changes
}

private func brightCellCount(_ cells: [VoiceWaveformGridCell], threshold: CGFloat) -> Int {
    cells.filter { $0.intensity > threshold }.count
}

private func totalIntensity(_ cells: [VoiceWaveformGridCell]) -> CGFloat {
    cells.reduce(CGFloat(0)) { $0 + $1.intensity }
}
