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
}
