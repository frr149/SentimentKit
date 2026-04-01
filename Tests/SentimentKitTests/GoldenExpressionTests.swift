import Testing

@testable import SentimentKit

struct GoldenExpressionTests {
  @Test
  func mustMatchExpressionsExistInBundledDictionaries() throws {
    let fixture = try FixtureSupport.loadGoldenExpressions()
    let dictionaries = FixtureSupport.allBundledDictionaries()

    for entry in fixture.mustMatch {
      let expressionType = try #require(ExpressionType(rawValue: entry.type))
      let exists = FixtureSupport.allBundledExpressionKeys().contains(
        FixtureSupport.normalizedExpressionKey(
          text: entry.text,
          type: expressionType,
          language: entry.language
        )
      )

      #expect(exists, "Missing approved expression: \(entry.text)")
    }
  }

  @Test
  func mustNotMatchExpressionsStayOutOfDictionariesAndScoreNeutralAlone() throws {
    let fixture = try FixtureSupport.loadGoldenExpressions()
    let dictionaries = FixtureSupport.allBundledDictionaries()
    let analyzer = SentimentAnalyzer()

    for entry in fixture.mustNotMatch {
      let exists = dictionaries.contains { dictionary in
        dictionary.entries.contains {
          TextNormalization.normalizeExpression($0.expression, language: dictionary.language)
            == TextNormalization.normalizeExpression(entry.text, language: dictionary.language)
        }
      }
      #expect(exists == false, "Forbidden dictionary entry present: \(entry.text)")

      let result = analyzer.analyze(entry.text)
      #expect(abs(result.score) <= 0.1, "\(entry.text) should stay neutral")
      #expect(result.profanity.isEmpty && result.frustration.isEmpty && result.positive.isEmpty)
    }
  }

  @Test
  func spanishProfanityCulturalExpressionsClassifyCorrectly() {
    let analyzer = SentimentAnalyzer()

    // Positive cultural expressions with profanity
    let dePutaMadre = analyzer.analyze("esto es de puta madre")
    #expect(dePutaMadre.score > 1.0, "de puta madre should be strongly positive")
    #expect(dePutaMadre.positive.contains(where: { $0.text == "de puta madre" }))
    #expect(dePutaMadre.profanity.isEmpty, "de puta madre should not trigger profanity")

    let oleTusCojones = analyzer.analyze("olé tus cojones")
    #expect(oleTusCojones.score > 1.0, "olé tus cojones should be strongly positive")
    #expect(oleTusCojones.positive.contains(where: { $0.text == "olé tus cojones" }))
    #expect(oleTusCojones.profanity.isEmpty, "olé tus cojones should not trigger profanity")

    // Insults should still be negative
    let tuPutaMadre = analyzer.analyze("tu puta madre")
    #expect(tuPutaMadre.score < 0, "tu puta madre should be negative")
    #expect(tuPutaMadre.profanity.isEmpty == false, "tu puta madre should trigger profanity")

    let laPutMadre = analyzer.analyze("la puta madre")
    #expect(laPutMadre.score < 0, "la puta madre should be negative")
    #expect(laPutMadre.profanity.isEmpty == false, "la puta madre should trigger profanity")
  }
}
