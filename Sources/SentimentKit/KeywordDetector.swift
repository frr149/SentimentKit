import Foundation

struct KeywordMatches: Sendable, Equatable {
    let profanity: [Expression]
    let frustration: [Expression]
    let positive: [Expression]
    let score: Double
}

struct KeywordDetector: Sendable {
    private struct Candidate: Sendable {
        let entry: ExpressionDictionary.Entry
        let type: ExpressionType
        let language: String
        let tokens: [String]
    }

    private let candidates: [Candidate]

    init(dictionaries: [ExpressionDictionary]) {
        self.candidates = dictionaries
            .flatMap { dictionary in
                dictionary.entries.map { entry in
                    Candidate(
                        entry: entry,
                        type: dictionary.type,
                        language: dictionary.language,
                        tokens: Self.tokenize(entry.expression)
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.tokens.count == rhs.tokens.count {
                    return lhs.entry.expression.count > rhs.entry.expression.count
                }

                return lhs.tokens.count > rhs.tokens.count
            }
    }

    func detect(in message: String, language: String? = nil) -> KeywordMatches {
        let messageTokens = Self.tokenize(message)
        guard messageTokens.isEmpty == false else {
            return KeywordMatches(profanity: [], frustration: [], positive: [], score: 0)
        }

        let filteredCandidates = candidates.filter { candidate in
            guard let language else {
                return true
            }

            return candidate.language == language
        }

        var occupiedTokenIndexes = Set<Int>()
        var profanity: [(position: Int, expression: Expression)] = []
        var frustration: [(position: Int, expression: Expression)] = []
        var positive: [(position: Int, expression: Expression)] = []
        var score = 0.0

        for candidate in filteredCandidates where candidate.tokens.isEmpty == false {
            let windowSize = candidate.tokens.count
            guard windowSize <= messageTokens.count else {
                continue
            }

            for startIndex in 0...(messageTokens.count - windowSize) {
                let tokenRange = startIndex..<(startIndex + windowSize)
                let isOccupied = tokenRange.contains { occupiedTokenIndexes.contains($0) }
                guard isOccupied == false else {
                    continue
                }

                let window = Array(messageTokens[tokenRange])
                guard window == candidate.tokens else {
                    continue
                }

                let expression = Expression(
                    text: candidate.entry.expression,
                    type: candidate.type,
                    language: candidate.language
                )

                switch candidate.type {
                case .profanity:
                    profanity.append((startIndex, expression))
                case .frustration:
                    frustration.append((startIndex, expression))
                case .positive:
                    positive.append((startIndex, expression))
                }

                for index in tokenRange {
                    occupiedTokenIndexes.insert(index)
                }

                score += candidate.entry.score
            }
        }

        return KeywordMatches(
            profanity: profanity.sorted { $0.position < $1.position }.map(\.expression),
            frustration: frustration.sorted { $0.position < $1.position }.map(\.expression),
            positive: positive.sorted { $0.position < $1.position }.map(\.expression),
            score: score
        )
    }

    private static func tokenize(_ text: String) -> [String] {
        let cleaned = text.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return Character(scalar)
            }

            return " "
        }

        return String(cleaned)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
