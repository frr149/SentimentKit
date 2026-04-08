#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// On-device session scorer using Apple Intelligence (FoundationModels framework).
///
/// Runs entirely on-device via Apple's ~3B parameter model. No API key, no network,
/// no cost. Requires macOS 26+ / iOS 26+ with Apple Intelligence enabled.
///
/// Typical latency: ~600ms for a session of 50 messages. The model uses guided
/// generation (`@Generable`) to guarantee valid JSON output.
@available(macOS 26, iOS 26, *)
public struct AppleIntelligenceScorer: SentimentScorer, Sendable {
  public let policy: LLMScoringPolicy
  private let limiter: LLMRequestLimiter

  /// Whether Apple Intelligence is available on this device.
  public static var isAvailable: Bool {
    SystemLanguageModel.default.isAvailable
  }

  /// Creates an on-device scorer using Apple Intelligence.
  ///
  /// - Parameter policy: Budget and rate-limit policy. Network-related fields
  ///   (`requestTimeout`) are ignored since inference is local.
  /// - Throws: `SentimentScorerError.modelNotAvailable` if Apple Intelligence
  ///   is not enabled on this device.
  public init(policy: LLMScoringPolicy = LLMScoringPolicy()) throws {
    guard Self.isAvailable else {
      throw AppleIntelligenceScorerError.modelNotAvailable
    }
    self.policy = policy
    self.limiter = LLMRequestLimiter(policy: policy)
  }

  public func meanScore(for messages: [String], baseAnalysis: SessionAnalysis) async throws
    -> Double
  {
    try await limiter.validateAndRecord(messages: messages)

    let session = LanguageModelSession(
      instructions: LLMSentimentPrompt.systemInstructions
    )

    let input = LLMSentimentPrompt.input(messages: messages, baseAnalysis: baseAnalysis)
    let response = try await session.respond(to: input, generating: SentimentResponse.self)

    let score = response.content.meanScore
    guard score.isFinite, (-2.0...2.0).contains(score) else {
      throw SentimentScorerError.invalidScore(provider: "AppleIntelligence", score: score)
    }
    return score
  }
}

/// Errors specific to the Apple Intelligence scorer.
public enum AppleIntelligenceScorerError: Error, LocalizedError {
  case modelNotAvailable

  public var errorDescription: String? {
    switch self {
    case .modelNotAvailable:
      return
        "Apple Intelligence is not available. Enable it in System Settings → Apple Intelligence & Siri."
    }
  }
}

@available(macOS 26, iOS 26, *)
@Generable
struct SentimentResponse {
  @Guide(description: "Session mean sentiment score, from -2.0 (very negative) to 2.0 (very positive)")
  var meanScore: Double
}
#endif
