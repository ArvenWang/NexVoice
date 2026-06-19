import Testing
@testable import NexVoiceCore

@Test func outputLanguageMenuTitlesAreExplicitOutputModes() {
    #expect(VoiceOutputLanguage.simplifiedChinese.menuTitle == "中文")
    #expect(VoiceOutputLanguage.english.menuTitle == "English")
}
