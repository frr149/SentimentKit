import Testing
import Foundation

@testable import SentimentKit

struct DictionaryNormalizationLintTests {

  @Test
  func dictionaryHasNoDuplicatesAfterNormalization() throws {
    // This test catches duplicate entries after normalization.
    // If you get a duplicateExpression error, it means two entries
    // in the dictionary normalize to the same string (e.g., "câlice" and "calice").
    //
    // Solution: Keep only one form (preferably the canonical/standard form).
    // Use: swift Tools/add-dict-word.swift to add entries safely.

    let resourceNames = [
      "es-profanity.tsv",
      "es-frustration.tsv",
      "es-positive.tsv",
      "en-profanity.tsv",
      "en-frustration.tsv",
      "en-positive.tsv",
      "pt-profanity.tsv",
      "pt-frustration.tsv",
      "pt-positive.tsv",
      "de-profanity.tsv",
      "de-frustration.tsv",
      "de-positive.tsv",
      "fr-profanity.tsv",
      "fr-frustration.tsv",
      "fr-positive.tsv",
      "zh-profanity.tsv",
      "zh-frustration.tsv",
      "zh-positive.tsv",
    ]

    var totalEntries = 0
    for resourceName in resourceNames {
      let dictionary = try ExpressionDictionary.bundled(named: resourceName)
      totalEntries += dictionary.entries.count
    }

    // If we get here, all dictionaries loaded without duplicateExpression errors
    #expect(totalEntries > 0, "Should load dictionary entries")

    print("✅ All \(resourceNames.count) dictionaries loaded successfully with \(totalEntries) total entries")
    print("   No duplicates after normalization detected")
  }
}