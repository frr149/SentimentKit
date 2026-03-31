import Foundation

struct TechnicalCommandGuard: Sendable {
  private let neutralResponses = Set(["ok", "sí", "si", "no"])
  private let imperativeVerbs = Set([
    "delete", "run", "commit", "push", "kill", "nuke", "drop", "abort",
    "borra", "ejecuta", "usa", "cambia",
  ])
  private let technicalTokens = Set([
    "git", "make", "test", "tests", "file", "temp", "process", "cache", "database",
    "operation", "foregroundstyle", "tertiary", "var", "let", "fichero", "temporal",
  ])
  private let suppressedPhrases = [
    "restos mortales",
    "manipulacion",
    "lo vá matar",
    "lo vía matar",
  ]
  private let suppressedTechnicalTerms = Set([
    "kill", "abort", "execute", "dump", "die", "crash", "fatal", "panic", "destroy",
    "nuke", "delete", "borra", "exterminio", "murió", "huelga",
  ])

  func shouldSuppressNLTagger(for message: String, tokens: [MessageToken]) -> Bool {
    let normalizedTokens = tokens.map(\.normalized)
    guard normalizedTokens.isEmpty == false else {
      return true
    }

    if normalizedTokens.count == 1, neutralResponses.contains(normalizedTokens[0]) {
      return true
    }

    if let first = normalizedTokens.first, imperativeVerbs.contains(first) {
      return true
    }

    if normalizedTokens.contains(where: suppressedTechnicalTerms.contains) {
      return true
    }

    if suppressedPhrases.contains(where: { phrase in
      message.localizedCaseInsensitiveContains(phrase)
    }) {
      return true
    }

    if normalizedTokens.contains("git") || normalizedTokens.contains("make") {
      return true
    }

    let technicalCount = normalizedTokens.reduce(into: 0) { total, token in
      if technicalTokens.contains(token) {
        total += 1
      }
    }
    if technicalCount >= 2 {
      return true
    }

    if message.contains(".foregroundStyle") || message.contains("--hard") {
      return true
    }

    return false
  }
}
