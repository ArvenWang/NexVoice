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
    private let diagnosticsLogger = TencentCloudASRDiagnosticsLogger.shared
    private let lock = NSLock()
    private var stateStorage: State = .idle
    private var eventHandler: (@Sendable (VoiceRealtimeEvent) -> Void)?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var transcriptBuffer = TencentCloudRealtimeTranscriptBuffer()
    private var currentSessionID: String?
    private var startedAt: Date?
    private var finishRequestedAt: Date?
    private var hasReceivedTranscript = false
    private var didRequestFinish = false

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
        personalDictionary: VoicePersonalDictionary = VoicePersonalDictionary(),
        rewriteContext: VoiceRewriteContext? = nil,
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
            hotwordList: personalDictionary.hotwordList(for: rewriteContext)
        )
        let url = try cloudConfiguration.signedWebSocketURL()
        let task = session.webSocketTask(with: url)
        let sessionID = UUID().uuidString
        let startedAt = Date()
        let frameDurationMilliseconds = 40

        lock.withLock {
            self.eventHandler = onEvent
            self.transcriptBuffer = TencentCloudRealtimeTranscriptBuffer()
            self.currentSessionID = sessionID
            self.startedAt = startedAt
            self.finishRequestedAt = nil
            self.hasReceivedTranscript = false
            self.didRequestFinish = false
            self.webSocketTask = task
            self.stateStorage = .running
        }
        logASR(
            sessionID: sessionID,
            event: "started",
            engineModelType: cloudConfiguration.engineModelType,
            frameDurationMilliseconds: frameDurationMilliseconds,
            hasHotwords: personalDictionary.hotwordList != nil,
            hotwordCount: personalDictionary.terms.count
        )

        task.resume()
        receiveTask = Task { [weak self, weak task] in
            guard let task else { return }
            await self?.receiveLoop(task: task)
        }

        do {
            try captureService.start(
                configuration: AudioCaptureConfiguration(frameDurationMilliseconds: frameDurationMilliseconds)
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
        let snapshot = lock.withLock { () -> (String?, Date?, Date?) in
            finishRequestedAt = Date()
            return (currentSessionID, startedAt, finishRequestedAt)
        }
        if let sessionID = snapshot.0 {
            logASR(
                sessionID: sessionID,
                event: "finish_requested",
                latencyMs: snapshot.1.map { Self.milliseconds(from: $0, to: snapshot.2 ?? Date()) }
            )
        }
        lock.withLock {
            stateStorage = .finishing
            didRequestFinish = true
        }
        webSocketTask?.send(.string(#"{"type":"end"}"#)) { [weak self] error in
            guard let error else { return }
            guard self?.shouldTreatTransportErrorAsNoSpeech() != true else {
                self?.complete()
                return
            }
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
            guard !shouldTreatTransportErrorAsNoSpeech() else {
                complete()
                return
            }
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
            let firstTranscriptSnapshot = lock.withLock { () -> (String?, Date?, Bool) in
                let isFirstTranscript = !hasReceivedTranscript
                hasReceivedTranscript = true
                return (currentSessionID, startedAt, isFirstTranscript)
            }
            if firstTranscriptSnapshot.2,
               let sessionID = firstTranscriptSnapshot.0,
               let startedAt = firstTranscriptSnapshot.1 {
                logASR(
                    sessionID: sessionID,
                    event: "first_partial",
                    latencyMs: Self.milliseconds(from: startedAt, to: Date()),
                    partialCharacters: partialText.count,
                    partialPreview: partialText
                )
            }
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
                handler: eventHandler,
                sessionID: currentSessionID,
                startedAt: startedAt,
                finishRequestedAt: finishRequestedAt
            )
        }
        cleanup(cancelWebSocket: true)

        if snapshot.text.isEmpty {
            if let sessionID = snapshot.sessionID {
                logASR(
                    sessionID: sessionID,
                    event: "no_speech",
                    latencyMs: snapshot.startedAt.map { Self.milliseconds(from: $0, to: Date()) },
                    finishToFinalMs: snapshot.finishRequestedAt.map { Self.milliseconds(from: $0, to: Date()) }
                )
            }
            snapshot.handler?(.failed(message: VoiceFinalTextPolicy.noRecognizedSpeechMessage))
        } else {
            if let sessionID = snapshot.sessionID {
                logASR(
                    sessionID: sessionID,
                    event: "final",
                    latencyMs: snapshot.startedAt.map { Self.milliseconds(from: $0, to: Date()) },
                    finishToFinalMs: snapshot.finishRequestedAt.map { Self.milliseconds(from: $0, to: Date()) },
                    finalCharacters: snapshot.text.count,
                    finalPreview: snapshot.text
                )
            }
            snapshot.handler?(.finalTranscript(snapshot.text))
            snapshot.handler?(.sessionEnded)
        }
    }

    private func fail(message: String) {
        captureService.stop()
        let snapshot = lock.withLock {
            (
                handler: eventHandler,
                sessionID: currentSessionID,
                startedAt: startedAt,
                finishRequestedAt: finishRequestedAt
            )
        }
        cleanup(cancelWebSocket: true)
        if let sessionID = snapshot.sessionID {
            logASR(
                sessionID: sessionID,
                event: "failed",
                latencyMs: snapshot.startedAt.map { Self.milliseconds(from: $0, to: Date()) },
                finishToFinalMs: snapshot.finishRequestedAt.map { Self.milliseconds(from: $0, to: Date()) },
                errorMessage: message
            )
        }
        snapshot.handler?(.failed(message: message))
    }

    private func shouldTreatTransportErrorAsNoSpeech() -> Bool {
        lock.withLock {
            didRequestFinish && !hasReceivedTranscript
        }
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
            currentSessionID = nil
            startedAt = nil
            finishRequestedAt = nil
            hasReceivedTranscript = false
            didRequestFinish = false
            return task
        }
        if cancelWebSocket {
            task?.cancel(with: .normalClosure, reason: nil)
        }
        receiveTask?.cancel()
        receiveTask = nil
    }

    private func logASR(
        sessionID: String,
        event: String,
        engineModelType: String? = nil,
        frameDurationMilliseconds: Int? = nil,
        hasHotwords: Bool? = nil,
        hotwordCount: Int? = nil,
        latencyMs: Int? = nil,
        finishToFinalMs: Int? = nil,
        partialCharacters: Int? = nil,
        finalCharacters: Int? = nil,
        partialPreview: String? = nil,
        finalPreview: String? = nil,
        errorMessage: String? = nil
    ) {
        Task {
            await diagnosticsLogger.log(
                TencentCloudASRDiagnosticEvent(
                    sessionID: sessionID,
                    event: event,
                    engineModelType: engineModelType,
                    frameDurationMilliseconds: frameDurationMilliseconds,
                    hasHotwords: hasHotwords,
                    hotwordCount: hotwordCount,
                    latencyMs: latencyMs,
                    finishToFinalMs: finishToFinalMs,
                    partialCharacters: partialCharacters,
                    finalCharacters: finalCharacters,
                    partialPreview: partialPreview,
                    finalPreview: finalPreview,
                    errorMessage: errorMessage
                )
            )
        }
    }

    private static func milliseconds(since startDate: Date) -> Int {
        milliseconds(from: startDate, to: Date())
    }

    private static func milliseconds(from startDate: Date, to endDate: Date) -> Int {
        Int(endDate.timeIntervalSince(startDate) * 1000)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
