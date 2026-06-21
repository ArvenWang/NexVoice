import CoreGraphics
import Testing
@testable import NexVoiceCore

@Test func waveformDisplayPolicyKeepsPanelCompact() {
    #expect(VoiceWaveformDisplayPolicy.waveformSize == CGSize(width: 64, height: 28))
    #expect(VoiceWaveformDisplayPolicy.compactPanelSize == CGSize(width: 92, height: 56))
    #expect(VoiceWaveformDisplayPolicy.loadingPanelSize == CGSize(width: 156, height: 44))
    #expect(VoiceWaveformDisplayPolicy.statusPanelSize == CGSize(width: 188, height: 44))
    #expect(VoiceWaveformDisplayPolicy.stageSize == CGSize(width: 420, height: 300))
    #expect(VoiceWaveformDisplayPolicy.panelSize == CGSize(width: 92, height: 56))
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
    #expect(VoiceWaveformDisplayPolicy.maximumResultTextHeight > VoiceWaveformDisplayPolicy.maximumTextHeight)
    #expect(VoiceWaveformDisplayPolicy.resultPanelHeight(for: 400) == VoiceWaveformDisplayPolicy.maximumResultPanelHeight)
    #expect(VoiceWaveformDisplayPolicy.floatingScrollerGutter == 24)
    #expect(VoiceWaveformDisplayPolicy.transcriptLayoutWidth < VoiceWaveformDisplayPolicy.textContentWidth)
}

@Test func waveformDisplayPolicyUsesNexHubStyleFiveBars() {
    let rects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    #expect(rects.count == 5)
    #expect(rects.allSatisfy { $0.width == 5 })
    #expect(rects.first?.midX ?? 0 < rects.last?.midX ?? 0)
    #expect(((rects.last?.maxX ?? 0) - (rects.first?.minX ?? 0)) >= 37)
}

@Test func waveformUsesAnimatedNexHubStyleShape() {
    let rects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    #expect(Set(rects.map { round($0.height * 10) / 10 }).count > 1)
}

@Test func silentWaveformShowsStableBaselineOnly() {
    let idleRects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0,
        phase: 0,
        isActive: false
    )
    let activeRects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0,
        phase: 0,
        isActive: true
    )

    #expect((idleRects.first?.height ?? 0) >= 4)
    #expect((activeRects.map(\.height).max() ?? 0) > (idleRects.map(\.height).max() ?? 0))
}

@Test func quietAudioCreatesVisibleWaveMovement() {
    let quietRects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0.18,
        phase: 0,
        isActive: true
    )
    let idleRects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0,
        phase: 0,
        isActive: true
    )

    let quietTallest = quietRects.map(\.height).max() ?? 0
    let idleTallest = idleRects.map(\.height).max() ?? 0
    #expect(quietTallest - idleTallest >= 3)
}

@Test func silentActiveWaveformKeepsSubtleListeningMotion() {
    let firstFrame = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0,
        phase: 0,
        isActive: true
    )
    let laterFrame = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0,
        phase: 3.4,
        isActive: true
    )

    #expect(firstFrame != laterFrame)
    #expect(Set(firstFrame.map { round($0.height * 10) / 10 }).count > 1)
}

@Test func waveformFeedbackHidesImmediatelyAfterInsertion() {
    #expect(VoiceWaveformDisplayPolicy.insertedTextHideDelay == 0)
}
