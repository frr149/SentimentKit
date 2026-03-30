import Testing
@testable import SentimentKit

struct DictionaryCoverageTests {
    @Test
    func seedGoldenMessagesDoNotReferenceUnknownExpressions() throws {
        let fixtures = try FixtureSupport.loadGoldenMessages()
        let knownExpressions = Set(
            FixtureSupport.allBundledDictionaries()
                .flatMap(\.entries)
                .map(\.expression)
        )

        let referencedExpressions = Set(
            fixtures.flatMap { fixture in
                fixture.expected_profanity + fixture.expected_frustration + fixture.expected_positive
            }
        )

        let unconsumed = referencedExpressions.subtracting(knownExpressions)
        #expect(unconsumed.isEmpty, "Unknown expressions in golden fixtures: \(unconsumed.sorted())")
    }
}
