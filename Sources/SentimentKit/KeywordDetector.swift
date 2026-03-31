import Foundation

struct KeywordMatches: Sendable, Equatable {
  let profanity: [Expression]
  let frustration: [Expression]
  let positive: [Expression]
  let score: Double
  let matches: [KeywordMatch]
}

struct KeywordMatch: Sendable, Equatable {
  let expression: Expression
  let score: Double
  let start: Int
  let end: Int
}

struct KeywordDetector: Sendable {
  private struct Candidate: Sendable {
    let entry: ExpressionDictionary.Entry
    let type: ExpressionType
    let language: String
    let tokens: [String]
    let allowCrossLanguage: Bool
  }

  private let candidates: [Candidate]

  init(dictionaries: [ExpressionDictionary]) {
    self.init(dictionaries: dictionaries.map { ($0, allowCrossLanguage: false) })
  }

  init(dictionaries: [(ExpressionDictionary, allowCrossLanguage: Bool)]) {
    self.candidates =
      dictionaries
      .flatMap { dictionary, allowCrossLanguage in
        dictionary.entries.map { entry in
          Candidate(
            entry: entry,
            type: dictionary.type,
            language: dictionary.language,
            tokens: MessageTokenizer.tokenize(entry.expression, language: dictionary.language).map(
              \.normalized),
            allowCrossLanguage: allowCrossLanguage
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
    detect(in: MessageTokenizer.tokenize(message, language: language), language: language)
  }

  func detect(in messageTokens: [MessageToken], language: String? = nil) -> KeywordMatches {
    guard messageTokens.isEmpty == false else {
      return KeywordMatches(profanity: [], frustration: [], positive: [], score: 0, matches: [])
    }

    let filteredCandidates = candidates.filter { candidate in
      guard let language else {
        return true
      }

      return candidate.language == language || candidate.allowCrossLanguage
    }

    var occupiedTokenIndexes = Set<Int>()
    var profanity: [(position: Int, expression: Expression)] = []
    var frustration: [(position: Int, expression: Expression)] = []
    var positive: [(position: Int, expression: Expression)] = []
    var matches: [KeywordMatch] = []
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

        let window = messageTokens[tokenRange].map(\.normalized)
        guard window == candidate.tokens else {
          continue
        }

        let expression = Expression(
          text: candidate.entry.expression,
          type: candidate.type,
          language: candidate.language
        )
        let match = KeywordMatch(
          expression: expression,
          score: candidate.entry.score,
          start: startIndex,
          end: startIndex + windowSize - 1
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

        matches.append(match)
        score += candidate.entry.score
      }
    }

    return KeywordMatches(
      profanity: profanity.sorted { $0.position < $1.position }.map(\.expression),
      frustration: frustration.sorted { $0.position < $1.position }.map(\.expression),
      positive: positive.sorted { $0.position < $1.position }.map(\.expression),
      score: score,
      matches: matches.sorted { $0.start < $1.start }
    )
  }
}
