import Foundation

struct MessageToken: Sendable, Equatable {
  let raw: String
  let normalized: String
  let isAllCaps: Bool
}

enum MessageTokenizer {
  static func tokenize(_ message: String, language: String? = nil) -> [MessageToken] {
    let pieces = message.split { character in
      character.unicodeScalars.allSatisfy { isSeparator($0) }
    }
      .flatMap { expandCJK(String($0)) }

    let rawTokens = pieces.compactMap { piece -> String? in
      let raw = String(piece)
      let normalized = TextNormalization.normalizeToken(raw, language: language)
      return normalized.isEmpty ? nil : raw
    }

    let mergedTokens = applyCJKSearch(rawTokens, language: language)

    return mergedTokens.compactMap { raw in
      let normalized = TextNormalization.normalizeToken(raw, language: language)
      guard normalized.isEmpty == false else {
        return nil
      }

      return MessageToken(
        raw: raw,
        normalized: normalized,
        isAllCaps: raw.count >= 2 && raw == raw.uppercased() && raw != raw.lowercased()
      )
    }
  }

  private static func applyCJKSearch(_ tokens: [String], language: String?) -> [String] {
    guard language == "zh" else {
      return tokens
    }

    let searcher = BuiltInLexicons.cjkSearcher
    return searcher.merge(tokens)
  }

  private static func isSeparator(_ scalar: UnicodeScalar) -> Bool {
    !isWordScalar(scalar)
  }

  private static func isWordScalar(_ scalar: UnicodeScalar) -> Bool {
    CharacterSet.alphanumerics.contains(scalar) || isCJKIdeograph(scalar)
  }

  static func isCJKIdeograph(_ scalar: UnicodeScalar) -> Bool {
    switch scalar.value {
    case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0x2A700...0x2B73F,
      0x2B740...0x2B81F, 0x2B820...0x2CEAF, 0xF900...0xFAFF, 0x2F800...0x2FA1F:
      return true
    default:
      return false
    }
  }

  private static func expandCJK(_ text: String) -> [String] {
    let scalars = text.unicodeScalars
    guard scalars.isEmpty == false else {
      return []
    }

    if scalars.allSatisfy(isCJKIdeograph) {
      return text.map { String($0) }
    }

    return [text]
  }
}
