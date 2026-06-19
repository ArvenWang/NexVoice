import Foundation
import Testing
@testable import NexVoiceCore

@Test func rewriteStyleDefinesDefaultAndToneMenuTitles() {
    #expect(VoiceRewriteStyle.default == .faithful)
    #expect(VoiceRewriteStyle.allCases == [
        .faithful,
        .clear,
        .natural,
        .professional,
        .expressive,
        .creativeWild
    ])
    #expect(VoiceRewriteStyle.faithful.menuTitle == "忠实整理（默认）")
    #expect(VoiceRewriteStyle.clear.menuTitle == "清晰优化")
    #expect(VoiceRewriteStyle.natural.menuTitle == "自然表达")
    #expect(VoiceRewriteStyle.professional.menuTitle == "专业严谨")
    #expect(VoiceRewriteStyle.expressive.menuTitle == "增强表达")
    #expect(VoiceRewriteStyle.creativeWild.menuTitle == "疯狂模式")
}

@Test func rewriteStyleInstructionsAreLanguageAgnostic() {
    #expect(VoiceRewriteStyle.faithful.promptInstruction.contains("最大限度保留用户原意"))
    #expect(VoiceRewriteStyle.faithful.promptInstruction.contains("不要扩写观点"))
    #expect(VoiceRewriteStyle.faithful.promptInstruction.contains("不要省略关键动作"))
    #expect(VoiceRewriteStyle.clear.promptInstruction.contains("清晰优化模式"))
    #expect(VoiceRewriteStyle.natural.promptInstruction.contains("自然表达模式"))
    #expect(VoiceRewriteStyle.natural.promptInstruction.contains("频率和严重程度"))
    #expect(VoiceRewriteStyle.professional.promptInstruction.contains("专业严谨模式"))
    #expect(VoiceRewriteStyle.expressive.promptInstruction.contains("增强表达模式"))
    #expect(VoiceRewriteStyle.creativeWild.promptInstruction.contains("疯狂模式"))
    #expect(VoiceRewriteStyle.creativeWild.promptInstruction.contains("更锋利"))
    #expect(VoiceRewriteStyle.creativeWild.promptInstruction.contains("大胆比喻"))
    #expect(VoiceRewriteStyle.creativeWild.promptInstruction.contains("普通纯文本"))
    #expect(VoiceRewriteStyle.creativeWild.promptInstruction.contains("Markdown 符号"))
    #expect(!VoiceRewriteStyle.professional.promptInstruction.contains("英文邮件"))
}

@Test func rewriteStyleDefinesTemperatureLadder() {
    #expect(VoiceRewriteStyle.faithful.rewriteTemperature == 0.05)
    #expect(VoiceRewriteStyle.clear.rewriteTemperature == 0.15)
    #expect(VoiceRewriteStyle.professional.rewriteTemperature == 0.2)
    #expect(VoiceRewriteStyle.natural.rewriteTemperature == 0.25)
    #expect(VoiceRewriteStyle.expressive.rewriteTemperature == 0.45)
    #expect(VoiceRewriteStyle.creativeWild.rewriteTemperature == 0.85)
    #expect(VoiceRewriteStyle.faithful.rewriteTemperature < VoiceRewriteStyle.creativeWild.rewriteTemperature)
}

@Test func rewriteStyleDecodesLegacyValuesToSafeModes() throws {
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""automatic""#.data(using: .utf8)!) == .faithful)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""general""#.data(using: .utf8)!) == .faithful)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""casualFun""#.data(using: .utf8)!) == .natural)
}
