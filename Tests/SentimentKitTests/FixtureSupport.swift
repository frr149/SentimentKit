import Foundation

@testable import SentimentKit

struct NormalizedExpressionKey: Hashable {
  let text: String
  let type: ExpressionType
  let language: String
}

struct GoldenMessageFixture: Decodable {
  let id: String
  let text: String
  let language: String
  let expectedProfanity: [String]
  let expectedFrustration: [String]
  let expectedPositive: [String]
  let expectedScoreMin: Double
  let expectedScoreMax: Double
  let note: String

  enum CodingKeys: String, CodingKey {
    case id
    case text
    case language
    case expectedProfanity = "expected_profanity"
    case expectedFrustration = "expected_frustration"
    case expectedPositive = "expected_positive"
    case expectedScoreMin = "expected_score_min"
    case expectedScoreMax = "expected_score_max"
    case note
  }
}

struct GoldenExpressionsFixture: Decodable {
  struct MustMatch: Decodable {
    let text: String
    let type: String
    let language: String
  }

  struct MustNotMatch: Decodable {
    let text: String
    let note: String
  }

  let mustMatch: [MustMatch]
  let mustNotMatch: [MustNotMatch]

  enum CodingKeys: String, CodingKey {
    case mustMatch = "must_match"
    case mustNotMatch = "must_not_match"
  }
}

enum FixtureSupport {
  static let rootURL = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appending(path: "Fixtures")

  static func loadGoldenMessages() throws -> [GoldenMessageFixture] {
    let data = try Data(contentsOf: rootURL.appending(path: "golden/messages.json"))
    return try JSONDecoder().decode([GoldenMessageFixture].self, from: data)
  }

  static func loadGoldenExpressions() throws -> GoldenExpressionsFixture {
    let data = try Data(contentsOf: rootURL.appending(path: "golden/expressions.json"))
    return try JSONDecoder().decode(GoldenExpressionsFixture.self, from: data)
  }

  static func allBundledDictionaries() -> [ExpressionDictionary] {
    BuiltInLexicons.dictionaries
  }

  static func allBundledExpressions() -> [SentimentKit.Expression] {
    allBundledDictionaries().flatMap { dictionary in
      dictionary.entries.map { entry in
        SentimentKit.Expression(
          text: entry.expression, type: dictionary.type, language: dictionary.language)
      }
    }
  }

  static func normalizedExpressionKey(
    text: String,
    type: ExpressionType,
    language: String
  ) -> NormalizedExpressionKey {
    NormalizedExpressionKey(
      text: TextNormalization.normalizeExpression(text, language: language),
      type: type,
      language: language
    )
  }

  static func allExercisedBundledExpressions() throws -> Set<SentimentKit.Expression> {
    let messages = try loadGoldenMessages()
    let expressionFixtures = try loadGoldenExpressions()

    let exercisedFromMessages = messages.flatMap { fixture in
      fixture.expectedProfanity.map {
        SentimentKit.Expression(text: $0, type: .profanity, language: fixture.language)
      }
        + fixture.expectedFrustration.map {
          SentimentKit.Expression(text: $0, type: .frustration, language: fixture.language)
        }
        + fixture.expectedPositive.map {
          SentimentKit.Expression(text: $0, type: .positive, language: fixture.language)
        }
    }

    let exercisedFromMustMatch = expressionFixtures.mustMatch.compactMap {
      item -> SentimentKit.Expression? in
      guard let type = ExpressionType(rawValue: item.type) else {
        return nil
      }
      return SentimentKit.Expression(text: item.text, type: type, language: item.language)
    }

    return Set(exercisedFromMessages + exercisedFromMustMatch)
  }

  static func allBundledExpressionKeys() -> Set<NormalizedExpressionKey> {
    Set(
      allBundledExpressions().map {
        normalizedExpressionKey(text: $0.text, type: $0.type, language: $0.language)
      })
  }

  static func allExercisedBundledExpressionKeys() throws -> Set<NormalizedExpressionKey> {
    let messages = try loadGoldenMessages()
    let expressionFixtures = try loadGoldenExpressions()

    let exercisedFromMessages = messages.flatMap { fixture in
      fixture.expectedProfanity.map {
        normalizedExpressionKey(text: $0, type: .profanity, language: fixture.language)
      }
        + fixture.expectedFrustration.map {
          normalizedExpressionKey(text: $0, type: .frustration, language: fixture.language)
        }
        + fixture.expectedPositive.map {
          normalizedExpressionKey(text: $0, type: .positive, language: fixture.language)
        }
    }

    let exercisedFromMustMatch = expressionFixtures.mustMatch.compactMap {
      item -> NormalizedExpressionKey? in
      guard let type = ExpressionType(rawValue: item.type) else {
        return nil
      }
      return normalizedExpressionKey(text: item.text, type: type, language: item.language)
    }

    return Set(exercisedFromMessages + exercisedFromMustMatch)
  }
}
