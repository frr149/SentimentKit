import Testing

@testable import SentimentKit

struct KeywordDetectorTests {
  @Test
  func prefersLongestExpressionFirst() throws {
    let dictionary = try ExpressionDictionary(
      language: "en",
      type: .profanity,
      entries: [
        .init(expression: "shit", score: -1.0),
        .init(expression: "holy shit", score: -1.3),
      ]
    )
    let detector = KeywordDetector(dictionaries: [dictionary])

    let result = detector.detect(in: "this is holy shit")

    #expect(result.profanity.map(\.text) == ["holy shit"])
    #expect(result.score == -1.3)
  }

  @Test
  func keepsIndependentMatchesInMessageOrder() throws {
    let profanity = try ExpressionDictionary(
      language: "es",
      type: .profanity,
      entries: [
        .init(expression: "joder", score: -1.0),
        .init(expression: "mierda", score: -1.0),
      ]
    )
    let frustration = try ExpressionDictionary(
      language: "es",
      type: .frustration,
      entries: [
        .init(expression: "aberración", score: -0.7)
      ]
    )
    let detector = KeywordDetector(dictionaries: [profanity, frustration])

    let result = detector.detect(in: "joder, esto es una aberración y una mierda")

    #expect(result.profanity.map(\.text) == ["joder", "mierda"])
    #expect(result.frustration.map(\.text) == ["aberración"])
    #expect(result.score == -2.7)
  }

  @Test
  func canRestrictMatchesToSingleLanguage() throws {
    let spanish = try ExpressionDictionary(
      language: "es",
      type: .positive,
      entries: [
        .init(expression: "perfecto", score: 1.0)
      ]
    )
    let english = try ExpressionDictionary(
      language: "en",
      type: .positive,
      entries: [
        .init(expression: "perfect", score: 1.0)
      ]
    )
    let detector = KeywordDetector(dictionaries: [spanish, english])

    let result = detector.detect(in: "perfect perfecto", language: "es")

    #expect(result.positive.map(\.text) == ["perfecto"])
    #expect(result.score == 1.0)
  }

  @Test
  func matchesAcrossDiacriticsAndUnicodeNormalizationForms() throws {
    let positive = try ExpressionDictionary(
      language: "pt",
      type: .positive,
      entries: [
        .init(expression: "ótimo", score: 1.0)
      ]
    )
    let frustration = try ExpressionDictionary(
      language: "pt",
      type: .frustration,
      entries: [
        .init(expression: "péssimo", score: -1.0)
      ]
    )
    let detector = KeywordDetector(dictionaries: [positive, frustration])
    let decomposedMessage = "isso está o\u{0301}timo, não péssimo"

    let plainAscii = detector.detect(in: "isso esta otimo, nao pessimo", language: "pt")
    let decomposed = detector.detect(in: decomposedMessage, language: "pt")
    let accented = detector.detect(in: "isso está ótimo, não péssimo", language: "pt")

    #expect(plainAscii.positive.map(\.text) == ["ótimo"])
    #expect(plainAscii.frustration.map(\.text) == ["péssimo"])
    #expect(decomposed.positive.map(\.text) == ["ótimo"])
    #expect(decomposed.frustration.map(\.text) == ["péssimo"])
    #expect(accented.positive.map(\.text) == ["ótimo"])
    #expect(accented.frustration.map(\.text) == ["péssimo"])
  }
}
