import Testing

@testable import SentimentKit

struct NegationTests {
  @Test
  func notGoodBecomesNegative() {
    let result = SentimentAnalyzer().analyze("this is not good at all")

    #expect(result.score < 0)
    #expect(result.score >= -1.0 && result.score <= -0.5)
    #expect(result.positive.isEmpty)
  }

  @Test
  func notBadBecomesSlightlyPositive() {
    let result = SentimentAnalyzer().analyze("this is not bad")

    #expect(result.score > 0)
    #expect(result.frustration.isEmpty)
  }

  @Test
  func spanishNegationIsApplied() {
    let result = SentimentAnalyzer().analyze("no es bueno")

    #expect(result.score < 0)
    #expect(result.positive.isEmpty)
  }

  @Test
  func neverBeenBetterStaysPositive() {
    let result = SentimentAnalyzer().analyze("this has never been better")

    #expect(result.score > 0)
    #expect(result.positive.map(\.text) == ["never been better"])
  }

  @Test
  func intensifierAmplifiesNegativeExpression() {
    let baseline = SentimentAnalyzer().analyze("bad")
    let intensified = SentimentAnalyzer().analyze("very bad")

    #expect(intensified.score < baseline.score)
  }

  @Test
  func diminisherAttenuatesNegativeExpression() {
    let baseline = SentimentAnalyzer().analyze("malo")
    let diminished = SentimentAnalyzer().analyze("un poco malo")

    #expect(diminished.score > baseline.score)
  }

  @Test
  func butConjunctionWeightsPostClause() {
    let result = SentimentAnalyzer().analyze("good but bad")

    #expect(result.score < 0)
  }
}
