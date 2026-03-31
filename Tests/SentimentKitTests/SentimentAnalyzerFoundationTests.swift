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
  func analyzeUsesPortugueseSeedDictionariesByDefault() {
    let analyzer = SentimentAnalyzer()

    let negative = analyzer.analyze("isso é ruim e horrivel")
    let profanity = analyzer.analyze("caralho, merda")
    let positive = analyzer.analyze("isso é excelente e genial")

    #expect(negative.language == "pt")
    #expect(negative.frustration.map(\.text) == ["ruim", "horrivel"])
    #expect(negative.score < 0)

    #expect(profanity.language == nil || profanity.language == "pt")
    #expect(profanity.profanity.map(\.text) == ["caralho", "merda"])
    #expect(profanity.score < 0)

    #expect(positive.language == "pt")
    #expect(positive.positive.map(\.text) == ["excelente", "genial"])
    #expect(positive.score > 0)
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
