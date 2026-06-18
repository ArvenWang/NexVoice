import Testing
@testable import NexVoiceCore

@Test func levelSmootherKeepsSubThresholdNoiseSilent() {
    var smoother = VoiceAudioLevelSmoother()

    let outputs = [0.08, 0.12, 0.14, 0.1].map {
        smoother.process(rawLevel: $0)
    }

    #expect(outputs.allSatisfy { $0 == 0 })
}

@Test func levelSmootherOpensOnQuietSpeech() {
    var smoother = VoiceAudioLevelSmoother()

    let output = smoother.process(rawLevel: 0.35)

    #expect(output >= 0.18)
}

@Test func levelSmootherClosesAfterSustainedSilence() {
    var smoother = VoiceAudioLevelSmoother()

    _ = smoother.process(rawLevel: 0.7)
    let firstQuietFrame = smoother.process(rawLevel: 0.03)
    let secondQuietFrame = smoother.process(rawLevel: 0.02)
    let thirdQuietFrame = smoother.process(rawLevel: 0.01)

    #expect(firstQuietFrame > 0)
    #expect(secondQuietFrame > 0)
    #expect(thirdQuietFrame == 0)
}
