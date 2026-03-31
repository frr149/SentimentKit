import Foundation

struct MessageToken: Sendable, Equatable {
  let raw: String
  let normalized: String
  let isAllCaps: Bool
}

enum MessageTokenizer {
  static func tokenize(_ message: String) -> [MessageToken] {
    let pieces = message.split { character in
      character.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) } == false
    }

    return pieces.compactMap { piece in
      let raw = String(piece)
      let normalized = raw.lowercased()
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
}
