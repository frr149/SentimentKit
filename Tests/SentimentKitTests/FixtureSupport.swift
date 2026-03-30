import Foundation
@testable import SentimentKit

struct GoldenMessageFixture: Decodable {
    let id: String
    let text: String
    let language: String
    let expected_profanity: [String]
    let expected_frustration: [String]
    let expected_positive: [String]
    let expected_score_min: Double
    let expected_score_max: Double
    let note: String
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

    let must_match: [MustMatch]
    let must_not_match: [MustNotMatch]
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
}
