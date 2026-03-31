import Testing

@testable import SentimentKit

struct SentimentAnalyzerFoundationTests {
  @Test
  func analyzeReturnsNeutralResultUntilDeterministicStagesLand() {
    let analyzer = SentimentAnalyzer()

    let result = analyzer.analyze("delete the temp file")

    #expect(result == .neutral)
  }

  @Test
  func analyzeUsesBundledSeedDictionariesByDefault() {
    let analyzer = SentimentAnalyzer()

    let result = analyzer.analyze("qué coño es esto")

    #expect(result.profanity.map(\.text) == ["qué coño"])
    #expect(result.score < 0)
  }

  @Test
  func analyzeUsesInjectedKeywordDictionaries() throws {
    let profanity = try ExpressionDictionary(
      language: "es",
      type: .profanity,
      entries: [
        .init(expression: "qué coño", score: -1.2),
        .init(expression: "mierda", score: -1.0),
      ]
    )
    let positive = try ExpressionDictionary(
      language: "en",
      type: .positive,
      entries: [
        .init(expression: "great", score: 1.0)
      ]
    )
    let analyzer = SentimentAnalyzer(
      config: SentimentConfig(additionalDictionaries: [profanity, positive])
    )

    let result = analyzer.analyze("Qué coño, this is great... y una mierda")

    #expect(abs(result.score - (-1.2)) < 0.000_001)
    #expect(result.profanity.map(\.text) == ["qué coño", "mierda"])
    #expect(result.positive.map(\.text) == ["great"])
    #expect(result.frustration.isEmpty)
  }

}
