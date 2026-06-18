import Testing
@testable import NexVoiceCore

@Test func speechRecognitionLanguagesExposeExpectedLocales() {
    #expect(SpeechRecognitionLanguage.simplifiedChinese.localeIdentifier == "zh_CN")
    #expect(SpeechRecognitionLanguage.englishUS.localeIdentifier == "en_US")
}

@Test func speechRecognitionLanguagesHaveHumanReadableTitles() {
    #expect(SpeechRecognitionLanguage.simplifiedChinese.menuTitle == "中文")
    #expect(SpeechRecognitionLanguage.englishUS.menuTitle == "English")
}
