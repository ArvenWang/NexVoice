import Foundation
import Testing
@testable import NexVoiceCore

@Test func rewriteStyleDefinesDefaultAndToneMenuTitles() {
    #expect(VoiceRewriteStyle.default == .standard)
    #expect(VoiceRewriteStyle.allCases == [
        .standard,
        .socialExpert,
        .amplifiedSpokesperson,
        .calm
    ])
    #expect(VoiceRewriteStyle.standard.menuTitle == "标准模式（默认）")
    #expect(VoiceRewriteStyle.socialExpert.menuTitle == "社交达人")
    #expect(VoiceRewriteStyle.amplifiedSpokesperson.menuTitle == "强化嘴替")
    #expect(VoiceRewriteStyle.calm.menuTitle == "冷静模式")
}

@Test func rewriteStyleInstructionsAreLanguageAgnostic() {
    #expect(VoiceRewriteStyle.standard.promptInstruction.contains("标准模式"))
    #expect(VoiceRewriteStyle.standard.promptInstruction.contains("严格贴合原意"))
    #expect(VoiceRewriteStyle.standard.promptInstruction.contains("不添加新观点"))
    #expect(VoiceRewriteStyle.socialExpert.promptInstruction.contains("社交达人"))
    #expect(VoiceRewriteStyle.socialExpert.promptInstruction.contains("X、Reddit"))
    #expect(VoiceRewriteStyle.socialExpert.promptInstruction.contains("不硬加梗"))
    #expect(VoiceRewriteStyle.amplifiedSpokesperson.promptInstruction.contains("强化嘴替"))
    #expect(VoiceRewriteStyle.amplifiedSpokesperson.promptInstruction.contains("更有冲击力"))
    #expect(VoiceRewriteStyle.amplifiedSpokesperson.promptInstruction.contains("更有张力"))
    #expect(VoiceRewriteStyle.calm.promptInstruction.contains("冷静模式"))
    #expect(VoiceRewriteStyle.calm.promptInstruction.contains("用尽量少的字"))
    #expect(VoiceRewriteStyle.calm.promptInstruction.contains("语气冷静"))
    #expect(!VoiceRewriteStyle.standard.promptInstruction.contains("英文邮件"))
}

@Test func rewriteStyleDefinesTemperatureLadder() {
    #expect(VoiceRewriteStyle.standard.rewriteTemperature == 0.1)
    #expect(VoiceRewriteStyle.calm.rewriteTemperature == 0.15)
    #expect(VoiceRewriteStyle.socialExpert.rewriteTemperature == 0.35)
    #expect(VoiceRewriteStyle.amplifiedSpokesperson.rewriteTemperature == 0.75)
    #expect(VoiceRewriteStyle.standard.rewriteTemperature < VoiceRewriteStyle.amplifiedSpokesperson.rewriteTemperature)
}

@Test func rewriteStyleDecodesLegacyValuesToSafeModes() throws {
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""automatic""#.data(using: .utf8)!) == .standard)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""general""#.data(using: .utf8)!) == .standard)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""faithful""#.data(using: .utf8)!) == .standard)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""clear""#.data(using: .utf8)!) == .standard)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""professional""#.data(using: .utf8)!) == .standard)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""casualFun""#.data(using: .utf8)!) == .socialExpert)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""natural""#.data(using: .utf8)!) == .socialExpert)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""expressive""#.data(using: .utf8)!) == .amplifiedSpokesperson)
    #expect(try JSONDecoder().decode(VoiceRewriteStyle.self, from: #""creativeWild""#.data(using: .utf8)!) == .amplifiedSpokesperson)
}
