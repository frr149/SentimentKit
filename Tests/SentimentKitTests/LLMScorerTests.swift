import Foundation
import Testing

@testable import SentimentKit

struct LLMScorerTests {
  @Test
  func asyncSessionScorerOnlyOverridesMeanScore() async throws {
    let analyzer = SentimentAnalyzer()
    let base = analyzer.analyzeSession([
      "works now",
      "this is annoying",
    ])

    let session = try await analyzer.analyzeSession(
      [
        "works now",
        "this is annoying",
      ],
      using: MockSentimentScorer(meanScore: -0.25)
    )

    #expect(session.meanScore == -0.25)
    #expect(session.messages == base.messages)
    #expect(session.stddev == base.stddev)
    #expect(session.angryNerdIndex == base.angryNerdIndex)
    #expect(session.topExpressions == base.topExpressions)
  }

  @Test
  func openAIScorerParsesStructuredOutput() async throws {
    let scorer = OpenAISentimentScorer(
      apiKey: "test-key",
      client: MockHTTPClient.responses([
        .json(
          status: 200,
          body: """
            {
              "output": [
                {
                  "type": "message",
                  "content": [
                    {
                      "type": "output_text",
                      "text": "{\\"meanScore\\": -0.75}"
                    }
                  ]
                }
              ]
            }
            """
        )
      ])
    )

    let score = try await scorer.meanScore(
      for: ["this was frustrating"], baseAnalysis: sampleSession())

    #expect(score == -0.75)
  }

  @Test
  func anthropicScorerParsesJSONText() async throws {
    let scorer = AnthropicSentimentScorer(
      apiKey: "test-key",
      client: MockHTTPClient.responses([
        .json(
          status: 200,
          body: """
            {
              "content": [
                {
                  "type": "text",
                  "text": "{\\"meanScore\\": 0.5}"
                }
              ]
            }
            """
        )
      ])
    )

    let score = try await scorer.meanScore(for: ["nice catch"], baseAnalysis: sampleSession())

    #expect(score == 0.5)
  }

  @Test
  func scoringPolicyRejectsOversizedInputs() async throws {
    let scorer = OpenAISentimentScorer(
      apiKey: "test-key",
      policy: LLMScoringPolicy(maxMessagesPerRequest: 1),
      client: MockHTTPClient.responses([])
    )

    await #expect(throws: SentimentScorerError.tooManyMessages(maximum: 1, actual: 2)) {
      _ = try await scorer.meanScore(
        for: ["one", "two"],
        baseAnalysis: sampleSession()
      )
    }
  }

  @Test
  func scoringPolicyRateLimitsRepeatedRequests() async throws {
    let scorer = OpenAISentimentScorer(
      apiKey: "test-key",
      policy: LLMScoringPolicy(maxRequestsPerMinute: 1),
      client: MockHTTPClient.responses([
        .json(
          status: 200,
          body: """
            {
              "output": [
                {
                  "type": "message",
                  "content": [
                    {
                      "type": "output_text",
                      "text": "{\\"meanScore\\": 0.0}"
                    }
                  ]
                }
              ]
            }
            """
        )
      ])
    )

    _ = try await scorer.meanScore(for: ["fine"], baseAnalysis: sampleSession())

    await #expect(throws: SentimentScorerError.rateLimited(maxRequestsPerMinute: 1)) {
      _ = try await scorer.meanScore(for: ["fine"], baseAnalysis: sampleSession())
    }
  }

  @Test
  func providerFailureProducesStructuredHTTPError() async throws {
    let scorer = OpenAISentimentScorer(
      apiKey: "test-key",
      client: MockHTTPClient.responses([
        .json(status: 500, body: #"{"error":"boom"}"#)
      ])
    )

    await #expect(
      throws: SentimentScorerError.unexpectedStatusCode(
        provider: "OpenAI",
        statusCode: 500,
        body: #"{"error":"boom"}"#
      )
    ) {
      _ = try await scorer.meanScore(for: ["broken"], baseAnalysis: sampleSession())
    }
  }

  @Test
  func providerTimeoutBubblesUp() async throws {
    let scorer = AnthropicSentimentScorer(
      apiKey: "test-key",
      client: MockHTTPClient.responses([
        .error(URLError(.timedOut))
      ])
    )

    await #expect(throws: URLError(.timedOut)) {
      _ = try await scorer.meanScore(for: ["still waiting"], baseAnalysis: sampleSession())
    }
  }

  private func sampleSession() -> SessionAnalysis {
    SessionAnalysis(
      messages: [MessageAnalysis.neutral],
      meanScore: 0,
      stddev: 0,
      angryNerdIndex: 0,
      patienceLevel: 0,
      topExpressions: [:],
      language: "en"
    )
  }
}

private struct MockSentimentScorer: SentimentScorer {
  let meanScore: Double

  func meanScore(for messages: [String], baseAnalysis: SessionAnalysis) async throws -> Double {
    let _ = messages
    let _ = baseAnalysis
    return meanScore
  }
}

private struct MockHTTPClient: HTTPClient {
  struct Reply {
    let status: Int
    let body: String
    let error: Error?

    static func json(status: Int, body: String) -> Reply {
      Reply(status: status, body: body, error: nil)
    }

    static func error(_ error: Error) -> Reply {
      Reply(status: 0, body: "", error: error)
    }
  }

  let replies: [Reply]
  private let state = State()

  static func responses(_ replies: [Reply]) -> MockHTTPClient {
    MockHTTPClient(replies: replies)
  }

  func send(_ request: URLRequest) async throws -> HTTPResponse {
    let _ = request
    let reply = try await state.next(from: replies)
    if let error = reply.error {
      throw error
    }
    return HTTPResponse(
      data: Data(reply.body.utf8),
      response: HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: reply.status,
        httpVersion: nil,
        headerFields: nil
      )!
    )
  }

  actor State {
    private var index = 0

    func next(from replies: [Reply]) throws -> Reply {
      guard index < replies.count else {
        throw URLError(.badServerResponse)
      }
      defer { index += 1 }
      return replies[index]
    }
  }
}
