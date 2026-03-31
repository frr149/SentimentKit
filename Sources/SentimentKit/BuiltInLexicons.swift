import Foundation

enum BuiltInLexicons {
  static let dictionaries: [ExpressionDictionary] = {
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

    return resourceNames.compactMap { resourceName in
      try? ExpressionDictionary.bundled(named: resourceName)
    }
  }()

  static let vaderRules: VADERRules = {
    (try? VADERRules(
      negations: PhraseLexicon(resourceNames: [
        "en-negation.tsv",
        "es-negation.tsv",
        "pt-negation.tsv",
        "de-negation.tsv",
        "fr-negation.tsv",
        "zh-negation.tsv",
      ]),
      intensifiers: PhraseLexicon(resourceNames: [
        "en-intensifiers.tsv",
        "es-intensifiers.tsv",
        "pt-intensifiers.tsv",
        "de-intensifiers.tsv",
        "fr-intensifiers.tsv",
        "zh-intensifiers.tsv",
      ]),
      diminishers: PhraseLexicon(resourceNames: [
        "en-diminishers.tsv",
        "es-diminishers.tsv",
        "pt-diminishers.tsv",
        "de-diminishers.tsv",
        "fr-diminishers.tsv",
      ]),
      conjunctions: PhraseLexicon(resourceNames: [
        "en-conjunctions.tsv",
        "es-conjunctions.tsv",
        "pt-conjunctions.tsv",
        "de-conjunctions.tsv",
        "fr-conjunctions.tsv",
      ])
    )) ?? .empty
  }()

  static let cjkSearcher: CJKSearcher = {
    let words = loadTSVLines(named: "zh-vader.tsv")
      + loadTSVLines(named: "zh-positive.tsv")
      + loadTSVLines(named: "zh-frustration.tsv")
      + loadTSVLines(named: "zh-profanity.tsv")
      + loadTSVLines(named: "zh-negation.tsv")
      + loadTSVLines(named: "zh-intensifiers.tsv")
    return CJKSearcher(dictionary: Set(words))
  }()

  private static func loadTSVLines(named resourceName: String) -> [String] {
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: nil),
      let content = try? String(contentsOf: url, encoding: .utf8)
    else {
      return []
    }

    return content
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }
      .compactMap { line in
        let parts = line.components(separatedBy: "\t")
        return parts.first?.trimmingCharacters(in: .whitespaces)
      }
      .filter { !$0.isEmpty }
  }
}
