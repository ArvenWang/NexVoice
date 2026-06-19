import CryptoKit
import Foundation

public struct TencentCloudASRCredentials: Equatable, Sendable {
    public let appID: String
    public let secretID: String
    public let secretKey: String

    public init(appID: String, secretID: String, secretKey: String) {
        self.appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.secretID = secretID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.secretKey = secretKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var missingFieldNames: [String] {
        var fields: [String] = []
        if appID.isEmpty { fields.append("AppID") }
        if secretID.isEmpty { fields.append("SecretId") }
        if secretKey.isEmpty { fields.append("SecretKey") }
        return fields
    }

    public var isComplete: Bool {
        missingFieldNames.isEmpty
    }
}

public enum TencentCloudRealtimeASRError: Error, LocalizedError, Equatable, Sendable {
    case missingCredentials([String])
    case invalidSignedURL

    public var errorDescription: String? {
        switch self {
        case .missingCredentials(let fields):
            return "腾讯云 ASR 配置缺少：\(fields.joined(separator: "、"))。"
        case .invalidSignedURL:
            return "腾讯云 ASR 签名地址生成失败。"
        }
    }
}

public struct TencentCloudRealtimeASRConfiguration: Equatable, Sendable {
    public static let host = "asr.cloud.tencent.com"
    public static let pathPrefix = "/asr/v2"

    public let credentials: TencentCloudASRCredentials
    public let voiceID: String
    public let timestamp: Int
    public let expired: Int
    public let nonce: Int
    public let hotwordList: String?

    public init(
        credentials: TencentCloudASRCredentials,
        voiceID: String = UUID().uuidString,
        timestamp: Int = Int(Date().timeIntervalSince1970),
        expired: Int? = nil,
        nonce: Int = Int.random(in: 1...9_999_999_999),
        hotwordList: String? = nil
    ) {
        self.credentials = credentials
        self.voiceID = voiceID
        self.timestamp = timestamp
        self.expired = expired ?? timestamp + 600
        self.nonce = nonce
        self.hotwordList = hotwordList
    }

    public var engineModelType: String {
        "16k_zh_en"
    }

    public var voiceFormat: Int { 1 }
    public var needVAD: Bool { true }
    public var vadSilenceTime: Int { 800 }
    public var maxSpeakTime: Int { 10_000 }

    public var unsignedQueryItems: [(String, String)] {
        var items: [(String, String)] = [
            ("convert_num_mode", "1"),
            ("engine_model_type", engineModelType),
            ("expired", String(expired)),
            ("filter_dirty", "0"),
            ("filter_empty_result", "1"),
            ("filter_modal", "0"),
            ("filter_punc", "0"),
            ("max_speak_time", String(maxSpeakTime)),
            ("needvad", needVAD ? "1" : "0"),
            ("nonce", String(nonce)),
            ("secretid", credentials.secretID),
            ("timestamp", String(timestamp)),
            ("vad_silence_time", String(vadSilenceTime)),
            ("voice_format", String(voiceFormat)),
            ("voice_id", voiceID),
            ("word_info", "0")
        ]
        if let hotwordList, !hotwordList.isEmpty {
            items.append(("hotword_list", hotwordList))
        }
        return items.sorted { $0.0 < $1.0 }
    }

    public var signaturePlaintext: String {
        "\(Self.host)\(Self.pathPrefix)/\(credentials.appID)?\(Self.rawQueryString(from: unsignedQueryItems))"
    }

    public func signedWebSocketURL() throws -> URL {
        let missingFields = credentials.missingFieldNames
        guard missingFields.isEmpty else {
            throw TencentCloudRealtimeASRError.missingCredentials(missingFields)
        }

        let signature = TencentCloudRealtimeASRSigner.hmacSHA1Base64(
            message: signaturePlaintext,
            key: credentials.secretKey
        )
        let signedItems = unsignedQueryItems + [("signature", signature)]
        let queryString = Self.encodedQueryString(from: signedItems)
        guard let url = URL(string: "wss://\(Self.host)\(Self.pathPrefix)/\(credentials.appID)?\(queryString)") else {
            throw TencentCloudRealtimeASRError.invalidSignedURL
        }
        return url
    }

    public static func encodedQueryString(from items: [(String, String)]) -> String {
        items.map { key, value in
            "\(percentEncode(key))=\(percentEncode(value))"
        }
        .joined(separator: "&")
    }

    public static func rawQueryString(from items: [(String, String)]) -> String {
        items.map { key, value in
            "\(key)=\(value)"
        }
        .joined(separator: "&")
    }

    static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=/?|")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public enum TencentCloudRealtimeASRSigner {
    public static func hmacSHA1Base64(message: String, key: String) -> String {
        let key = SymmetricKey(data: Data(key.utf8))
        let authenticationCode = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(message.utf8),
            using: key
        )
        return Data(authenticationCode).base64EncodedString()
    }
}

public enum TencentCloudASRCredentialStore {
    private struct FileCredentials: Decodable {
        let appID: String
        let secretID: String
        let secretKey: String
    }

    public static let appIDEnvironmentKey = "NEXVOICE_TENCENT_ASR_APP_ID"
    public static let secretIDEnvironmentKey = "NEXVOICE_TENCENT_ASR_SECRET_ID"
    public static let secretKeyEnvironmentKey = "NEXVOICE_TENCENT_ASR_SECRET_KEY"

    public static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("TencentCloudASR.json")
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileURL: URL = defaultFileURL
    ) throws -> TencentCloudASRCredentials {
        let environmentCredentials = TencentCloudASRCredentials(
            appID: environment[appIDEnvironmentKey] ?? "",
            secretID: environment[secretIDEnvironmentKey] ?? "",
            secretKey: environment[secretKeyEnvironmentKey] ?? ""
        )
        if environmentCredentials.isComplete {
            return environmentCredentials
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return environmentCredentials
        }
        let data = try Data(contentsOf: fileURL)
        let fileCredentials = try JSONDecoder().decode(FileCredentials.self, from: data)
        return TencentCloudASRCredentials(
            appID: fileCredentials.appID,
            secretID: fileCredentials.secretID,
            secretKey: fileCredentials.secretKey
        )
    }
}
