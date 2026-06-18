@preconcurrency import AVFoundation
import Foundation
import NexVoiceCore
import WhisperKit

final class WhisperKitLocalTranscriptionService: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case idle
        case running
        case finishing
    }

    private let captureService: AudioCaptureService
    private let lock = NSLock()
    private var stateStorage: State = .idle
    private var eventHandler: (@Sendable (VoiceRealtimeEvent) -> Void)?
    private var configuration = LocalWhisperTranscriptionConfiguration()
    private var recordedPCM = Data()
    private var sampleRate = 16_000
    private var channelCount = 1
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?
    private var transcriptionTask: Task<Void, Never>?
    private let transcriptionTimeoutSeconds: TimeInterval
    private let senseVoiceTranscriber = SenseVoiceCommandTranscriber()

    init(
        captureService: AudioCaptureService = AudioCaptureService(),
        transcriptionTimeoutSeconds: TimeInterval = 90
    ) {
        self.captureService = captureService
        self.transcriptionTimeoutSeconds = transcriptionTimeoutSeconds
    }

    var state: State {
        lock.withLock { stateStorage }
    }

    func start(
        configuration: LocalWhisperTranscriptionConfiguration = LocalWhisperTranscriptionConfiguration(),
        onEvent: @escaping @Sendable (VoiceRealtimeEvent) -> Void
    ) throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw LocalWhisperTranscriptionError.microphonePermissionMissing
        }
        guard state == .idle else {
            throw LocalWhisperTranscriptionError.alreadyRunning
        }

        lock.withLock {
            self.configuration = configuration
            self.eventHandler = onEvent
            self.recordedPCM.removeAll(keepingCapacity: true)
            self.sampleRate = 16_000
            self.channelCount = 1
            self.stateStorage = .running
        }

        do {
            try captureService.start(configuration: AudioCaptureConfiguration()) { [weak self] frame in
                self?.append(frame)
            }
            emit(.sessionStarted)
        } catch {
            cleanupRecordingState()
            throw error
        }
    }

    func finish() {
        guard state == .running else { return }
        captureService.stop()
        setState(.finishing)

        let snapshot = lock.withLock {
            (
                configuration: self.configuration,
                pcm: self.recordedPCM,
                sampleRate: self.sampleRate,
                channelCount: self.channelCount,
                eventHandler: self.eventHandler
            )
        }

        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            await self?.transcribe(snapshot)
        }
    }

    func stop() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        captureService.stop()
        cleanupRecordingState()
    }

    private func append(_ frame: AudioPCMFrame) {
        lock.withLock {
            recordedPCM.append(frame.pcm16LittleEndian)
            sampleRate = Int(frame.sampleRate)
            channelCount = frame.channelCount
        }
        emit(.audioLevelUpdated(VoiceAudioLevelMeter.normalizedLevel(
            pcm16LittleEndian: frame.pcm16LittleEndian
        )))
    }

    private func transcribe(
        _ snapshot: (
            configuration: LocalWhisperTranscriptionConfiguration,
            pcm: Data,
            sampleRate: Int,
            channelCount: Int,
            eventHandler: (@Sendable (VoiceRealtimeEvent) -> Void)?
        )
    ) async {
        do {
            let wavData = try AudioWaveFileWriter.wavData(
                pcm16LittleEndian: snapshot.pcm,
                sampleRate: snapshot.sampleRate,
                channelCount: snapshot.channelCount
            )
            let audioURL = try writeTemporaryWavFile(wavData)
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let text = try await withTranscriptionTimeout {
                try await self.transcribe(audioURL: audioURL, configuration: snapshot.configuration)
            }

            guard !Task.isCancelled else {
                cleanupRecordingState()
                return
            }
            cleanupRecordingState()
            if text.isEmpty {
                snapshot.eventHandler?(.failed(message: VoiceFinalTextPolicy.noRecognizedSpeechMessage))
            } else {
                snapshot.eventHandler?(.finalTranscript(text))
                snapshot.eventHandler?(.sessionEnded)
            }
        } catch AudioWaveFileWriter.Error.emptyAudio {
            cleanupRecordingState()
            snapshot.eventHandler?(.failed(message: LocalWhisperTranscriptionError.noRecordedAudio.localizedDescription))
        } catch LocalWhisperTranscriptionError.transcriptionTimedOut {
            cleanupRecordingState()
            snapshot.eventHandler?(.failed(message: LocalWhisperTranscriptionError.transcriptionTimedOut(seconds: transcriptionTimeoutSeconds).localizedDescription))
        } catch {
            cleanupRecordingState()
            snapshot.eventHandler?(.failed(message: LocalWhisperTranscriptionError.modelUnavailable(error.localizedDescription).localizedDescription))
        }
    }

    private func transcribe(
        audioURL: URL,
        configuration: LocalWhisperTranscriptionConfiguration
    ) async throws -> String {
        switch configuration.backend {
        case .tencentCloudRealtime:
            throw LocalWhisperTranscriptionError.modelUnavailable("腾讯云实时 ASR 需要使用实时 WebSocket 服务。")
        case .senseVoice:
            return try await senseVoiceTranscriber.transcribe(
                audioURL: audioURL,
                configuration: LocalSenseVoiceTranscriptionConfiguration(language: configuration.language)
            )
        case .whisperKit:
            let whisper = try await self.whisperKit(for: configuration)
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: configuration.whisperLanguageCode,
                temperature: 0,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: false
            )
            let results = try await whisper.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )
            let merged = TranscriptionUtilities.mergeTranscriptionResults(results)
            return merged.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func withTranscriptionTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask { [transcriptionTimeoutSeconds] in
                let nanoseconds = UInt64(max(1, transcriptionTimeoutSeconds) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw LocalWhisperTranscriptionError.transcriptionTimedOut(seconds: transcriptionTimeoutSeconds)
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }
    }

    private func whisperKit(for configuration: LocalWhisperTranscriptionConfiguration) async throws -> WhisperKit {
        if let whisperKit, loadedModelName == configuration.modelName {
            return whisperKit
        }

        let config = WhisperKitConfig(
            model: configuration.modelName,
            verbose: false,
            prewarm: false,
            load: true,
            download: true,
            useBackgroundDownloadSession: false
        )
        let whisperKit = try await WhisperKit(config)
        self.whisperKit = whisperKit
        loadedModelName = configuration.modelName
        return whisperKit
    }

    private func writeTemporaryWavFile(_ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NexVoiceLocalWhisper", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func setState(_ state: State) {
        lock.withLock {
            stateStorage = state
        }
    }

    private func emit(_ event: VoiceRealtimeEvent) {
        lock.withLock { eventHandler }?(event)
    }

    private func cleanupRecordingState() {
        lock.withLock {
            stateStorage = .idle
            eventHandler = nil
            recordedPCM.removeAll(keepingCapacity: false)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
