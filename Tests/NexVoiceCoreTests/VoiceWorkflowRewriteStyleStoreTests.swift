import Foundation
import Testing
@testable import NexVoiceCore

@Test func workflowRewriteStyleStoreFallsBackToGlobalDefault() {
    let suiteName = "VoiceWorkflowRewriteStyleStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    let store = VoiceWorkflowRewriteStyleStore(defaults: defaults)

    #expect(store.style(for: "agent-collaboration", defaultStyle: .standard) == .standard)
}

@Test func workflowRewriteStyleStoreSavesIndependentWorkflowOverrides() {
    let suiteName = "VoiceWorkflowRewriteStyleStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    let store = VoiceWorkflowRewriteStyleStore(defaults: defaults)

    store.save(.socialExpert, for: "social")
    store.save(.calm, for: "email-reply")

    #expect(store.style(for: "social", defaultStyle: .standard) == .socialExpert)
    #expect(store.style(for: "email-reply", defaultStyle: .standard) == .calm)
    #expect(store.style(for: "work-chat", defaultStyle: .amplifiedSpokesperson) == .amplifiedSpokesperson)
}
