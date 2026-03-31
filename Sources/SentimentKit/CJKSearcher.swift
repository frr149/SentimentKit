import Foundation

struct CJKSearcher: Sendable {
  let dictionary: Set<String>

  func merge(_ tokens: [String]) -> [String] {
    var result: [String] = []
    var i = 0

    while i < tokens.count {
      if let match = longestMatch(from: tokens, startingAt: i) {
        result.append(match.word)
        i += match.tokensConsumed
      } else {
        result.append(tokens[i])
        i += 1
      }
    }

    return result
  }

  func contains(_ word: String) -> Bool {
    dictionary.contains(word)
  }

  private func longestMatch(
    from tokens: [String],
    startingAt index: Int
  ) -> (word: String, tokensConsumed: Int)? {
    var combined = ""
    var bestMatch: (word: String, tokensConsumed: Int)?

    let maxLen = min(4, tokens.count - index)
    for offset in 0..<maxLen {
      combined += tokens[index + offset]

      if dictionary.contains(combined) {
        bestMatch = (combined, offset + 1)
      }
    }

    return bestMatch
  }
}
