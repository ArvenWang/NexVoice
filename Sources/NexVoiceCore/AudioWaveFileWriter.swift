import Foundation

public enum AudioWaveFileWriter {
    public enum Error: Swift.Error, Equatable {
        case emptyAudio
        case invalidFormat
    }

    public static func wavData(
        pcm16LittleEndian: Data,
        sampleRate: Int,
        channelCount: Int
    ) throws -> Data {
        guard !pcm16LittleEndian.isEmpty else { throw Error.emptyAudio }
        guard sampleRate > 0, channelCount > 0 else { throw Error.invalidFormat }

        let bitsPerSample = 16
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let chunkSize = 36 + pcm16LittleEndian.count

        var data = Data()
        data.appendASCII("RIFF")
        data.appendUInt32LE(UInt32(chunkSize))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendUInt32LE(16)
        data.appendUInt16LE(1)
        data.appendUInt16LE(UInt16(channelCount))
        data.appendUInt32LE(UInt32(sampleRate))
        data.appendUInt32LE(UInt32(byteRate))
        data.appendUInt16LE(UInt16(blockAlign))
        data.appendUInt16LE(UInt16(bitsPerSample))
        data.appendASCII("data")
        data.appendUInt32LE(UInt32(pcm16LittleEndian.count))
        data.append(pcm16LittleEndian)
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(contentsOf: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff)
        ])
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 24) & 0xff)
        ])
    }
}
