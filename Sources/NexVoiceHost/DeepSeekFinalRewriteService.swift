import Foundation
import NexVoiceCore

enum DeepSeekFinalRewriteError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyRewrite
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "DeepSeek API Key 未配置。"
        case .invalidResponse:
            return "DeepSeek 返回格式异常。"
        case .emptyRewrite:
            return "DeepSeek 未返回有效整理文本。"
        case .httpError(let statusCode, let message):
            return "DeepSeek 请求失败（\(statusCode)）：\(message)"
        }
    }
}

final class DeepSeekFinalRewriteService: Sendable {
    private let session: URLSession
    private let configurationLoader: @Sendable () throws -> DeepSeekFinalRewriteConfiguration
    private let diagnosticsLogger = DeepSeekRewriteDiagnosticsLogger.shared

    init(
        session: URLSession = .shared,
        configurationLoader: @escaping @Sendable () throws -> DeepSeekFinalRewriteConfiguration = {
            DeepSeekFinalRewriteConfiguration(
                credentials: try DeepSeekCredentialStore.load()
            )
        }
    ) {
        self.session = session
        self.configurationLoader = configurationLoader
    }

    func rewrite(
        _ text: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle = .default,
        context: VoiceRewriteContext = VoiceRewriteContext()
    ) async throws -> String {
        let originalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalText.isEmpty else { throw DeepSeekFinalRewriteError.emptyRewrite }
        let promptPlan = VoiceRewritePromptPolicy.promptPlan(
            for: originalText,
            outputLanguage: outputLanguage,
            style: style,
            context: context
        )

        return try await complete(
            promptPlan: promptPlan,
            operation: "final_rewrite",
            outputLanguage: outputLanguage,
            style: style,
            selectedTextCharacters: nil,
            instructionCharacters: originalText.count,
            context: context,
            temperature: style.rewriteTemperature,
            sourceText: originalText
        )
    }

    func handleSelectedTextCommand(
        selectedText: String,
        instruction: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle = .default,
        context: VoiceRewriteContext = VoiceRewriteContext()
    ) async throws -> String {
        let selectedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty, !instruction.isEmpty else { throw DeepSeekFinalRewriteError.emptyRewrite }
        let promptPlan = VoiceRewritePromptPolicy.selectedTextCommandPromptPlan(
            selectedText: selectedText,
            instruction: instruction,
            outputLanguage: outputLanguage,
            style: style,
            context: context
        )

        return try await complete(
            promptPlan: promptPlan,
            operation: "selected_text_command",
            outputLanguage: outputLanguage,
            style: style,
            selectedTextCharacters: selectedText.count,
            instructionCharacters: instruction.count,
            context: context,
            temperature: style.rewriteTemperature,
            sourceText: nil
        )
    }

    func handleScreenReply(
        visibleText: String,
        structuredMessages: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle = .default,
        context: VoiceRewriteContext = VoiceRewriteContext()
    ) async throws -> String {
        let visibleText = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let structuredMessages = structuredMessages.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !visibleText.isEmpty || !structuredMessages.isEmpty else {
            throw DeepSeekFinalRewriteError.emptyRewrite
        }
        let promptPlan = VoiceRewritePromptPolicy.screenReplyPromptPlan(
            visibleText: visibleText,
            structuredMessages: structuredMessages,
            outputLanguage: outputLanguage,
            style: style,
            context: context
        )

        return try await complete(
            promptPlan: promptPlan,
            operation: "screen_reply",
            outputLanguage: outputLanguage,
            style: style,
            selectedTextCharacters: nil,
            instructionCharacters: max(visibleText.count, structuredMessages.count),
            context: context,
            temperature: style.rewriteTemperature,
            sourceText: nil
        )
    }

    private func complete(
        promptPlan: VoiceRewritePromptPlan,
        operation: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle,
        selectedTextCharacters: Int?,
        instructionCharacters: Int?,
        context: VoiceRewriteContext,
        temperature: Double,
        sourceText: String?
    ) async throws -> String {
        let requestID = UUID().uuidString
        let startedAt = Date()
        let userPrompt = promptPlan.userPrompt
        let diagnosticPrompt = diagnosticPromptPreview(for: operation, prompt: userPrompt)
        let configuration: DeepSeekFinalRewriteConfiguration
        do {
            configuration = try configurationLoader()
        } catch {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: error,
                startedAt: startedAt
            )
            throw error
        }
        let requestTimeoutSeconds = max(
            configuration.timeoutSeconds,
            VoiceRewriteTimeoutPolicy.timeoutSeconds(
                operation: operation,
                promptCharacters: userPrompt.count,
                selectedTextCharacters: selectedTextCharacters,
                sourceTextCharacters: instructionCharacters,
                sourceText: sourceText,
                style: style,
                promptMode: promptPlan.mode
            )
        )

        await diagnosticsLogger.log(
            DeepSeekRewriteDiagnosticEvent(
                requestID: requestID,
                event: "started",
                operation: operation,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                outputLanguage: outputLanguage.rawValue,
                rewriteStyle: style.rawValue,
                promptMode: promptPlan.mode.rawValue,
                temperature: temperature,
                timeoutSeconds: requestTimeoutSeconds,
                promptCharacters: userPrompt.count,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                contextSummary: context.diagnosticsSummary,
                promptPreview: diagnosticPrompt
            )
        )

        guard configuration.credentials.isComplete else {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: DeepSeekFinalRewriteError.missingAPIKey,
                startedAt: startedAt
            )
            throw DeepSeekFinalRewriteError.missingAPIKey
        }

        var request = URLRequest(url: configuration.chatCompletionsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.credentials.apiKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(
                DeepSeekChatCompletionRequest(
                    model: configuration.model,
                    messages: [
                        .init(role: "system", content: promptPlan.systemPrompt),
                        .init(role: "user", content: userPrompt)
                    ],
                    stream: false,
                    temperature: temperature,
                    maxTokens: configuration.maxOutputTokens,
                    thinking: .disabled
                )
            )
        } catch {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: error,
                startedAt: startedAt
            )
            throw error
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: error,
                startedAt: startedAt
            )
            throw error
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: DeepSeekFinalRewriteError.invalidResponse,
                startedAt: startedAt
            )
            throw DeepSeekFinalRewriteError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "无错误详情"
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: DeepSeekFinalRewriteError.httpError(httpResponse.statusCode, message),
                startedAt: startedAt,
                httpStatus: httpResponse.statusCode,
                responseBody: message
            )
            throw DeepSeekFinalRewriteError.httpError(httpResponse.statusCode, message)
        }

        let completion: DeepSeekChatCompletionResponse
        do {
            completion = try JSONDecoder().decode(DeepSeekChatCompletionResponse.self, from: data)
        } catch {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: error,
                startedAt: startedAt,
                httpStatus: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8)
            )
            throw error
        }
        guard let rewritten = completion.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rewritten.isEmpty
        else {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: DeepSeekFinalRewriteError.emptyRewrite,
                startedAt: startedAt,
                httpStatus: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8)
            )
            throw DeepSeekFinalRewriteError.emptyRewrite
        }
        let sanitizedRewrite = VoiceRewriteOutputSanitizer.sanitize(rewritten)
        guard !sanitizedRewrite.isEmpty else {
            await logFailure(
                requestID: requestID,
                operation: operation,
                outputLanguage: outputLanguage,
                style: style,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                timeoutSeconds: requestTimeoutSeconds,
                temperature: temperature,
                promptMode: promptPlan.mode,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                context: context,
                prompt: diagnosticPrompt,
                error: DeepSeekFinalRewriteError.emptyRewrite,
                startedAt: startedAt,
                httpStatus: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8)
            )
            throw DeepSeekFinalRewriteError.emptyRewrite
        }
        if VoicePromptInjectionPolicy.shouldUseSafeFallback(
            sourceText: sourceText,
            output: sanitizedRewrite,
            operation: operation
        ) {
            let fallback = VoicePersonalDictionaryTextProtector.protect(
                VoiceRewriteFallbackPolicy.fallbackText(for: sourceText ?? ""),
                dictionary: context.personalDictionary
            )
            guard !fallback.isEmpty else {
                throw DeepSeekFinalRewriteError.emptyRewrite
            }
            await diagnosticsLogger.log(
                DeepSeekRewriteDiagnosticEvent(
                    requestID: requestID,
                    event: "guarded_prompt_injection",
                    operation: operation,
                    model: configuration.model,
                    endpointHost: configuration.chatCompletionsURL.host,
                    outputLanguage: outputLanguage.rawValue,
                    rewriteStyle: style.rawValue,
                    promptMode: promptPlan.mode.rawValue,
                    temperature: temperature,
                    timeoutSeconds: requestTimeoutSeconds,
                    latencyMs: Self.milliseconds(since: startedAt),
                    httpStatus: httpResponse.statusCode,
                    finishReason: completion.choices.first?.finishReason,
                    promptCharacters: userPrompt.count,
                    selectedTextCharacters: selectedTextCharacters,
                    instructionCharacters: instructionCharacters,
                    contextSummary: context.diagnosticsSummary,
                    outputCharacters: fallback.count,
                    promptPreview: diagnosticPrompt,
                    outputPreview: fallback,
                    responseBodyPreview: sanitizedRewrite
                )
            )
            return fallback
        }
        let protectedRewrite = VoicePersonalDictionaryTextProtector.protect(
            sanitizedRewrite,
            dictionary: context.personalDictionary
        )
        let qualityIssue = VoiceRewriteQualityPolicy.qualityIssue(
            output: protectedRewrite,
            operation: operation,
            outputLanguage: outputLanguage
        )

        await diagnosticsLogger.log(
            DeepSeekRewriteDiagnosticEvent(
                requestID: requestID,
                event: "succeeded",
                operation: operation,
                model: configuration.model,
                endpointHost: configuration.chatCompletionsURL.host,
                outputLanguage: outputLanguage.rawValue,
                rewriteStyle: style.rawValue,
                promptMode: promptPlan.mode.rawValue,
                temperature: temperature,
                timeoutSeconds: requestTimeoutSeconds,
                latencyMs: Self.milliseconds(since: startedAt),
                httpStatus: httpResponse.statusCode,
                finishReason: completion.choices.first?.finishReason,
                promptCharacters: userPrompt.count,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                contextSummary: context.diagnosticsSummary,
                outputCharacters: protectedRewrite.count,
                promptPreview: diagnosticPrompt,
                outputPreview: protectedRewrite,
                responseBodyPreview: qualityIssue ?? (protectedRewrite == rewritten ? nil : rewritten)
            )
        )
        return protectedRewrite
    }

    private func logFailure(
        requestID: String,
        operation: String,
        outputLanguage: VoiceOutputLanguage,
        style: VoiceRewriteStyle,
        model: String? = nil,
        endpointHost: String? = nil,
        timeoutSeconds: Double? = nil,
        temperature: Double,
        promptMode: VoiceRewritePromptMode? = nil,
        selectedTextCharacters: Int?,
        instructionCharacters: Int?,
        context: VoiceRewriteContext,
        prompt: String,
        error: Error,
        startedAt: Date,
        httpStatus: Int? = nil,
        responseBody: String? = nil
    ) async {
        await diagnosticsLogger.log(
            DeepSeekRewriteDiagnosticEvent(
                requestID: requestID,
                event: "failed",
                operation: operation,
                model: model,
                endpointHost: endpointHost,
                outputLanguage: outputLanguage.rawValue,
                rewriteStyle: style.rawValue,
                promptMode: promptMode?.rawValue,
                temperature: temperature,
                timeoutSeconds: timeoutSeconds,
                latencyMs: Self.milliseconds(since: startedAt),
                httpStatus: httpStatus,
                promptCharacters: prompt.count,
                selectedTextCharacters: selectedTextCharacters,
                instructionCharacters: instructionCharacters,
                contextSummary: context.diagnosticsSummary,
                promptPreview: prompt,
                responseBodyPreview: responseBody,
                errorType: String(describing: type(of: error)),
                errorMessage: error.localizedDescription
            )
        )
    }

    private static func milliseconds(since startDate: Date) -> Int {
        Int(Date().timeIntervalSince(startDate) * 1000)
    }

    private func diagnosticPromptPreview(for operation: String, prompt: String) -> String {
        guard operation == "screen_reply" else { return prompt }
        return "screen_reply prompt redacted; characters=\(prompt.count)"
    }
}

private struct DeepSeekChatCompletionRequest: Encodable {
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

private struct DeepSeekChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let content: String
    }
}
