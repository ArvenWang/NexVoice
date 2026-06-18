import Foundation

public enum VoiceAudioLevelMeter {
    public static func normalizedLevel(samples: [Float]) -> Double {
        let sumOfSquares = samples.reduce(0) { partialResult, sample in
            partialResult + Double(sample * sample)
        }
        return normalizedLevel(sumOfSquares: sumOfSquares, sampleCount: samples.count)
    }

    public static func normalizedLevel(pcm16LittleEndian: Data) -> Double {
        let sampleCount = pcm16LittleEndian.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }

        var sumOfSquares: Double = 0
        pcm16LittleEndian.withUnsafeBytes { rawBuffer in
            guard let pointer = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
            for index in 0..<sampleCount {
                let sample = Double(Int16(littleEndian: pointer[index])) / Double(Int16.max)
                sumOfSquares += sample * sample
            }
        }
        return normalizedLevel(sumOfSquares: sumOfSquares, sampleCount: sampleCount)
    }

    public static func normalizedLevel(sumOfSquares: Double, sampleCount: Int) -> Double {
        guard sampleCount > 0, sumOfSquares > 0 else { return 0 }
        let rms = sqrt(sumOfSquares / Double(sampleCount))
        let noiseFloor = 0.003
        guard rms > noiseFloor else { return 0 }
        let gainedLevel = (rms - noiseFloor) * 24
        return min(1, max(0, pow(gainedLevel, 0.72)))
    }
}
