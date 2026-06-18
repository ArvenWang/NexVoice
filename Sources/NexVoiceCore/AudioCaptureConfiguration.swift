import Foundation

public struct AudioCaptureConfiguration: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case invalidSampleRate
        case invalidChannelCount
        case invalidFrameDuration
    }

    public let targetSampleRate: Double
    public let channelCount: Int
    public let frameDurationMilliseconds: Int

    public init(
        targetSampleRate: Double = 16_000,
        channelCount: Int = 1,
        frameDurationMilliseconds: Int = 100
    ) {
        self.targetSampleRate = targetSampleRate
        self.channelCount = channelCount
        self.frameDurationMilliseconds = frameDurationMilliseconds
    }

    public static func validated(
        targetSampleRate: Double,
        channelCount: Int,
        frameDurationMilliseconds: Int
    ) throws -> AudioCaptureConfiguration {
        guard targetSampleRate > 0 else { throw ValidationError.invalidSampleRate }
        guard channelCount > 0 else { throw ValidationError.invalidChannelCount }
        guard frameDurationMilliseconds > 0 else { throw ValidationError.invalidFrameDuration }
        return AudioCaptureConfiguration(
            targetSampleRate: targetSampleRate,
            channelCount: channelCount,
            frameDurationMilliseconds: frameDurationMilliseconds
        )
    }

    public var targetFrameSampleCount: Int {
        Int((targetSampleRate * Double(frameDurationMilliseconds) / 1_000).rounded())
    }
}
