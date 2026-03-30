import Foundation

struct PhraseLexicon: Sendable {
    let phrases: [[String]]

    init(phrases: [[String]]) {
        self.phrases = phrases.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.joined(separator: " ") > rhs.joined(separator: " ")
            }

            return lhs.count > rhs.count
        }
    }

    init(resourceNames: [String], in bundle: Bundle = .module) throws {
        let phrases = try resourceNames.flatMap { resourceName in
            try Self.load(resourceName: resourceName, in: bundle)
        }

        self.init(phrases: phrases)
    }

    func containsPhrase(before startIndex: Int, in tokens: [MessageToken], maxDistance: Int) -> Bool {
        guard startIndex > 0 else {
            return false
        }

        for phrase in phrases {
            let phraseLength = phrase.count
            guard phraseLength > 0, startIndex - phraseLength >= 0 else {
                continue
            }

            let lowerBound = max(0, startIndex - maxDistance)
            let upperBound = startIndex - phraseLength
            guard lowerBound <= upperBound else {
                continue
            }

            for candidateStart in lowerBound...upperBound {
                let candidateEnd = candidateStart + phraseLength
                let candidate = tokens[candidateStart..<candidateEnd].map(\.normalized)
                if candidate == phrase {
                    return true
                }
            }
        }

        return false
    }

    func lastMatchStart(in tokens: [MessageToken]) -> Int? {
        var lastMatchStart: Int?

        for phrase in phrases {
            let phraseLength = phrase.count
            guard phraseLength > 0, phraseLength <= tokens.count else {
                continue
            }

            for startIndex in 0...(tokens.count - phraseLength) {
                let endIndex = startIndex + phraseLength
                let candidate = tokens[startIndex..<endIndex].map(\.normalized)
                if candidate == phrase {
                    lastMatchStart = startIndex
                }
            }
        }

        return lastMatchStart
    }

    private static func load(resourceName: String, in bundle: Bundle) throws -> [[String]] {
        let parts = resourceName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(parts[0])
        let ext = parts.count == 2 ? String(parts[1]) : "tsv"

        let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "dictionaries")
            ?? bundle.url(forResource: name, withExtension: ext)

        guard let url else {
            throw ExpressionDictionaryError.missingResource(resourceName)
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                line.isEmpty == false && line.hasPrefix("#") == false
            }
            .map { phrase in
                MessageTokenizer.tokenize(phrase).map(\.normalized)
            }
            .filter { $0.isEmpty == false }
    }
}
