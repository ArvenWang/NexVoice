import Foundation
import Testing
@testable import NexVoiceCore

@Test func pcmFrameDurationUsesSampleRateChannelCountAndInt16Width() {
    let sampleCount = 1_600
    let bytes = Data(repeating: 0, count: sampleCount * MemoryLayout<Int16>.size)
    let frame = AudioPCMFrame(
        pcm16LittleEndian: bytes,
        sampleRate: 16_000,
        channelCount: 1
    )

    #expect(frame.durationSeconds == 0.1)
    #expect(frame.isEmpty == false)
}

@Test func emptyPCMFrameHasZeroDuration() {
    let frame = AudioPCMFrame(
        pcm16LittleEndian: Data(),
        sampleRate: 16_000,
        channelCount: 1
    )

    #expect(frame.durationSeconds == 0)
    #expect(frame.isEmpty)
}
