import Foundation

public enum ExpressionDictionaryError: Error, Equatable, LocalizedError {
  case missingMetadata(String)
  case invalidMetadata(key: String, value: String)
  case invalidEntry(line: Int, reason: String)
  case duplicateExpression(String)
  case missingResource(String)

  public var errorDescription: String? {
    switch self {
    case .missingMetadata(let key):
      return "Missing dictionary metadata: \(key)"
    case .invalidMetadata(let key, let value):
      return "Invalid dictionary metadata \(key): \(value)"
    case .invalidEntry(let line, let reason):
      return "Invalid dictionary entry at line \(line): \(reason)"
    case .duplicateExpression(let expression):
      return "Duplicate dictionary expression: \(expression)"
    case .missingResource(let name):
      return "Dictionary resource not found: \(name)"
    }
  }
}

/// A validated TSV-backed dictionary of sentiment expressions.
public struct ExpressionDictionary: Sendable, Equatable {
  public struct Entry: Sendable, Equatable, Hashable {
    public let expression: String
    public let score: Double

    public init(expression: String, score: Double) {
      self.expression = expression
      self.score = score
    }
  }

  public let language: String
  public let type: ExpressionType
  public let entries: [Entry]

  public init(language: String, type: ExpressionType, entries: [Entry]) throws {
    let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalizedLanguage.isEmpty == false else {
      throw ExpressionDictionaryError.missingMetadata("language")
    }

    var seen = Set<String>()
    for entry in entries {
      let normalizedExpression = Self.normalize(entry.expression)
      guard normalizedExpression.isEmpty == false else {
        throw ExpressionDictionaryError.invalidEntry(
          line: 0, reason: "expression must not be empty")
      }

      guard entry.score.isFinite else {
        throw ExpressionDictionaryError.invalidEntry(
          line: 0,
          reason: "score must be finite for \(entry.expression)"
        )
      }

      let inserted = seen.insert(normalizedExpression).inserted
      if inserted == false {
        throw ExpressionDictionaryError.duplicateExpression(entry.expression)
      }
    }

    self.language = normalizedLanguage
    self.type = type
    self.entries = entries
  }

  public init(contentsOf url: URL, encoding: String.Encoding = .utf8) throws {
    let contents = try String(contentsOf: url, encoding: encoding)
    try self.init(parsing: contents)
  }

  public init(parsing contents: String) throws {
    let parsed = try Self.parse(contents)
    try self.init(language: parsed.language, type: parsed.type, entries: parsed.entries)
  }

  public static func bundled(
    named resource: String,
    in bundle: Bundle? = nil
  ) throws -> ExpressionDictionary {
    let bundle = bundle ?? .module
    let parts = resource.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let name = String(parts[0])
    let ext = parts.count == 2 ? String(parts[1]) : "tsv"

    let url =
      bundle.url(forResource: name, withExtension: ext, subdirectory: "dictionaries")
      ?? bundle.url(forResource: name, withExtension: ext)

    guard let url else {
      throw ExpressionDictionaryError.missingResource(resource)
    }

    return try ExpressionDictionary(contentsOf: url)
  }

  private static func parse(_ contents: String) throws -> (
    language: String, type: ExpressionType, entries: [Entry]
  ) {
    var language: String?
    var type: ExpressionType?
    var entries: [Entry] = []

    let lines = contents.components(separatedBy: .newlines)
    for (index, rawLine) in lines.enumerated() {
      let lineNumber = index + 1
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

      if line.isEmpty {
        continue
      }

      if line.hasPrefix("#") {
        let metadataLine = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard let separatorIndex = metadataLine.firstIndex(of: ":") else {
          continue
        }

        let key = metadataLine[..<separatorIndex].trimmingCharacters(in: .whitespaces)
        let value = metadataLine[metadataLine.index(after: separatorIndex)...]
          .trimmingCharacters(in: .whitespaces)

        switch key {
        case "language":
          language = value
        case "type":
          guard let parsedType = ExpressionType(rawValue: value) else {
            throw ExpressionDictionaryError.invalidMetadata(key: key, value: value)
          }
          type = parsedType
        default:
          continue
        }

        continue
      }

      let parts = rawLine.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2 else {
        throw ExpressionDictionaryError.invalidEntry(
          line: lineNumber,
          reason: "expected expression<TAB>score"
        )
      }

      let expression = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard expression.isEmpty == false else {
        throw ExpressionDictionaryError.invalidEntry(
          line: lineNumber,
          reason: "expression must not be empty"
        )
      }

      let scoreText = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard let score = Double(scoreText) else {
        throw ExpressionDictionaryError.invalidEntry(
          line: lineNumber,
          reason: "invalid score \(scoreText)"
        )
      }

      entries.append(Entry(expression: expression, score: score))
    }

    guard let language else {
      throw ExpressionDictionaryError.missingMetadata("language")
    }

    guard let type else {
      throw ExpressionDictionaryError.missingMetadata("type")
    }

    return (language, type, entries)
  }

  private static func normalize(_ expression: String) -> String {
    expression
      .lowercased()
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }
}
