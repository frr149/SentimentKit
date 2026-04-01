import Testing

@testable import SentimentKit

struct DictionaryCoverageTests {
  // PHANTOM baseline: expressions in dictionaries but not exercised by golden messages.
  // 2026-04-01: Updated from 346 to 426 after PROD-753/754 added PT/DE golden messages.
  // The expanded dictionaries (PROD-721) have more expressions than current golden coverage.
  // This is acceptable because golden messages are added incrementally with provenance requirements.
  // Each new language seed adds ~30-50 expressions to PHANTOM until golden coverage catches up.
  private static let phantomBaseline = 426

  @Test
  func seedGoldenMessagesDoNotReferenceUnknownExpressions() throws {
    let fixtures = try FixtureSupport.loadGoldenMessages()
    let knownExpressions = FixtureSupport.allBundledExpressionKeys()

    let referencedExpressions = Set(
      fixtures.flatMap { fixture in
        fixture.expectedProfanity.map {
          FixtureSupport.normalizedExpressionKey(
            text: $0, type: .profanity, language: fixture.language)
        }
          + fixture.expectedFrustration.map {
            FixtureSupport.normalizedExpressionKey(
              text: $0,
              type: .frustration,
              language: fixture.language
            )
          }
          + fixture.expectedPositive.map {
            FixtureSupport.normalizedExpressionKey(
              text: $0, type: .positive, language: fixture.language)
          }
      }
    )

    let unconsumed = referencedExpressions.subtracting(knownExpressions)
    #expect(
      unconsumed.isEmpty,
      "Unknown expressions in golden fixtures: \(unconsumed.map { $0.text }.sorted())"
    )
  }

  @Test
  func phantomCoverageDoesNotRegressPastCurrentBaseline() throws {
    let exercisedExpressions = try FixtureSupport.allExercisedBundledExpressionKeys()
    let phantom = FixtureSupport.allBundledExpressionKeys()
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

  private func phantomReport(_ phantom: [NormalizedExpressionKey]) -> String {
    phantom.map { expression in
      "[\(expression.language)/\(expression.type.rawValue)] \(expression.text)"
    }
    .joined(separator: "\n")
  }
}
