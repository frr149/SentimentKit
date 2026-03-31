import Foundation
import Testing

@testable import SentimentKit

struct NormalizationLintTests {
  @Test
  func unicodeNormalizationOnlyLivesInApprovedFiles() throws {
    let root = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sources = root.appending(path: "Sources/SentimentKit")
    let enumerator = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)

    let allowedFiles = Set([
      "TextNormalization.swift",
      "WordPieceTokenizer.swift",
    ])

    let forbiddenMarkers = [
      ".folding(",
      "precomposedStringWithCanonicalMapping",
      "precomposedStringWithCompatibilityMapping",
      "decomposedStringWithCanonicalMapping",
      "decomposedStringWithCompatibilityMapping",
    ]

    var violations: [String] = []

    while let fileURL = enumerator?.nextObject() as? URL {
      guard fileURL.pathExtension == "swift" else {
        continue
      }

      guard allowedFiles.contains(fileURL.lastPathComponent) == false else {
        continue
      }

      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      let lines = contents.components(separatedBy: .newlines)

      for (index, line) in lines.enumerated() {
        if forbiddenMarkers.contains(where: line.contains) {
          let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
          violations.append(
            "\(relativePath):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
        }
      }
    }

    #expect(
      violations.isEmpty,
      """
      Unicode normalization must go through TextNormalization.
      Violations:
      \(violations.joined(separator: "\n"))
      """
    )
  }
}
