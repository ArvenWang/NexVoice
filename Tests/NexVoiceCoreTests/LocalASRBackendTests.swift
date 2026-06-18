import Testing
@testable import NexVoiceCore

@Test func localASRDefaultsToTencentRealtimeForLowestLatency() {
    #expect(LocalASRBackend.default == .tencentCloudRealtime)
}

@Test func localASRBackendHasReadableDisplayTitles() {
    #expect(LocalASRBackend.tencentCloudRealtime.displayTitle == "腾讯云实时 ASR 大模型")
    #expect(LocalASRBackend.senseVoice.displayTitle == "SenseVoice Small")
    #expect(LocalASRBackend.whisperKit.displayTitle == "WhisperKit large-v3")
}
