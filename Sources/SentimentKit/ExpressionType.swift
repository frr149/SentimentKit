import Foundation

/// Expression categories supported by the deterministic sentiment pipeline.
public enum ExpressionType: String, Sendable, Codable, CaseIterable {
  case profanity
  case frustration
  case positive
}
