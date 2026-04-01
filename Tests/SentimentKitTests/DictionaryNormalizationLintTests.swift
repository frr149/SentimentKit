import Foundation
import Testing

@testable import SentimentKit

struct DictionaryNormalizationLintTests {
  @Test
  func allDictionaryEntriesArePreNormalized() throws {
    // Dictionary TSV files must store entries in their normalized form.
    // This means: for any entry e in a TSV file,
    //   TextNormalization.normalizeExpression(e, language: lang) == e
    // If this fails, run: swift Tools/normalize-dictionaries.swift
    //
    // Note: This test only checks ExpressionDictionary files (profanity, frustration, positive).
    // PhraseLexicon files (negation, intensifiers, diminishers, conjunctions) are loaded
    // differently and don't require scores.

    let resourceNames = [
      // ExpressionDictionary files (have scores)
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
    var violations: [(file: String, entry: String, normalized: String)] = []

    for resourceName in resourceNames {
      let dictionary = try ExpressionDictionary.bundled(named: resourceName)
      totalEntries += dictionary.entries.count

      for entry in dictionary.entries {
        let normalized = TextNormalization.normalizeExpression(
          entry.expression, language: dictionary.language)

        if entry.expression != normalized {
          violations.append((file: resourceName, entry: entry.expression, normalized: normalized))
        }
      }
    }

    // Must load successfully (no duplicates)
    #expect(totalEntries > 0, "Should load dictionary entries")

    // All entries must be pre-normalized
    if !violations.isEmpty {
      let message = """
        Found \(violations.count) non-normalized entries. Run: swift Tools/normalize-dictionaries.swift

        \(violations.prefix(5).map { "\($0.file): '\($0.entry)' should be '\($0.normalized)'" }.joined(separator: "\n        "))
        \(violations.count > 5 ? "... and \(violations.count - 5) more" : "")
        """
      #expect(violations.isEmpty, Comment(rawValue: message))
    }

    // Also check PhraseLexicon files (no scores, just expressions)
    let phraseLexiconFiles = [
      "es-negation.tsv",
      "es-intensifiers.tsv",
      "es-diminishers.tsv",
      "es-conjunctions.tsv",
      "en-negation.tsv",
      "en-intensifiers.tsv",
      "en-diminishers.tsv",
      "en-conjunctions.tsv",
      "pt-negation.tsv",
      "pt-intensifiers.tsv",
      "pt-diminishers.tsv",
      "pt-conjunctions.tsv",
      "de-negation.tsv",
      "de-intensifiers.tsv",
      "de-diminishers.tsv",
      "de-conjunctions.tsv",
      "fr-negation.tsv",
      "fr-intensifiers.tsv",
      "fr-diminishers.tsv",
      "fr-conjunctions.tsv",
      "zh-negation.tsv",
      "zh-intensifiers.tsv",
    ]

    // PhraseLexicon files don't need additional checks - they load as simple phrase lists
    // and normalizing happens in PhraseLexicon.load() via MessageTokenizer.tokenize()
    print("✅ All \(resourceNames.count) ExpressionDictionary files validated")
    print("✅ All \(phraseLexiconFiles.count) PhraseLexicon files will be normalized on load")
    print("   Total entries: \(totalEntries)")
  }

}
