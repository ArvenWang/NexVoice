import Foundation
import Testing
@testable import NexVoiceCore

@Test func waveFileWriterBuildsPcm16MonoHeader() throws {
    let samples = Data([0x01, 0x00, 0x02, 0x00])
    let wav = try AudioWaveFileWriter.wavData(
        pcm16LittleEndian: samples,
        sampleRate: 16_000,
        channelCount: 1
    )

    #expect(String(data: wav[0..<4], encoding: .ascii) == "RIFF")
    #expect(String(data: wav[8..<12], encoding: .ascii) == "WAVE")
    #expect(String(data: wav[12..<16], encoding: .ascii) == "fmt ")
    #expect(String(data: wav[36..<40], encoding: .ascii) == "data")
    #expect(wav.count == 44 + samples.count)
}

@Test func waveFileWriterRejectsEmptyAudio() {
    #expect(throws: AudioWaveFileWriter.Error.emptyAudio) {
        try AudioWaveFileWriter.wavData(
            pcm16LittleEndian: Data(),
            sampleRate: 16_000,
            channelCount: 1
        )
    }
}
