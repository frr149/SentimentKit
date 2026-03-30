import Foundation

/// Session-level scorer used by the optional async LLM layer.
public protocol SentimentScorer: Sendable {
    /// Returns a replacement session mean score in the range `-2.0 ... 2.0`.
    func meanScore(for messages: [String], baseAnalysis: SessionAnalysis) async throws -> Double
}

/// Errors produced by optional remote sentiment scorers.
public enum SentimentScorerError: Error, Equatable, LocalizedError {
    case missingAPIKey(environmentVariable: String)
    case tooManyMessages(maximum: Int, actual: Int)
    case inputTooLarge(maximumCharacters: Int, actualCharacters: Int)
    case rateLimited(maxRequestsPerMinute: Int)
    case invalidResponse(provider: String)
    case invalidScore(provider: String, score: Double)
    case unexpectedStatusCode(provider: String, statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case let .missingAPIKey(environmentVariable):
            return "Missing API key in \(environmentVariable)."
        case let .tooManyMessages(maximum, actual):
            return "Too many messages for LLM scoring: \(actual) > \(maximum)."
        case let .inputTooLarge(maximumCharacters, actualCharacters):
            return "LLM scoring input too large: \(actualCharacters) > \(maximumCharacters) characters."
        case let .rateLimited(maxRequestsPerMinute):
            return "LLM scoring rate limit exceeded: \(maxRequestsPerMinute) requests per minute."
        case let .invalidResponse(provider):
            return "Invalid response from \(provider)."
        case let .invalidScore(provider, score):
            return "Invalid mean score from \(provider): \(score)."
        case let .unexpectedStatusCode(provider, statusCode, _):
            return "Unexpected HTTP status from \(provider): \(statusCode)."
        }
    }
}

/// Budget and rate-limit policy for optional remote LLM scoring.
public struct LLMScoringPolicy: Sendable {
    public var maxMessagesPerRequest: Int
    public var maxInputCharacters: Int
    public var maxRequestsPerMinute: Int
    public var requestTimeout: TimeInterval
    public var maxOutputTokens: Int
    public var storeProviderResponses: Bool

    public init(
        maxMessagesPerRequest: Int = 200,
        maxInputCharacters: Int = 12_000,
        maxRequestsPerMinute: Int = 10,
        requestTimeout: TimeInterval = 20,
        maxOutputTokens: Int = 128,
        storeProviderResponses: Bool = false
    ) {
        self.maxMessagesPerRequest = maxMessagesPerRequest
        self.maxInputCharacters = maxInputCharacters
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.requestTimeout = requestTimeout
        self.maxOutputTokens = maxOutputTokens
        self.storeProviderResponses = storeProviderResponses
    }
}

actor LLMRequestLimiter {
    private let policy: LLMScoringPolicy
    private var requestTimes: [Date] = []

    init(policy: LLMScoringPolicy) {
        self.policy = policy
    }

    func validateAndRecord(messages: [String]) throws {
        guard messages.count <= policy.maxMessagesPerRequest else {
            throw SentimentScorerError.tooManyMessages(maximum: policy.maxMessagesPerRequest, actual: messages.count)
        }

        let characterCount = messages.reduce(0) { partialResult, message in
            partialResult + message.count
        }
        guard characterCount <= policy.maxInputCharacters else {
            throw SentimentScorerError.inputTooLarge(
                maximumCharacters: policy.maxInputCharacters,
                actualCharacters: characterCount
            )
        }

        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        requestTimes.removeAll { $0 < cutoff }

        guard requestTimes.count < policy.maxRequestsPerMinute else {
            throw SentimentScorerError.rateLimited(maxRequestsPerMinute: policy.maxRequestsPerMinute)
        }

        requestTimes.append(now)
    }
}

enum LLMSentimentPrompt {
    static let systemInstructions = """
    You score the overall sentiment of a developer session.
    Return JSON only.
    Never emit expressions or explanation.
    Produce exactly one object: {"meanScore": number}
    meanScore must be a finite number between -2.0 and 2.0.
    The score represents the overall emotional tone of the full session.
    Technical commands, procedural steps, and code-like instructions should remain neutral unless the session clearly carries sentiment.
    """

    static func input(messages: [String], baseAnalysis: SessionAnalysis) -> String {
        let numberedMessages = messages.enumerated().map { index, message in
            "\(index + 1). \(message)"
        }.joined(separator: "\n")

        return """
        Deterministic baseline:
        - meanScore: \(baseAnalysis.meanScore)
        - angryNerdIndex: \(baseAnalysis.angryNerdIndex)
        - patienceLevel: \(baseAnalysis.patienceLevel)
        - language: \(baseAnalysis.language ?? "unknown")

        Task:
        Return only the corrected session-level JSON meanScore. Do not include commentary.

        Messages:
        \(numberedMessages)
        """
    }

    static func parseMeanScore(from jsonText: String, provider: String) throws -> Double {
        guard let data = jsonText.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["meanScore"] as? NSNumber else {
            throw SentimentScorerError.invalidResponse(provider: provider)
        }

        let score = value.doubleValue
        guard score.isFinite, (-2.0...2.0).contains(score) else {
            throw SentimentScorerError.invalidScore(provider: provider, score: score)
        }
        return score
    }
}
