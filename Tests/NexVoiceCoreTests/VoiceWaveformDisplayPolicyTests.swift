import CoreGraphics
import Testing
@testable import NexVoiceCore

@Test func waveformDisplayPolicyKeepsPanelCompact() {
    #expect(VoiceWaveformDisplayPolicy.panelSize == CGSize(width: 176, height: 52))
    #expect(VoiceWaveformDisplayPolicy.bottomOffset == 34)
}

@Test func waveformDisplayPolicyUsesManyThinBars() {
    let rects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    #expect(rects.count == 21)
    #expect(rects.allSatisfy { $0.width == 3 })
    #expect(rects.first?.midX ?? 0 < rects.last?.midX ?? 0)
    #expect(((rects.last?.maxX ?? 0) - (rects.first?.minX ?? 0)) >= 120)
}

@Test func waveformUsesTypelessStyleCenterWeightedEnvelope() {
    let rects = VoiceWaveformDisplayPolicy.waveBarRects(
        in: CGRect(x: 0, y: 0, width: 176, height: 52),
        amplitude: 0.7,
        phase: 0,
        isActive: true
    )

    let centerHeight = rects[rects.count / 2].height
    let edgeHeight = max(rects.first?.height ?? 0, rects.last?.height ?? 0)

    #expect(centerHeight - edgeHeight >= 10)
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
    #expect(activeRects == idleRects)
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
    #expect(quietTallest - idleTallest >= 8)
}

@Test func silentActiveWaveformDoesNotWiggleWithPhase() {
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

    #expect(firstFrame == laterFrame)
    #expect(Set(firstFrame.map(\.height)).count == 1)
}

@Test func waveformFeedbackHidesImmediatelyAfterInsertion() {
    #expect(VoiceWaveformDisplayPolicy.insertedTextHideDelay == 0)
}
