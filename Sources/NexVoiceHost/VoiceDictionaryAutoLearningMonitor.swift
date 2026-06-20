import AppKit
import NexVoiceCore

@MainActor
final class VoiceDictionaryAutoLearningMonitor {
    private let textReader: FocusedTextInserter
    private let learningService: VoiceDictionaryLearningService
    private let onLearningStarted: @MainActor () -> Void
    private let onLearningFinished: @MainActor (VoiceDictionaryLearningResult?) -> Void
    private var observationTask: Task<Void, Never>?
    private let logFileURL: URL

    init(
        textReader: FocusedTextInserter,
        learningService: VoiceDictionaryLearningService = VoiceDictionaryLearningService(),
        onLearningStarted: @escaping @MainActor () -> Void = {},
        onLearningFinished: @escaping @MainActor (VoiceDictionaryLearningResult?) -> Void = { _ in },
        logFileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("NexVoice", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DictionaryLearning.jsonl")
    ) {
        self.textReader = textReader
        self.learningService = learningService
        self.onLearningStarted = onLearningStarted
        self.onLearningFinished = onLearningFinished
        self.logFileURL = logFileURL
    }

    func cancel() {
        observationTask?.cancel()
        observationTask = nil
    }

    func observePossibleEdit(
        insertedText: String,
        originalASRText: String,
        rewrittenText: String,
        context: VoiceRewriteContext,
        targetApplication: NSRunningApplication?
    ) {
        cancel()
        observationTask = Task { [weak self, weak targetApplication] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }

            let baseline = self.textReader.focusedTextPreview(in: targetApplication) ?? insertedText
            var lastObservedText = baseline
            var learnedCandidateKeys = Set<String>()
            log(
                event: "observation_started",
                insertedCharacters: insertedText.count,
                baselineCharacters: baseline.count,
                appName: targetApplication?.localizedName
            )

            let observationEndsAt = Date().addingTimeInterval(60)
            var pendingCandidate: VoiceDictionaryCorrectionCandidate?
            var checkpoint = 0

            while Date() < observationEndsAt {
                checkpoint += 1
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                guard let editedText = self.textReader.focusedTextPreview(in: targetApplication) else {
                    if let pendingCandidate {
                        log(
                            event: "commit_detected",
                            insertedCharacters: insertedText.count,
                            baselineCharacters: baseline.count,
                            currentCharacters: lastObservedText.count,
                            message: "snapshot_unavailable_after_candidate",
                            appName: targetApplication?.localizedName
                        )
                        self.startLearning(
                            pendingCandidate,
                            insertedCharacters: insertedText.count,
                            baselineCharacters: baseline.count,
                            currentCharacters: lastObservedText.count,
                            appName: targetApplication?.localizedName,
                            learnedCandidateKeys: &learnedCandidateKeys
                        )
                        return
                    }
                    log(
                        event: "snapshot_unavailable",
                        insertedCharacters: insertedText.count,
                        baselineCharacters: baseline.count,
                        message: "checkpoint:\(checkpoint)",
                        appName: targetApplication?.localizedName
                    )
                    continue
                }

                if let pendingCandidate,
                   self.looksLikeCommittedInputReplacement(editedText, baseline: baseline, candidate: pendingCandidate) {
                    log(
                        event: "commit_detected",
                        insertedCharacters: insertedText.count,
                        baselineCharacters: baseline.count,
                        currentCharacters: editedText.count,
                        message: "short_or_unrelated_text_after_candidate",
                        appName: targetApplication?.localizedName
                    )
                    self.startLearning(
                        pendingCandidate,
                        insertedCharacters: insertedText.count,
                        baselineCharacters: baseline.count,
                        currentCharacters: lastObservedText.count,
                        appName: targetApplication?.localizedName,
                        learnedCandidateKeys: &learnedCandidateKeys
                    )
                    return
                }

                if editedText != lastObservedText {
                    lastObservedText = editedText
                    log(
                        event: "text_changed",
                        insertedCharacters: insertedText.count,
                        baselineCharacters: baseline.count,
                        currentCharacters: editedText.count,
                        message: "checkpoint:\(checkpoint)",
                        appName: targetApplication?.localizedName
                    )

                    if let candidate = VoiceDictionaryLearningPolicy.candidate(
                        baselineText: baseline,
                        editedText: editedText,
                        originalASRText: originalASRText,
                        rewrittenText: rewrittenText,
                        context: context
                    ) {
                        pendingCandidate = candidate
                        log(
                            event: "candidate_pending",
                            insertedCharacters: insertedText.count,
                            baselineCharacters: baseline.count,
                            currentCharacters: editedText.count,
                            message: "\(candidate.incorrectText) -> \(candidate.correctedText)",
                            appName: targetApplication?.localizedName
                        )
                    } else {
                        log(
                            event: "candidate_rejected_locally",
                            insertedCharacters: insertedText.count,
                            baselineCharacters: baseline.count,
                            currentCharacters: editedText.count,
                            message: "checkpoint:\(checkpoint)",
                            appName: targetApplication?.localizedName
                        )
                    }
                    continue
                }

            }
            log(
                event: "observation_finished",
                insertedCharacters: insertedText.count,
                baselineCharacters: baseline.count,
                appName: targetApplication?.localizedName
            )
        }
    }

    private func startLearning(
        _ candidate: VoiceDictionaryCorrectionCandidate,
        insertedCharacters: Int,
        baselineCharacters: Int,
        currentCharacters: Int,
        appName: String?,
        learnedCandidateKeys: inout Set<String>
    ) {
        let candidateKey = "\(candidate.incorrectText.lowercased())\u{1F}\(candidate.correctedText.lowercased())"
        guard learnedCandidateKeys.insert(candidateKey).inserted else {
            return
        }

        log(
            event: "candidate_detected",
            insertedCharacters: insertedCharacters,
            baselineCharacters: baselineCharacters,
            currentCharacters: currentCharacters,
            message: "\(candidate.incorrectText) -> \(candidate.correctedText)",
            appName: appName
        )
        onLearningStarted()
        Task.detached { [learningService, onLearningFinished] in
            let result = await learningService.learn(candidate)
            await MainActor.run {
                onLearningFinished(result)
            }
        }
    }

    private func looksLikeCommittedInputReplacement(
        _ text: String,
        baseline: String,
        candidate: VoiceDictionaryCorrectionCandidate
    ) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }
        if normalized.localizedCaseInsensitiveContains(candidate.correctedText) {
            return false
        }

        let shortReplacementLimit = max(8, baseline.count / 2)
        return normalized.count <= shortReplacementLimit
    }

    private func log(
        event: String,
        insertedCharacters: Int,
        baselineCharacters: Int? = nil,
        currentCharacters: Int? = nil,
        message: String? = nil,
        appName: String? = nil
    ) {
        var payload: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "event": event,
            "insertedCharacters": insertedCharacters
        ]
        if let baselineCharacters {
            payload["baselineCharacters"] = baselineCharacters
        }
        if let currentCharacters {
            payload["currentCharacters"] = currentCharacters
        }
        if let message {
            payload["message"] = message
        }
        if let appName {
            payload["appName"] = appName
        }

        do {
            try FileManager.default.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
        } catch {
            return
        }
    }
}
