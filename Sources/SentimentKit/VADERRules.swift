import Foundation

struct VADERRules: Sendable {
  static let empty = VADERRules(
    negations: PhraseLexicon(phrases: []),
    intensifiers: PhraseLexicon(phrases: []),
    diminishers: PhraseLexicon(phrases: []),
    conjunctions: PhraseLexicon(phrases: [])
  )

  let negations: PhraseLexicon
  let intensifiers: PhraseLexicon
  let diminishers: PhraseLexicon
  let conjunctions: PhraseLexicon

  func apply(to matches: [KeywordMatch], in message: String, tokens: [MessageToken]) -> (
    score: Double, intensity: Double
  ) {
    guard matches.isEmpty == false else {
      return (0, 0)
    }

    let conjunctionStart = conjunctions.lastMatchStart(in: tokens)
    var score = 0.0
    var intensity = 0.0

    for match in matches {
      let result = adjustedScore(
        for: match, tokens: tokens, conjunctionStart: conjunctionStart)
      score += result.score
      intensity += result.capsIntensity
    }

    let exclamationBoost = min(0.4, Double(message.filter { $0 == "!" }.count) * 0.1)
    if exclamationBoost > 0 {
      score *= 1 + exclamationBoost
      intensity += exclamationBoost
    }

    if message.contains("?") {
      score *= 0.9
      intensity += 0.05
    }

    return (score, min(1, intensity))
  }

  func isNegated(_ match: KeywordMatch, tokens: [MessageToken]) -> Bool {
    negations.containsPhrase(before: match.start, in: tokens, maxDistance: 2)
  }

  private func adjustedScore(
    for match: KeywordMatch, tokens: [MessageToken], conjunctionStart: Int?
  ) -> (score: Double, capsIntensity: Double) {
    var adjustedScore = match.score

    if isNegated(match, tokens: tokens) {
      adjustedScore *= -0.75
    }

    let intensifierFactor = intensifiers.amplificationFactor(
      before: match.start, in: tokens, maxDistance: 2)
    adjustedScore *= intensifierFactor

    if diminishers.containsPhrase(before: match.start, in: tokens, maxDistance: 3) {
      adjustedScore *= 0.7
    }

    if let conjunctionStart, match.start > conjunctionStart {
      adjustedScore *= 1.5
    }

    let isAllCaps = tokens[match.start...match.end].allSatisfy(\.isAllCaps)
    if isAllCaps {
      adjustedScore *= 1.2
    }

    return (adjustedScore, isAllCaps ? 0.2 : 0.0)
  }
}
