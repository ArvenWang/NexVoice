import Foundation

public struct TencentCloudRealtimeASRMessage: Decodable, Equatable, Sendable {
    public let code: Int
    public let message: String
    public let voiceID: String?
    public let messageID: String?
    public let result: TencentCloudRealtimeASRResult?
    public let final: Int?

    public enum CodingKeys: String, CodingKey {
        case code
        case message
        case voiceID = "voice_id"
        case messageID = "message_id"
        case result
        case final
    }

    public static func decode(from data: Data) throws -> TencentCloudRealtimeASRMessage {
        try JSONDecoder().decode(TencentCloudRealtimeASRMessage.self, from: data)
    }

    public var isSuccess: Bool {
        code == 0
    }

    public var isStreamFinal: Bool {
        final == 1
    }
}

public struct TencentCloudRealtimeASRResult: Decodable, Equatable, Sendable {
    public let sliceType: SliceType
    public let index: Int
    public let startTime: Int
    public let endTime: Int
    public let voiceText: String
    public let wordSize: Int
    public let wordList: [Word]

    public enum CodingKeys: String, CodingKey {
        case sliceType = "slice_type"
        case index
        case startTime = "start_time"
        case endTime = "end_time"
        case voiceText = "voice_text_str"
        case wordSize = "word_size"
        case wordList = "word_list"
    }

    public enum SliceType: Int, Decodable, Equatable, Sendable {
        case started = 0
        case recognizing = 1
        case ended = 2
    }

    public struct Word: Decodable, Equatable, Sendable {
        public let word: String
        public let startTime: Int
        public let endTime: Int
        public let stableFlag: Int?

        public enum CodingKeys: String, CodingKey {
            case word
            case startTime = "start_time"
            case endTime = "end_time"
            case stableFlag = "stable_flag"
        }
    }

    public var isStable: Bool {
        sliceType == .ended
    }
}

public struct TencentCloudRealtimeTranscriptBuffer: Sendable {
    private var stableSegments: [Int: String] = [:]
    private var latestUnstableSegment: (index: Int, text: String)?

    public init() {}

    public mutating func apply(_ message: TencentCloudRealtimeASRMessage) throws {
        guard message.isSuccess else { return }
        guard let result = message.result else { return }

        switch result.sliceType {
        case .started:
            latestUnstableSegment = (result.index, result.voiceText)
        case .recognizing:
            latestUnstableSegment = (result.index, result.voiceText)
        case .ended:
            stableSegments[result.index] = result.voiceText
            if latestUnstableSegment?.index == result.index {
                latestUnstableSegment = nil
            }
        }
    }

    public var committedText: String {
        stableSegments.keys.sorted()
            .compactMap { stableSegments[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined()
    }

    public var bestAvailableText: String {
        let committed = committedText
        guard let latestUnstableSegment else { return committed }
        let unstable = latestUnstableSegment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unstable.isEmpty else { return committed }
        if committed.isEmpty { return unstable }
        return committed + unstable
    }
}
