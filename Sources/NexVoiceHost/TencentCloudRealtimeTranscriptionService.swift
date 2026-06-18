@preconcurrency import AVFoundation
@preconcurrency import Foundation
import NexVoiceCore

final class TencentCloudRealtimeTranscriptionService: @unchecked Sendable {
    enum State: Equatable, Sendable {
        case idle
        case running
        case finishing
    }

    private let captureService: AudioCaptureService
    private let session: URLSession
    private let credentialLoader: @Sendable () throws -> TencentCloudASRCredentials
    private let lock = NSLock()
    private var stateStorage: State = .idle
    private var eventHandler: (@Sendable (VoiceRealtimeEvent) -> Void)?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var transcriptBuffer = TencentCloudRealtimeTranscriptBuffer()

    init(
        captureService: AudioCaptureService = AudioCaptureService(),
        session: URLSession = .shared,
        credentialLoader: @escaping @Sendable () throws -> TencentCloudASRCredentials = {
            try TencentCloudASRCredentialStore.load()
        }
    ) {
        self.captureService = captureService
        self.session = session
        self.credentialLoader = credentialLoader
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

        let credentials = try credentialLoader()
        let cloudConfiguration = TencentCloudRealtimeASRConfiguration(
            credentials: credentials,
            language: configuration.language
        )
        let url = try cloudConfiguration.signedWebSocketURL()
        let task = session.webSocketTask(with: url)

        lock.withLock {
            self.eventHandler = onEvent
            self.transcriptBuffer = TencentCloudRealtimeTranscriptBuffer()
            self.webSocketTask = task
            self.stateStorage = .running
        }

        task.resume()
        receiveTask = Task { [weak self, weak task] in
            guard let task else { return }
            await self?.receiveLoop(task: task)
        }

        do {
            try captureService.start(
                configuration: AudioCaptureConfiguration(frameDurationMilliseconds: 200)
            ) { [weak self] frame in
                self?.send(frame)
            }
            emit(.sessionStarted)
        } catch {
            fail(message: error.localizedDescription)
            throw error
        }
    }

    func finish() {
        guard state == .running else { return }
        captureService.stop()
        lock.withLock {
            stateStorage = .finishing
        }
        webSocketTask?.send(.string(#"{"type":"end"}"#)) { [weak self] error in
            guard let error else { return }
            self?.fail(message: "腾讯云 ASR 结束识别失败：\(error.localizedDescription)")
        }
    }

    func stop() {
        receiveTask?.cancel()
        captureService.stop()
        cleanup(cancelWebSocket: true)
    }

    private func send(_ frame: AudioPCMFrame) {
        guard state == .running else { return }
        emit(.audioLevelUpdated(VoiceAudioLevelMeter.normalizedLevel(
            pcm16LittleEndian: frame.pcm16LittleEndian
        )))
        webSocketTask?.send(.data(frame.pcm16LittleEndian)) { [weak self] error in
            guard let error else { return }
            self?.fail(message: "腾讯云 ASR 音频发送失败：\(error.localizedDescription)")
        }
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await receiveMessage(from: task)
                try handle(message)
            }
        } catch {
            guard !Task.isCancelled, state != .idle else { return }
            fail(message: "腾讯云 ASR 连接失败：\(error.localizedDescription)")
        }
    }

    private func receiveMessage(from task: URLSessionWebSocketTask) async throws -> URLSessionWebSocketTask.Message {
        try await withCheckedThrowingContinuation { continuation in
            task.receive { result in
                continuation.resume(with: result)
            }
        }
    }

    private func handle(_ webSocketMessage: URLSessionWebSocketTask.Message) throws {
        let data: Data
        switch webSocketMessage {
        case .string(let string):
            data = Data(string.utf8)
        case .data(let messageData):
            data = messageData
        @unknown default:
            return
        }

        let message = try TencentCloudRealtimeASRMessage.decode(from: data)
        guard message.isSuccess else {
            fail(message: "腾讯云 ASR 错误 \(message.code)：\(message.message)")
            return
        }

        var partialText: String?
        var isStable = false
        lock.withLock {
            try? transcriptBuffer.apply(message)
            if let result = message.result {
                partialText = transcriptBuffer.bestAvailableText
                isStable = result.isStable
            }
        }
        if let partialText, !partialText.isEmpty {
            emit(.partialTranscript(partialText, isStable: isStable))
        }

        if message.isStreamFinal {
            complete()
        }
    }

    private func complete() {
        captureService.stop()
        let snapshot = lock.withLock {
            (
                text: transcriptBuffer.bestAvailableText.trimmingCharacters(in: .whitespacesAndNewlines),
                handler: eventHandler
            )
        }
        cleanup(cancelWebSocket: true)

        if snapshot.text.isEmpty {
            snapshot.handler?(.failed(message: VoiceFinalTextPolicy.noRecognizedSpeechMessage))
        } else {
            snapshot.handler?(.finalTranscript(snapshot.text))
            snapshot.handler?(.sessionEnded)
        }
    }

    private func fail(message: String) {
        captureService.stop()
        let handler = lock.withLock { eventHandler }
        cleanup(cancelWebSocket: true)
        handler?(.failed(message: message))
    }

    private func emit(_ event: VoiceRealtimeEvent) {
        lock.withLock { eventHandler }?(event)
    }

    private func cleanup(cancelWebSocket: Bool) {
        let task = lock.withLock { () -> URLSessionWebSocketTask? in
            let task = webSocketTask
            stateStorage = .idle
            eventHandler = nil
            webSocketTask = nil
            transcriptBuffer = TencentCloudRealtimeTranscriptBuffer()
            return task
        }
        if cancelWebSocket {
            task?.cancel(with: .normalClosure, reason: nil)
        }
        receiveTask?.cancel()
        receiveTask = nil
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
