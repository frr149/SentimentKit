import Testing
@testable import SentimentKit

struct GoldenMessageTests {
    @Test
    func seedGoldenMessagesMatchExactly() throws {
        let analyzer = SentimentAnalyzer()
        let fixtures = try FixtureSupport.loadGoldenMessages()

        for fixture in fixtures {
            let result = analyzer.analyze(fixture.text)

            #expect(result.profanity.map(\.text) == fixture.expected_profanity, "\(fixture.id): profanity mismatch")
            #expect(result.frustration.map(\.text) == fixture.expected_frustration, "\(fixture.id): frustration mismatch")
            #expect(result.positive.map(\.text) == fixture.expected_positive, "\(fixture.id): positive mismatch")
            #expect(
                result.score >= fixture.expected_score_min && result.score <= fixture.expected_score_max,
                "\(fixture.id): score \(result.score) outside [\(fixture.expected_score_min), \(fixture.expected_score_max)]"
            )
        }
    }
}
