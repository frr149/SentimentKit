import Foundation

/// Anthropic-backed session scorer for the optional async LLM layer.
public struct AnthropicSentimentScorer: SentimentScorer, Sendable {
  public let model: String
  public let policy: LLMScoringPolicy

  private let apiKey: String
  private let endpoint: URL
  private let client: any HTTPClient
  private let limiter: LLMRequestLimiter

  /// Creates an Anthropic scorer that uses the Messages API.
  public init(
    apiKey: String? = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
    model: String = "claude-3-5-haiku-latest",
    policy: LLMScoringPolicy = LLMScoringPolicy()
  ) throws {
    guard let apiKey, apiKey.isEmpty == false else {
      throw SentimentScorerError.missingAPIKey(environmentVariable: "ANTHROPIC_API_KEY")
    }

    self.model = model
    self.policy = policy
    self.apiKey = apiKey
    self.endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    self.client = URLSessionHTTPClient()
    self.limiter = LLMRequestLimiter(policy: policy)
  }

  init(
    apiKey: String,
    model: String = "claude-3-5-haiku-latest",
    policy: LLMScoringPolicy = LLMScoringPolicy(),
    endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
    client: any HTTPClient
  ) {
    self.model = model
    self.policy = policy
    self.apiKey = apiKey
    self.endpoint = endpoint
    self.client = client
    self.limiter = LLMRequestLimiter(policy: policy)
  }

  public func meanScore(for messages: [String], baseAnalysis: SessionAnalysis) async throws
    -> Double
  {
    try await limiter.validateAndRecord(messages: messages)

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = policy.requestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.httpBody = try JSONEncoder().encode(
      AnthropicRequest(
        model: model,
        maxTokens: policy.maxOutputTokens,
        system: LLMSentimentPrompt.systemInstructions,
        messages: [
          AnthropicRequest.Message(
            role: "user",
            content: LLMSentimentPrompt.input(messages: messages, baseAnalysis: baseAnalysis)
          )
        ]
      )
    )

    let result = try await client.send(request)
    guard (200...299).contains(result.response.statusCode) else {
      let body = String(decoding: result.data, as: UTF8.self)
      throw SentimentScorerError.unexpectedStatusCode(
        provider: "Anthropic",
        statusCode: result.response.statusCode,
        body: body
      )
    }

    let response = try JSONDecoder().decode(AnthropicResponse.self, from: result.data)
    guard let text = response.content.first(where: { $0.type == "text" })?.text else {
      throw SentimentScorerError.invalidResponse(provider: "Anthropic")
    }

    return try LLMSentimentPrompt.parseMeanScore(from: text, provider: "Anthropic")
  }
}

private struct AnthropicRequest: Encodable {
  struct Message: Encodable {
    let role: String
    let content: String
  }

  let model: String
  let maxTokens: Int
  let system: String
  let messages: [Message]

  enum CodingKeys: String, CodingKey {
    case model
    case maxTokens = "max_tokens"
    case system
    case messages
  }
}

private struct AnthropicResponse: Decodable {
  struct Content: Decodable {
    let type: String
    let text: String?
  }

  let content: [Content]
}
