import Foundation
import SentimentKit

struct GoldenFixture: Encodable {
  let id: String
  let text: String
  let language: String
  let expectedProfanity: [String]
  let expectedFrustration: [String]
  let expectedPositive: [String]
  let expectedScoreMin: Double
  let expectedScoreMax: Double

  enum CodingKeys: String, CodingKey {
    case id
    case text
    case language
    case expectedProfanity = "expected_profanity"
    case expectedFrustration = "expected_frustration"
    case expectedPositive = "expected_positive"
    case expectedScoreMin = "expected_score_min"
    case expectedScoreMax = "expected_score_max"
  }
}

func deriveID(lang: String, analysis: MessageAnalysis) -> String {
  let hasProfanity = !analysis.profanity.isEmpty
  let hasFrustration = !analysis.frustration.isEmpty
  let hasPositive = !analysis.positive.isEmpty

  let category: String
  if hasProfanity && (hasFrustration || hasPositive) {
    category = "mixed"
  } else if hasProfanity {
    category = "profanity"
  } else if hasFrustration && hasPositive {
    category = "mixed"
  } else if hasFrustration {
    category = "frustration"
  } else if hasPositive {
    category = "positive"
  } else {
    category = "neutral"
  }

  return "\(lang)-\(category)-001"
}

func formatScore(_ score: Double) -> Double {
  round(score * 100) / 100
}

func printStderr(_ message: String) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
}

var lang = "en"
var text = ""
var i = 1

while i < CommandLine.arguments.count {
  let arg = CommandLine.arguments[i]
  if arg == "--lang" && i + 1 < CommandLine.arguments.count {
    lang = CommandLine.arguments[i + 1]
    i += 2
  } else if arg == "--text" && i + 1 < CommandLine.arguments.count {
    text = CommandLine.arguments[i + 1]
    i += 2
  } else {
    i += 1
  }
}

if text.isEmpty {
  printStderr("Usage: swift run golden-suggest --lang <lang> --text <text>")
  printStderr("Example: swift run golden-suggest --lang pt --text \"O design ficou ótimo\"")
  exit(1)
}

let analyzer = SentimentAnalyzer()
let analysis = analyzer.analyze(text)

let fixture = GoldenFixture(
  id: deriveID(lang: lang, analysis: analysis),
  text: text,
  language: lang,
  expectedProfanity: analysis.profanity.map(\.text).sorted(),
  expectedFrustration: analysis.frustration.map(\.text).sorted(),
  expectedPositive: analysis.positive.map(\.text).sorted(),
  expectedScoreMin: formatScore(analysis.score - 0.15),
  expectedScoreMax: formatScore(analysis.score + 0.15)
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

guard let jsonData = try? encoder.encode(fixture),
  let jsonString = String(data: jsonData, encoding: .utf8)
else {
  printStderr("Error: Failed to encode fixture")
  exit(1)
}

print(jsonString)
