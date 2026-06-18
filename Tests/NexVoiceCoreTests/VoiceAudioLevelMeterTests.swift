import Testing
@testable import NexVoiceCore

@Test func audioLevelMeterTreatsSilenceAsZero() {
    #expect(VoiceAudioLevelMeter.normalizedLevel(samples: [0, 0, 0]) == 0)
}

@Test func audioLevelMeterNormalizesSpeechLevelSamples() {
    let level = VoiceAudioLevelMeter.normalizedLevel(samples: [0.05, -0.1, 0.2, -0.15])

    #expect(level > 0)
    #expect(level <= 1)
}

@Test func audioLevelMeterMakesQuietSpeechVisible() {
    let level = VoiceAudioLevelMeter.normalizedLevel(samples: [0.02, -0.018, 0.015, -0.021])

    #expect(level >= 0.35)
}

@Test func audioLevelMeterSuppressesTinyNoiseFloor() {
    let level = VoiceAudioLevelMeter.normalizedLevel(samples: [0.001, -0.001, 0.001])

    #expect(level == 0)
}

@Test func audioLevelMeterClampsLoudSamples() {
    #expect(VoiceAudioLevelMeter.normalizedLevel(samples: [2, -2, 2]) == 1)
}
