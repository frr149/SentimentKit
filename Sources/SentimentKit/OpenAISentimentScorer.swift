import Foundation

/// OpenAI-backed session scorer for the optional async LLM layer.
public struct OpenAISentimentScorer: SentimentScorer, Sendable {
  public let model: String
  public let policy: LLMScoringPolicy

  private let apiKey: String
  private let endpoint: URL
  private let client: any HTTPClient
  private let limiter: LLMRequestLimiter

  /// Creates an OpenAI scorer that uses the Responses API.
  public init(
    apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
    model: String = "gpt-4o-mini",
    policy: LLMScoringPolicy = LLMScoringPolicy()
  ) throws {
    guard let apiKey, apiKey.isEmpty == false else {
      throw SentimentScorerError.missingAPIKey(environmentVariable: "OPENAI_API_KEY")
    }

    self.model = model
    self.policy = policy
    self.apiKey = apiKey
    self.endpoint = URL(string: "https://api.openai.com/v1/responses")!
    self.client = URLSessionHTTPClient()
    self.limiter = LLMRequestLimiter(policy: policy)
  }

  init(
    apiKey: String,
    model: String = "gpt-4o-mini",
    policy: LLMScoringPolicy = LLMScoringPolicy(),
    endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!,
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
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(
      OpenAIRequest(
        model: model,
        input: LLMSentimentPrompt.input(messages: messages, baseAnalysis: baseAnalysis),
        instructions: LLMSentimentPrompt.systemInstructions,
        maxOutputTokens: policy.maxOutputTokens,
        store: policy.storeProviderResponses
      )
    )

    let result = try await client.send(request)
    guard (200...299).contains(result.response.statusCode) else {
      let body = String(decoding: result.data, as: UTF8.self)
      throw SentimentScorerError.unexpectedStatusCode(
        provider: "OpenAI",
        statusCode: result.response.statusCode,
        body: body
      )
    }

    let response = try JSONDecoder().decode(OpenAIResponse.self, from: result.data)
    guard let text = response.outputText else {
      throw SentimentScorerError.invalidResponse(provider: "OpenAI")
    }

    return try LLMSentimentPrompt.parseMeanScore(from: text, provider: "OpenAI")
  }
}

private struct OpenAIRequest: Encodable {
  let model: String
  let input: String
  let instructions: String
  let maxOutputTokens: Int
  let store: Bool

  enum CodingKeys: String, CodingKey {
    case model
    case input
    case instructions
    case text
    case store
    case maxOutputTokens = "max_output_tokens"
  }

  enum TextKeys: String, CodingKey {
    case format
  }

  enum FormatKeys: String, CodingKey {
    case type
    case name
    case strict
    case schema
  }

  enum SchemaKeys: String, CodingKey {
    case type
    case properties
    case required
    case additionalProperties = "additionalProperties"
  }

  enum PropertyKeys: String, CodingKey {
    case meanScore = "meanScore"
  }

  enum NumberSchemaKeys: String, CodingKey {
    case type
    case minimum
    case maximum
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(model, forKey: .model)
    try container.encode(input, forKey: .input)
    try container.encode(instructions, forKey: .instructions)
    try container.encode(maxOutputTokens, forKey: .maxOutputTokens)
    try container.encode(store, forKey: .store)

    var textContainer = container.nestedContainer(keyedBy: TextKeys.self, forKey: .text)
    var formatContainer = textContainer.nestedContainer(keyedBy: FormatKeys.self, forKey: .format)
    try formatContainer.encode("json_schema", forKey: .type)
    try formatContainer.encode("sentimentkit_mean_score", forKey: .name)
    try formatContainer.encode(true, forKey: .strict)

    var schemaContainer = formatContainer.nestedContainer(keyedBy: SchemaKeys.self, forKey: .schema)
    try schemaContainer.encode("object", forKey: .type)
    try schemaContainer.encode(["meanScore"], forKey: .required)
    try schemaContainer.encode(false, forKey: .additionalProperties)

    var propertiesContainer = schemaContainer.nestedContainer(
      keyedBy: PropertyKeys.self, forKey: .properties)
    var meanScoreContainer = propertiesContainer.nestedContainer(
      keyedBy: NumberSchemaKeys.self, forKey: .meanScore)
    try meanScoreContainer.encode("number", forKey: .type)
    try meanScoreContainer.encode(-2.0, forKey: .minimum)
    try meanScoreContainer.encode(2.0, forKey: .maximum)
  }
}

private struct OpenAIResponse: Decodable {
  let output: [OpenAIOutputItem]

  var outputText: String? {
    for item in output where item.type == "message" {
      for content in item.content where content.type == "output_text" {
        if let text = content.text {
          return text
        }
      }
    }
    return nil
  }
}

private struct OpenAIOutputItem: Decodable {
  let type: String
  let content: [OpenAIOutputContent]
}

private struct OpenAIOutputContent: Decodable {
  let type: String
  let text: String?
}
