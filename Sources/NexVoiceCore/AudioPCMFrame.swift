import Foundation

public struct AudioPCMFrame: Equatable, Sendable {
    public let pcm16LittleEndian: Data
    public let sampleRate: Double
    public let channelCount: Int

    public init(pcm16LittleEndian: Data, sampleRate: Double, channelCount: Int) {
        self.pcm16LittleEndian = pcm16LittleEndian
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    public var isEmpty: Bool {
        pcm16LittleEndian.isEmpty
    }

    public var durationSeconds: Double {
        guard sampleRate > 0, channelCount > 0, !pcm16LittleEndian.isEmpty else {
            return 0
        }
        let bytesPerFrame = MemoryLayout<Int16>.size * channelCount
        guard bytesPerFrame > 0 else { return 0 }
        let sampleFrames = Double(pcm16LittleEndian.count) / Double(bytesPerFrame)
        return sampleFrames / sampleRate
    }
}
