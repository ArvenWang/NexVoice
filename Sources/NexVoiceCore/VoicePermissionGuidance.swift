import Foundation

public struct VoicePermissionGuidance: Equatable, Sendable {
    public let actionTitle: String
    public let noticeTitle: String
    public let explanation: String

    public static let accessibility = VoicePermissionGuidance(
        actionTitle: "申请辅助功能权限",
        noticeTitle: "需要辅助功能权限",
        explanation: "NexVoice 需要辅助功能权限，才能响应语音快捷键，并把识别结果输入到当前输入框。"
    )
}
