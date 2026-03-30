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
        ]

        return resourceNames.compactMap { resourceName in
            try? ExpressionDictionary.bundled(named: resourceName)
        }
    }()

    static let vaderRules: VADERRules = {
        (try? VADERRules(
            negations: PhraseLexicon(resourceNames: ["en-negation.tsv", "es-negation.tsv"]),
            intensifiers: PhraseLexicon(resourceNames: ["en-intensifiers.tsv", "es-intensifiers.tsv"]),
            diminishers: PhraseLexicon(resourceNames: ["en-diminishers.tsv", "es-diminishers.tsv"]),
            conjunctions: PhraseLexicon(resourceNames: ["en-conjunctions.tsv", "es-conjunctions.tsv"])
        )) ?? .empty
    }()
}
