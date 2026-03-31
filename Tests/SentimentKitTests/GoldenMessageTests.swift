import Testing

@testable import SentimentKit

struct GoldenMessageTests {
  @Test
  func seedGoldenMessagesMatchExactly() throws {
    let analyzer = SentimentAnalyzer()
    let fixtures = try FixtureSupport.loadGoldenMessages()

    for fixture in fixtures {
      let result = analyzer.analyze(fixture.text)

      #expect(
        result.profanity.map(\.text) == fixture.expectedProfanity,
        "\(fixture.id): profanity mismatch")
      #expect(
        result.frustration.map(\.text) == fixture.expectedFrustration,
        "\(fixture.id): frustration mismatch")
      #expect(
        result.positive.map(\.text) == fixture.expectedPositive, "\(fixture.id): positive mismatch"
      )
      #expect(
        result.score >= fixture.expectedScoreMin && result.score <= fixture.expectedScoreMax,
        "\(fixture.id): score \(result.score) outside [\(fixture.expectedScoreMin), \(fixture.expectedScoreMax)]"
      )
    }
  }
}
