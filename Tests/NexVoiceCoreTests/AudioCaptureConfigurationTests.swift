import Testing
@preconcurrency import AVFAudio
@testable import NexVoiceCore

@Test func defaultCaptureConfigurationTargetsRealtimeASRInput() {
    let configuration = AudioCaptureConfiguration()

    #expect(configuration.targetSampleRate == 16_000)
    #expect(configuration.channelCount == 1)
    #expect(configuration.frameDurationMilliseconds == 100)
    #expect(configuration.targetFrameSampleCount == 1_600)
}

@Test func captureConfigurationRejectsNonPositiveValues() {
    #expect(throws: AudioCaptureConfiguration.ValidationError.invalidSampleRate) {
        try AudioCaptureConfiguration.validated(targetSampleRate: 0, channelCount: 1, frameDurationMilliseconds: 100)
    }

    #expect(throws: AudioCaptureConfiguration.ValidationError.invalidChannelCount) {
        try AudioCaptureConfiguration.validated(targetSampleRate: 16_000, channelCount: 0, frameDurationMilliseconds: 100)
    }

    #expect(throws: AudioCaptureConfiguration.ValidationError.invalidFrameDuration) {
        try AudioCaptureConfiguration.validated(targetSampleRate: 16_000, channelCount: 1, frameDurationMilliseconds: 0)
    }
}

@Test func captureOutputCapacityKeepsConverterPreconditionForDownsampling() {
    let capacity = AudioCaptureService.outputFrameCapacity(
        inputFrameLength: 4_800,
        inputSampleRate: 48_000,
        outputSampleRate: 16_000
    )

    #expect(capacity >= 4_800)
}

@Test func captureConverterDownsamplesStereoFloatInputToMonoPCM16() throws {
    let inputFormat = try #require(AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 48_000,
        channels: 2,
        interleaved: false
    ))
    let outputFormat = try #require(AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    ))
    let converter = try #require(AVAudioConverter(from: inputFormat, to: outputFormat))
    let inputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4_800))
    inputBuffer.frameLength = 4_800
    for channelIndex in 0..<Int(inputFormat.channelCount) {
        let channel = try #require(inputBuffer.floatChannelData?[channelIndex])
        for frameIndex in 0..<Int(inputBuffer.frameLength) {
            channel[frameIndex] = Float(frameIndex % 64) / 64
        }
    }

    let frame = AudioCaptureService.convertBuffer(
        inputBuffer,
        converter: converter,
        outputFormat: outputFormat,
        configuration: AudioCaptureConfiguration()
    )

    #expect(frame?.sampleRate == 16_000)
    #expect(frame?.channelCount == 1)
    #expect(frame?.pcm16LittleEndian.isEmpty == false)
}
