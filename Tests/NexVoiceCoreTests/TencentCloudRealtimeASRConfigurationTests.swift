import Foundation
import Testing
@testable import NexVoiceCore

@Test func tencentRealtimeASRDefaultsToChineseEnglishLargeModel() {
    let configuration = TencentCloudRealtimeASRConfiguration(
        credentials: TencentCloudASRCredentials(
            appID: "1250000000",
            secretID: "AKIDexample",
            secretKey: "secret"
        ),
        language: .simplifiedChinese,
        voiceID: "voice-1",
        timestamp: 1_745_932_688,
        expired: 1_745_933_288,
        nonce: 8_743_357
    )

    #expect(configuration.engineModelType == "16k_zh_en")
    #expect(configuration.voiceFormat == 1)
    #expect(configuration.needVAD)
    #expect(configuration.hotwordList == "NexVoice|11,腾讯云|10,ASR|11")
}

@Test func tencentRealtimeASRUsesEnglishLargeModelForEnglishInput() {
    let configuration = TencentCloudRealtimeASRConfiguration(
        credentials: TencentCloudASRCredentials(
            appID: "1250000000",
            secretID: "AKIDexample",
            secretKey: "secret"
        ),
        language: .englishUS,
        voiceID: "voice-1",
        timestamp: 1_745_932_688,
        expired: 1_745_933_288,
        nonce: 8_743_357
    )

    #expect(configuration.engineModelType == "16k_en_large")
}

@Test func tencentRealtimeASRBuildsSignedWebSocketURL() throws {
    let configuration = TencentCloudRealtimeASRConfiguration(
        credentials: TencentCloudASRCredentials(
            appID: "1250000000",
            secretID: "AKIDexample",
            secretKey: "secret"
        ),
        language: .simplifiedChinese,
        voiceID: "voice-1",
        timestamp: 1_745_932_688,
        expired: 1_745_933_288,
        nonce: 8_743_357,
        hotwordList: "NexVoice|11"
    )

    #expect(configuration.signaturePlaintext == "asr.cloud.tencent.com/asr/v2/1250000000?convert_num_mode=1&engine_model_type=16k_zh_en&expired=1745933288&filter_dirty=0&filter_empty_result=1&filter_modal=0&filter_punc=0&hotword_list=NexVoice%7C11&max_speak_time=10000&needvad=1&nonce=8743357&secretid=AKIDexample&timestamp=1745932688&vad_silence_time=800&voice_format=1&voice_id=voice-1&word_info=0")
    #expect(TencentCloudRealtimeASRSigner.hmacSHA1Base64(message: "message", key: "secret") == "DK9kn+7klT2Hv5A6wRdsReAo3xY=")

    let url = try configuration.signedWebSocketURL()
    let urlString = url.absoluteString
    #expect(urlString.hasPrefix("wss://asr.cloud.tencent.com/asr/v2/1250000000?"))
    #expect(urlString.contains("signature="))
    #expect(urlString.contains("hotword_list=NexVoice%7C11"))
}

@Test func tencentCredentialsReportMissingFieldsWithoutLeakingValues() {
    let credentials = TencentCloudASRCredentials(
        appID: "1250000000",
        secretID: "AKIDexample",
        secretKey: ""
    )

    #expect(credentials.missingFieldNames == ["SecretKey"])
    #expect(credentials.isComplete == false)
}

@Test func tencentCredentialStoreLoadsEnvironmentBeforeFile() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try Data("""
    {"appID":"file-app","secretID":"file-id","secretKey":"file-key"}
    """.utf8).write(to: temporaryFile)
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    let credentials = try TencentCloudASRCredentialStore.load(
        environment: [
            "NEXVOICE_TENCENT_ASR_APP_ID": "env-app",
            "NEXVOICE_TENCENT_ASR_SECRET_ID": "env-id",
            "NEXVOICE_TENCENT_ASR_SECRET_KEY": "env-key"
        ],
        fileURL: temporaryFile
    )

    #expect(credentials.appID == "env-app")
    #expect(credentials.secretID == "env-id")
    #expect(credentials.secretKey == "env-key")
}

@Test func tencentCredentialStoreLoadsJSONFileWhenEnvironmentIsIncomplete() throws {
    let temporaryFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try Data("""
    {"appID":"file-app","secretID":"file-id","secretKey":"file-key"}
    """.utf8).write(to: temporaryFile)
    defer { try? FileManager.default.removeItem(at: temporaryFile) }

    let credentials = try TencentCloudASRCredentialStore.load(
        environment: ["NEXVOICE_TENCENT_ASR_APP_ID": "env-app"],
        fileURL: temporaryFile
    )

    #expect(credentials.appID == "file-app")
    #expect(credentials.secretID == "file-id")
    #expect(credentials.secretKey == "file-key")
}
