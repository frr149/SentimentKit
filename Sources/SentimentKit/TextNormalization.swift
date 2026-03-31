import Foundation

enum TextNormalization {
  enum Strategy: Sendable {
    case generic
  }

  private static let locale = Locale(identifier: "en_US_POSIX")

  static func normalizeToken(_ text: String, language: String? = nil) -> String {
    let strategy = strategy(for: language)

    switch strategy {
    case .generic:
      return text
        .precomposedStringWithCompatibilityMapping
        .folding(
          options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
          locale: locale
        )
    }
  }

  static func normalizeExpression(_ text: String, language: String? = nil) -> String {
    text
      .split(whereSeparator: \.isWhitespace)
      .map { normalizeToken(String($0), language: language) }
      .filter { $0.isEmpty == false }
      .joined(separator: " ")
  }

  private static func strategy(for language: String?) -> Strategy {
    switch language {
    default:
      return .generic
    }
  }
}
