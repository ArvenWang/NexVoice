import Testing
@testable import NexVoiceCore

@Test func escapeCancellationAppliesToActiveVoicePipelineOnly() {
    #expect(!VoiceSessionCancellationPolicy.shouldCancel(
        transcriptionState: .idle,
        isRewriting: false,
        hasRewriteTask: false
    ))
    #expect(VoiceSessionCancellationPolicy.shouldCancel(
        transcriptionState: .running,
        isRewriting: false,
        hasRewriteTask: false
    ))
    #expect(VoiceSessionCancellationPolicy.shouldCancel(
        transcriptionState: .finishing,
        isRewriting: false,
        hasRewriteTask: false
    ))
    #expect(VoiceSessionCancellationPolicy.shouldCancel(
        transcriptionState: .idle,
        isRewriting: true,
        hasRewriteTask: true
    ))
}
