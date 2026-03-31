import Foundation

struct PhraseLexicon: Sendable {
  let phrases: [[String]]
  let scores: [String: Double]?  // Only used for intensifiers

  init(phrases: [[String]], scores: [String: Double]? = nil) {
    self.phrases = phrases.sorted { lhs, rhs in
      if lhs.count == rhs.count {
        return lhs.joined(separator: " ") > rhs.joined(separator: " ")
      }

      return lhs.count > rhs.count
    }
    self.scores = scores
  }

  init(resourceNames: [String], in bundle: Bundle = .module) throws {
    var allPhrases: [[String]] = []
    var allScores: [String: Double] = [:]
    var hasScores = false

    for resourceName in resourceNames {
      let (phrases, scores) = try Self.load(resourceName: resourceName, in: bundle)
      allPhrases.append(contentsOf: phrases)
      for (phrase, score) in scores {
        allScores[phrase] = score
        hasScores = true
      }
    }

    self.init(phrases: allPhrases, scores: hasScores ? allScores : nil)
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

  func amplificationFactor(
    before startIndex: Int, in tokens: [MessageToken], maxDistance: Int
  ) -> Double {
    guard startIndex > 0, let scores else {
      return 1.0
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
          let phraseKey = phrase.joined(separator: " ")
          return scores[phraseKey] ?? 1.3
        }
      }
    }

    return 1.0
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

  private static func load(
    resourceName: String, in bundle: Bundle
  ) throws -> (phrases: [[String]], scores: [String: Double]) {
    let parts = resourceName.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let name = String(parts[0])
    let ext = parts.count == 2 ? String(parts[1]) : "tsv"

    // Extract language from filename prefix (e.g., "zh-intensifiers" → "zh")
    let language = name.components(separatedBy: "-").first

    let url =
      bundle.url(forResource: name, withExtension: ext, subdirectory: "dictionaries")
      ?? bundle.url(forResource: name, withExtension: ext)

    guard let url else {
      throw ExpressionDictionaryError.missingResource(resourceName)
    }

    let contents = try String(contentsOf: url, encoding: .utf8)
    var phrases: [[String]] = []
    var scores: [String: Double] = [:]

    for line in contents.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.isEmpty == false && trimmed.hasPrefix("#") == false else {
        continue
      }

      let parts = trimmed.components(separatedBy: "\t")
      let phraseText = parts[0].trimmingCharacters(in: .whitespaces)
      let tokens = MessageTokenizer.tokenize(phraseText, language: language).map(\.normalized)
      guard tokens.isEmpty == false else {
        continue
      }

      phrases.append(tokens)
      let phraseKey = tokens.joined(separator: " ")

      // Check for score in second column
      if parts.count > 1, let score = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
        scores[phraseKey] = score
      }
    }

    return (phrases, scores)
  }
}
