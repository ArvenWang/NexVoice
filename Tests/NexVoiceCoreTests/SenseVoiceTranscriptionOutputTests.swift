import Foundation
import Testing
@testable import NexVoiceCore

@Test func senseVoiceOutputParserExtractsTrimmedTextFromJSON() throws {
    let output = Data("""
    {"text":"  你好，NexVoice。  ","duration_seconds":1.2,"elapsed_seconds":0.3}
    """.utf8)

    #expect(try SenseVoiceTranscriptionOutput.transcribedText(from: output) == "你好，NexVoice。")
}

@Test func senseVoiceOutputParserRejectsInvalidJSON() {
    let output = Data("not json".utf8)

    #expect(throws: SenseVoiceTranscriptionOutput.Error.self) {
        try SenseVoiceTranscriptionOutput.transcribedText(from: output)
    }
}
