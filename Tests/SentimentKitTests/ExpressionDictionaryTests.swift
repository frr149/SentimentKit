import Foundation
import Testing

@testable import SentimentKit

struct ExpressionDictionaryTests {
  @Test
  func parsesTSVDictionaryMetadataAndEntries() throws {
    let contents = """
      # language: es
      # type: profanity
      joder\t-1.0
      mierda\t-1.0
      """

    let dictionary = try ExpressionDictionary(parsing: contents)

    #expect(dictionary.language == "es")
    #expect(dictionary.type == .profanity)
    #expect(
      dictionary.entries == [
        .init(expression: "joder", score: -1.0),
        .init(expression: "mierda", score: -1.0),
      ])
  }

  @Test
  func rejectsMissingMetadata() {
    let contents = """
      # language: es
      joder\t-1.0
      """

    #expect(throws: ExpressionDictionaryError.missingMetadata("type")) {
      try ExpressionDictionary(parsing: contents)
    }
  }

  @Test
  func rejectsDuplicateExpressions() {
    // Since entries are pre-normalized, duplicates are detected by string equality
    #expect(throws: ExpressionDictionaryError.duplicateExpression("que cono")) {
      try ExpressionDictionary(
        language: "es",
        type: .profanity,
        entries: [
          .init(expression: "que cono", score: -1.2),
          .init(expression: "que cono", score: -1.0),  // duplicate
        ]
      )
    }
  }

  @Test
  func rejectsDuplicateExpressionsAcrossUnicodeForms() {
    // Unicode normalization: "ótimo" as composed vs decomposed
    let composed = "ótimo"
    let decomposed = "o\u{0301}timo"

    #expect(throws: ExpressionDictionaryError.duplicateExpression(decomposed)) {
      try ExpressionDictionary(
        language: "pt",
        type: .positive,
        entries: [
          .init(expression: composed, score: 1.0),
          .init(expression: decomposed, score: 0.8),  // duplicate after Unicode normalization
        ]
      )
    }
  }

  @Test
  func loadsDictionaryFromFileURL() throws {
    let temporaryURL = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appendingPathExtension("tsv")

    try """
    # language: en
    # type: positive
    awesome\t1.0
    """
    .write(to: temporaryURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    let dictionary = try ExpressionDictionary(contentsOf: temporaryURL)

    #expect(dictionary.language == "en")
    #expect(dictionary.type == .positive)
    #expect(dictionary.entries.count == 1)
    #expect(dictionary.entries.first == .init(expression: "awesome", score: 1.0))
  }

  @Test
  func loadsBundledDictionaryResource() throws {
    let dictionary = try ExpressionDictionary.bundled(named: "es-profanity.tsv")

    #expect(dictionary.language == "es")
    #expect(dictionary.type == .profanity)
    #expect(dictionary.entries.contains { $0.expression == "joder" })
  }

}
