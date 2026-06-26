import Testing
@testable import NexVoiceCore

@Test func continuousRewriteUsesFocusedDraftForShortExistingInput() {
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: "我觉得这个功能应该基于输入框已有内容改写。",
        newTranscript: "然后我不一定一次说完，可能会分三次补充。",
        hasEditableSelection: false
    )

    #expect(decision.insertionMode == .replaceFocusedDraft)
    #expect(decision.rewriteSource.contains("已有输入框草稿："))
    #expect(decision.rewriteSource.contains("本轮新增语音："))
    #expect(decision.rewriteSource.contains("我觉得这个功能应该基于输入框已有内容改写。"))
    #expect(decision.rewriteSource.contains("然后我不一定一次说完，可能会分三次补充。"))
}

@Test func continuousRewriteIgnoresUntrustedFocusedDraft() {
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: "继续追问",
        focusedDraftIsTrusted: false,
        newTranscript: "现在每次说话都会带引导语，会把引导语带出来。",
        hasEditableSelection: false
    )

    #expect(decision.insertionMode == .insertAtCursor)
    #expect(decision.rewriteSource == "现在每次说话都会带引导语，会把引导语带出来。")
    #expect(decision.focusedDraft == nil)
}

@Test func continuousRewriteFallsBackToCurrentTranscriptWhenInputIsEmpty() {
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: "   \n",
        newTranscript: "先帮我整理这句话。",
        hasEditableSelection: false
    )

    #expect(decision.insertionMode == .insertAtCursor)
    #expect(decision.rewriteSource == "先帮我整理这句话。")
}

@Test func continuousRewriteDoesNotReplaceWhenEditableSelectionExists() {
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: "只选中了输入框里的一小段",
        newTranscript: "把这段改得更清楚。",
        hasEditableSelection: true
    )

    #expect(decision.insertionMode == .insertAtCursor)
    #expect(decision.rewriteSource == "把这段改得更清楚。")
}

@Test func continuousRewriteDoesNotReplaceLongDraftsInFirstVersion() {
    let longDraft = String(repeating: "这是一段已经很长的网页编辑器或文档内容。", count: 140)
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: longDraft,
        newTranscript: "再补充一个点。",
        hasEditableSelection: false
    )

    #expect(decision.insertionMode == .insertAtCursor)
    #expect(decision.rewriteSource == "再补充一个点。")
}

@Test func continuousRewritePromptInstructsModelToReturnWholeDraft() {
    let decision = VoiceContinuousRewritePolicy.decision(
        focusedDraft: "我希望这个功能基于输入框已有内容改写。",
        newTranscript: "新增语音是后面补充的第二个点。",
        hasEditableSelection: false
    )
    let prompt = VoiceRewritePromptPolicy.promptPlan(
        for: decision.rewriteSource,
        outputLanguage: .simplifiedChinese,
        style: .standard,
        context: VoiceRewriteContext()
    ).userPrompt

    #expect(prompt.contains("连续改写"))
    #expect(prompt.contains("输出一版完整的新草稿"))
    #expect(prompt.contains("不要只改写本轮新增语音"))
    #expect(prompt.contains("必须继续使用真实换行"))
    #expect(prompt.contains("每个编号项、问题项或段落单独成行"))
}
