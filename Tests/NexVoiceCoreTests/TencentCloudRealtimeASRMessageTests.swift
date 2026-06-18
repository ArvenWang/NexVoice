import Foundation
import Testing
@testable import NexVoiceCore

@Test func tencentRealtimeASRMessageParsesUnstableSlice() throws {
    let data = Data("""
    {"code":0,"message":"success","voice_id":"voice","message_id":"voice_11_0","result":{"slice_type":1,"index":0,"start_time":0,"end_time":1240,"voice_text_str":"实时","word_size":0,"word_list":[]}}
    """.utf8)

    let message = try TencentCloudRealtimeASRMessage.decode(from: data)

    #expect(message.isSuccess)
    #expect(message.isStreamFinal == false)
    #expect(message.result?.sliceType == .recognizing)
    #expect(message.result?.voiceText == "实时")
    #expect(message.result?.isStable == false)
}

@Test func tencentRealtimeASRMessageParsesStableSliceAndFinalMarker() throws {
    let stableData = Data("""
    {"code":0,"message":"success","voice_id":"voice","message_id":"voice_33_0","result":{"slice_type":2,"index":0,"start_time":0,"end_time":2840,"voice_text_str":"实时语音识别","word_size":0,"word_list":[]}}
    """.utf8)
    let finalData = Data("""
    {"code":0,"message":"success","voice_id":"voice","message_id":"voice_241","final":1}
    """.utf8)

    let stableMessage = try TencentCloudRealtimeASRMessage.decode(from: stableData)
    let finalMessage = try TencentCloudRealtimeASRMessage.decode(from: finalData)

    #expect(stableMessage.result?.sliceType == .ended)
    #expect(stableMessage.result?.isStable == true)
    #expect(finalMessage.isStreamFinal)
}

@Test func tencentRealtimeTranscriptBufferCommitsStableSlicesByIndex() throws {
    var buffer = TencentCloudRealtimeTranscriptBuffer()
    try buffer.apply(.decode(from: Data("""
    {"code":0,"message":"success","voice_id":"voice","message_id":"voice_1","result":{"slice_type":2,"index":1,"start_time":1200,"end_time":2000,"voice_text_str":"第二句。","word_size":0,"word_list":[]}}
    """.utf8)))
    try buffer.apply(.decode(from: Data("""
    {"code":0,"message":"success","voice_id":"voice","message_id":"voice_0","result":{"slice_type":2,"index":0,"start_time":0,"end_time":1000,"voice_text_str":"第一句。","word_size":0,"word_list":[]}}
    """.utf8)))

    #expect(buffer.committedText == "第一句。第二句。")
}
