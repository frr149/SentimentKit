import Testing
@testable import SentimentKit

struct DictionaryCoverageTests {
    private static let phantomBaseline = 86

    @Test
    func seedGoldenMessagesDoNotReferenceUnknownExpressions() throws {
        let fixtures = try FixtureSupport.loadGoldenMessages()
        let knownExpressions = Set(FixtureSupport.allBundledExpressions().map(\.text))

        let referencedExpressions = Set(
            fixtures.flatMap { fixture in
                fixture.expected_profanity + fixture.expected_frustration + fixture.expected_positive
            }
        )

        let unconsumed = referencedExpressions.subtracting(knownExpressions)
        #expect(unconsumed.isEmpty, "Unknown expressions in golden fixtures: \(unconsumed.sorted())")
    }

    @Test
    func phantomCoverageDoesNotRegressPastCurrentBaseline() throws {
        let exercisedExpressions = try FixtureSupport.allExercisedBundledExpressions()
        let phantom = FixtureSupport.allBundledExpressions()
            .filter { exercisedExpressions.contains($0) == false }
            .sorted {
                if $0.language == $1.language {
                    if $0.type == $1.type {
                        return $0.text < $1.text
                    }
                    return $0.type.rawValue < $1.type.rawValue
                }
                return $0.language < $1.language
            }

        let report = """
        PHANTOM count regressed: \(phantom.count) > \(Self.phantomBaseline)
        Current PHANTOM expressions:
        \(phantomReport(phantom))
        """

        #expect(
            phantom.count <= Self.phantomBaseline,
            Comment(rawValue: report)
        )
    }

    private func phantomReport(_ phantom: [SentimentKit.Expression]) -> String {
        phantom.map { expression in
            "[\(expression.language)/\(expression.type.rawValue)] \(expression.text)"
        }
        .joined(separator: "\n")
    }
}
