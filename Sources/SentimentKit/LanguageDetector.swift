import Foundation
import NaturalLanguage

struct LanguageDetector: Sendable {
  private let minimumReliableTokenCount = 5
  private let sessionSampleSize = 5

  func detectMessageLanguage(_ message: String) -> String? {
    let tokens = MessageTokenizer.tokenize(message)
    guard tokens.count >= minimumReliableTokenCount else {
      return nil
    }

    let recognizer = NLLanguageRecognizer()
    recognizer.processString(message)
    return normalizedLanguageCode(recognizer.dominantLanguage?.rawValue)
  }

  func detectSessionLanguage(_ messages: [String]) -> String? {
    let sample = messages.prefix(sessionSampleSize).joined(separator: "\n")
    return detectMessageLanguage(sample)
  }

  private func normalizedLanguageCode(_ code: String?) -> String? {
    guard let code else {
      return nil
    }

    let parts = code.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
    return parts.first.map { String($0) }
  }
}
