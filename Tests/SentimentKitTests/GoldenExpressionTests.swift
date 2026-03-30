import Testing
@testable import SentimentKit

struct GoldenExpressionTests {
    @Test
    func mustMatchExpressionsExistInBundledDictionaries() throws {
        let fixture = try FixtureSupport.loadGoldenExpressions()
        let dictionaries = FixtureSupport.allBundledDictionaries()

        for entry in fixture.must_match {
            let expressionType = try #require(ExpressionType(rawValue: entry.type))
            let exists = dictionaries.contains { dictionary in
                dictionary.language == entry.language
                    && dictionary.type == expressionType
                    && dictionary.entries.contains { $0.expression == entry.text }
            }

            #expect(exists, "Missing approved expression: \(entry.text)")
        }
    }

    @Test
    func mustNotMatchExpressionsStayOutOfDictionariesAndScoreNeutralAlone() throws {
        let fixture = try FixtureSupport.loadGoldenExpressions()
        let dictionaries = FixtureSupport.allBundledDictionaries()
        let analyzer = SentimentAnalyzer()

        for entry in fixture.must_not_match {
            let exists = dictionaries.contains { dictionary in
                dictionary.entries.contains { $0.expression == entry.text }
            }
            #expect(exists == false, "Forbidden dictionary entry present: \(entry.text)")

            let result = analyzer.analyze(entry.text)
            #expect(abs(result.score) <= 0.1, "\(entry.text) should stay neutral")
            #expect(result.profanity.isEmpty && result.frustration.isEmpty && result.positive.isEmpty)
        }
    }
}
