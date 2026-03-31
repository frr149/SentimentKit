import Foundation

/// A matched expression from a sentiment dictionary.
public struct Expression: Sendable, Equatable, Hashable {
  public let text: String
  public let type: ExpressionType
  public let language: String

  public init(text: String, type: ExpressionType, language: String) {
    self.text = text
    self.type = type
    self.language = language
  }
}
