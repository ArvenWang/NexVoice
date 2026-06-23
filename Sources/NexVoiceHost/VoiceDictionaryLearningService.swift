import Foundation
import NexVoiceCore

final class VoiceDictionaryLearningService: Sendable {
    private let session: URLSession
    private let configurationLoader: @Sendable () throws -> DeepSeekFinalRewriteConfiguration
    private let dictionaryFileURL: URL

    init(
        session: URLSession = .shared,
        configurationLoader: @escaping @Sendable () throws -> DeepSeekFinalRewriteConfiguration = {
            DeepSeekFinalRewriteConfiguration(
                credentials: try DeepSeekCredentialStore.load(),
                timeoutSeconds: 12,
                maxOutputTokens: 180
            )
        },
        dictionaryFileURL: URL = VoicePersonalDictionaryStore.defaultFileURL
    ) {
        self.session = session
        self.configurationLoader = configurationLoader
        self.dictionaryFileURL = dictionaryFileURL
    }

    func learnIfNeeded(
        baselineText: String,
        editedText: String,
        originalASRText: String,
        rewrittenText: String,
        context: VoiceRewriteContext
    ) async -> VoiceDictionaryLearningResult? {
        guard let candidate = VoiceDictionaryLearningPolicy.candidate(
            baselineText: baselineText,
            editedText: editedText,
            originalASRText: originalASRText,
            rewrittenText: rewrittenText,
            context: context
        ) else {
            return nil
        }

        return await learn(candidate)
    }

    func learn(_ candidate: VoiceDictionaryCorrectionCandidate) async -> VoiceDictionaryLearningResult? {
        guard let judgment = try? await judge(candidate),
              judgment.shouldSave,
              judgment.confidence >= 0.45,
              let term = normalizedTerm(from: judgment.term ?? candidate.correctedText) else {
            return nil
        }

        let note = judgment.category.map { "\($0)：\(judgment.reason ?? "用户修改后自动学习")" }
            ?? judgment.reason
            ?? "用户修改后自动学习"
        return save(
            term: term,
            observedText: candidate.incorrectText,
            note: note,
            confidence: judgment.confidence,
            contextKey: candidate.contextKey
        )
    }

    private func save(
        term: String,
        observedText: String,
        note: String,
        confidence: Double,
        contextKey: String
    ) -> VoiceDictionaryLearningResult? {
        let existingDictionary = VoicePersonalDictionaryStore.load(fileURL: dictionaryFileURL)
        let wasInserted = !existingDictionary.terms.contains {
            $0.phrase.caseInsensitiveCompare(term) == .orderedSame
        }
        guard let updatedDictionary = try? VoicePersonalDictionaryStore.upsert(
            VoicePersonalDictionaryTerm(
                phrase: term,
                weight: 8,
                note: note,
                aliases: [],
                contextWeights: [contextKey: 1]
            ),
            fileURL: dictionaryFileURL
        ) else {
            return nil
        }
        if observedText.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(term) != .orderedSame {
            _ = try? VoicePersonalDictionaryStore.upsertCorrection(
                VoicePersonalDictionaryCorrection(
                    observedText: observedText,
                    targetTerm: term,
                    note: note,
                    confidence: confidence,
                    contextWeights: [contextKey: 1]
                ),
                fileURL: dictionaryFileURL
            )
        }
        let savedTerm = updatedDictionary.terms.first {
            $0.phrase.caseInsensitiveCompare(term) == .orderedSame
        }
        return VoiceDictionaryLearningResult(
            term: savedTerm?.phrase ?? term,
            alias: nil,
            wasInserted: wasInserted
        )
    }

    private func judge(_ candidate: VoiceDictionaryCorrectionCandidate) async throws -> DictionaryLearningJudgment {
        let configuration = try configurationLoader()
        guard configuration.credentials.isComplete else {
            throw DeepSeekFinalRewriteError.missingAPIKey
        }

        var request = URLRequest(url: configuration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = max(configuration.timeoutSeconds, 12)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DictionaryLearningChatCompletionRequest(
                model: configuration.model,
                messages: [
                    .init(role: "system", content: Self.systemPrompt),
                    .init(role: "user", content: Self.userPrompt(for: candidate))
                ],
                stream: false,
                temperature: 0,
                maxTokens: configuration.maxOutputTokens,
                thinking: .disabled
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DeepSeekFinalRewriteError.invalidResponse
        }
        let completion = try JSONDecoder().decode(DictionaryLearningChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              let jsonData = Self.extractJSONObject(from: content).data(using: .utf8) else {
            throw DeepSeekFinalRewriteError.invalidResponse
        }
        return try JSONDecoder().decode(DictionaryLearningJudgment.self, from: jsonData)
    }

    private func normalizedTerm(from value: String) -> String? {
        let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              term.count <= 64,
              VoiceDictionaryLearningPolicy.isValidDictionaryTerm(term) else {
            return nil
        }
        return term
    }

    private static let systemPrompt = """
    你是语音输入个人词典学习判断器。用户把 NexVoice 输出中的 A 改成 B 后，你判断 B 是否应该进入个人词典。
    只保存 B 中真正应该作为热词的“词或短词组”，例如人名、产品名、项目名、品牌名、公司名、模型名、技术术语、文件名、特殊拼写或固定大小写。
    如果 ASR 把短技术词误听成普通中文短语，例如把 HTML 误听成“是那只天猫”，只要用户改回的是明确技术词，可以保存改正后的技术词 HTML。
    不保存：标点、语序、普通润色、普通同义改写、整句重写、普通句子片段、用户指令、常见普通词。
    term 必须只包含应该保存的词或短词组，不要返回整句，不要返回 A，不要返回别名或错误读音。
    只返回 JSON，不要解释。
    """

    private static func userPrompt(for candidate: VoiceDictionaryCorrectionCandidate) -> String {
        """
        修改：
        A：\(candidate.incorrectText)
        B：\(candidate.correctedText)

        原始 ASR：
        \(candidate.originalASRText)

        NexVoice 改写：
        \(candidate.rewrittenText)

        上下文摘要：
        \(candidate.contextSummary)

        返回 JSON：
        {"shouldSave":true,"term":"B 中应保存的词","category":"product_name/person_name/project_name/company_name/model_name/technical_term/file_name/other","confidence":0.0,"reason":"一句话原因"}
        """
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

struct VoiceDictionaryLearningResult: Equatable, Sendable {
    let term: String
    let alias: String?
    let wasInserted: Bool
}

private struct DictionaryLearningJudgment: Decodable {
    let shouldSave: Bool
    let term: String?
    let category: String?
    let confidence: Double
    let reason: String?
}

private struct DictionaryLearningChatCompletionRequest: Encodable {
    let model: String
    let messages: [Message]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int
    let thinking: Thinking

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Thinking: Encodable {
        let type: String

        static let disabled = Thinking(type: "disabled")
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case temperature
        case maxTokens = "max_tokens"
        case thinking
    }
}

private struct DictionaryLearningChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
