@preconcurrency import AVFAudio
import Foundation

public enum AudioCaptureServiceError: Error, Equatable {
    case alreadyRunning
    case inputFormatUnavailable
    case outputFormatUnavailable
    case converterUnavailable
}

public final class AudioCaptureService {
    public enum State: Equatable {
        case idle
        case running
    }

    private let engine: AVAudioEngine
    private let callbackQueue: DispatchQueue
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var stateStorage: State = .idle

    public init(
        engine: AVAudioEngine = AVAudioEngine(),
        callbackQueue: DispatchQueue = DispatchQueue(label: "com.nexvoice.audio-capture.frames")
    ) {
        self.engine = engine
        self.callbackQueue = callbackQueue
    }

    public var state: State {
        stateStorage
    }

    public func start(
        configuration: AudioCaptureConfiguration = AudioCaptureConfiguration(),
        onFrame: @escaping @Sendable (AudioPCMFrame) -> Void
    ) throws {
        guard stateStorage == .idle else { throw AudioCaptureServiceError.alreadyRunning }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureServiceError.inputFormatUnavailable
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: configuration.targetSampleRate,
            channels: AVAudioChannelCount(configuration.channelCount),
            interleaved: true
        ) else {
            throw AudioCaptureServiceError.outputFormatUnavailable
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioCaptureServiceError.converterUnavailable
        }

        self.converter = converter
        self.outputFormat = outputFormat
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(configuration.targetFrameSampleCount),
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self, let frame = self.convert(buffer: buffer, configuration: configuration) else {
                return
            }
            self.callbackQueue.async {
                onFrame(frame)
            }
        }

        engine.prepare()
        try engine.start()
        stateStorage = .running
    }

    public func stop() {
        guard stateStorage == .running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        outputFormat = nil
        stateStorage = .idle
    }

    private func convert(buffer: AVAudioPCMBuffer, configuration: AudioCaptureConfiguration) -> AudioPCMFrame? {
        guard let converter, let outputFormat else { return nil }

        return Self.convertBuffer(
            buffer,
            converter: converter,
            outputFormat: outputFormat,
            configuration: configuration
        )
    }

    static func convertBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat,
        configuration: AudioCaptureConfiguration
    ) -> AudioPCMFrame? {
        let outputCapacity = Self.outputFrameCapacity(
            inputFrameLength: buffer.frameLength,
            inputSampleRate: buffer.format.sampleRate,
            outputSampleRate: outputFormat.sampleRate
        )
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return nil
        }

        let inputProvider = AudioConverterInputProvider(buffer: buffer)
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            inputProvider.nextBuffer(outStatus: outStatus)
        }

        if status == .error || conversionError != nil {
            return nil
        }
        guard outputBuffer.frameLength > 0, let channelData = outputBuffer.int16ChannelData else {
            return nil
        }

        let byteCount = Int(outputBuffer.frameLength) * configuration.channelCount * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: byteCount)
        return AudioPCMFrame(
            pcm16LittleEndian: data,
            sampleRate: configuration.targetSampleRate,
            channelCount: configuration.channelCount
        )
    }

    static func outputFrameCapacity(
        inputFrameLength: AVAudioFrameCount,
        inputSampleRate: Double,
        outputSampleRate: Double
    ) -> AVAudioFrameCount {
        guard inputFrameLength > 0, inputSampleRate > 0, outputSampleRate > 0 else { return 1 }
        let convertedFrameCount = AVAudioFrameCount(
            (Double(inputFrameLength) * outputSampleRate / inputSampleRate).rounded(.up)
        ) + 1
        return max(inputFrameLength, convertedFrameCount, 1)
    }
}

private final class AudioConverterInputProvider: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var didProvideInput = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func nextBuffer(outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        if didProvideInput {
            outStatus.pointee = .noDataNow
            return nil
        }
        didProvideInput = true
        outStatus.pointee = .haveData
        return buffer
    }
}
