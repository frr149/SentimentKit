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
    let strongerNegative = analyzer.analyze("isso é terrivel, pessimo e horrendo")
    let profanity = analyzer.analyze("caralho, merda")
    let positive = analyzer.analyze("isso é excelente, genial e otimo")

    #expect(negative.language == "pt")
    #expect(negative.frustration.map(\.text) == ["ruim", "horrivel"])
    #expect(negative.score < 0)

    #expect(strongerNegative.language == "pt")
    #expect(strongerNegative.frustration.map(\.text) == ["terrivel", "pessimo", "horrendo"])
    #expect(strongerNegative.score <= negative.score)
    #expect(strongerNegative.score <= -2.0)

    #expect(profanity.language == nil || profanity.language == "pt")
    #expect(profanity.profanity.map(\.text) == ["caralho", "merda"])
    #expect(profanity.score < 0)

    #expect(positive.language == "pt")
    #expect(positive.positive.map(\.text) == ["excelente", "genial", "otimo"])
    #expect(positive.score > 0)
  }

  @Test
  func analyzeUsesGermanSeedDictionariesByDefault() {
    let analyzer = SentimentAnalyzer()

    let negative = analyzer.analyze("das ist frustrierend und furchtbar")
    let strongerNegative = analyzer.analyze("das ist katastrophal")
    let profanity = analyzer.analyze("scheiße, scheisse")
    let positive = analyzer.analyze("das ist hervorragend, prima und super")

    #expect(negative.language == "de")
    #expect(negative.frustration.map(\.text) == ["frustrierend", "furchtbar"])
    #expect(negative.score < 0)

    #expect(strongerNegative.language == nil || strongerNegative.language == "de")
    #expect(strongerNegative.frustration.map(\.text) == ["katastrophal"])
    #expect(strongerNegative.score < 0)

    #expect(profanity.language == nil || profanity.language == "de")
    #expect(profanity.profanity.map(\.text) == ["scheiße", "scheisse"])
    #expect(profanity.score < 0)

    #expect(positive.language == "de")
    #expect(positive.positive.map(\.text) == ["hervorragend", "prima", "super"])
    #expect(positive.score > 0)
  }

  @Test
  func analyzeUsesFrenchSeedDictionariesByDefault() {
    let analyzer = SentimentAnalyzer()

    let negative = analyzer.analyze("c'est horrible, affreux et nul")
    let profanity = analyzer.analyze("putain, merde")
    let positive = analyzer.analyze("c'est excellent, génial et formidable")

    #expect(negative.language == "fr")
    #expect(negative.frustration.map(\.text) == ["horrible", "affreux", "nul"])
    #expect(negative.score < 0)

    #expect(profanity.language == nil || profanity.language == "fr")
    #expect(profanity.profanity.map(\.text) == ["putain", "merde"])
    #expect(profanity.score < 0)

    #expect(positive.language == "fr")
    #expect(positive.positive.map(\.text) == ["excellent", "génial", "formidable"])
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
