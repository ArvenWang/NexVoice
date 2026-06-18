import Testing
@testable import NexVoiceCore

@Test func accessibilityGuidanceExplainsTextInsertionDependency() {
    let guidance = VoicePermissionGuidance.accessibility

    #expect(guidance.actionTitle == "申请辅助功能权限")
    #expect(guidance.explanation.contains("语音快捷键"))
    #expect(guidance.explanation.contains("当前输入框"))
}
