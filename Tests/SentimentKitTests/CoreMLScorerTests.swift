import Foundation
import Testing

@testable import SentimentKit

struct CoreMLScorerTests {
  @Test
  func missingModelProducesGracefulError() {
    let scorer = CoreMLScorer(modelName: "DefinitelyMissingModel")

    #expect(throws: CoreMLScorerError.missingModel("DefinitelyMissingModel")) {
      try scorer.loadModel()
    }
  }

  @Test
  func enablingCoreMLFallsBackCleanlyWhenNoModelIsBundled() {
    var config = SentimentConfig()
    config.enableCoreML = true
    let analyzerWithCoreML = SentimentAnalyzer(config: config)
    let analyzerWithoutCoreML = SentimentAnalyzer()
    let message = "The interaction was pleasant but slightly confusing overall"

    let withCoreML = analyzerWithCoreML.analyze(message)
    let withoutCoreML = analyzerWithoutCoreML.analyze(message)

    #expect(withCoreML == withoutCoreML)
  }

  @Test
  func localGeneratedModelProducesDirectionalScoresWhenAvailable() throws {
    guard let modelURL = localGeneratedModelURL() else { return }
    let scorer = CoreMLScorer()
    let positive = try #require(
      scorer.scoreIfAvailable(
        "Amazing work. This is excellent.",
        languageCode: "en",
        modelURL: modelURL
      )
    )
    let negative = try #require(
      scorer.scoreIfAvailable(
        "This is horrible and very frustrating.",
        languageCode: "en",
        modelURL: modelURL
      )
    )

    #expect(positive > negative)
    #expect(positive > 0.1)
    #expect(negative < -0.1)
  }

  @Test
  func localGeneratedModelPassesDirectionalSmokeSetWhenAvailable() throws {
    guard let modelURL = localGeneratedModelURL() else { return }

    let scorer = CoreMLScorer()
    let cases: [(String, String, ClosedRange<Double>)] = [
      ("Amazing work. This is excellent.", "en", 0.1...2.0),
      ("This is horrible and very frustrating.", "en", -2.0 ... -0.1),
      ("Excelente trabajo, esto esta genial.", "es", 0.1...2.0),
      ("Esto es horrible y muy frustrante.", "es", -2.0 ... -0.1),
    ]

    for (text, language, expectedRange) in cases {
      let score = try #require(
        scorer.scoreIfAvailable(text, languageCode: language, modelURL: modelURL),
        "Expected local CoreML score for: \(text)"
      )
      #expect(
        expectedRange.contains(score), "\(text) should score inside \(expectedRange), got \(score)")
    }
  }

  @Test
  func localGeneratedModelMatchesGoldenSubsetSignWhenAvailable() throws {
    guard let modelURL = localGeneratedModelURL() else { return }

    let scorer = CoreMLScorer()
    let selectedFixtureIDs: Set<String> = [
      "gold-es-001",
      "gold-es-pos-001",
      "gold-es-frustration-001",
      "gold-es-neg-003",
      "gold-en-senti4sd-pos-001",
      "gold-en-senti4sd-pos-002",
      "gold-en-senti4sd-neg-002",
      "gold-en-senti4sd-neg-007",
    ]

    let fixtures = try FixtureSupport.loadGoldenMessages()
      .filter { selectedFixtureIDs.contains($0.id) }
    #expect(fixtures.count == selectedFixtureIDs.count)

    for fixture in fixtures {
      let score = try #require(
        scorer.scoreIfAvailable(fixture.text, languageCode: fixture.language, modelURL: modelURL),
        "Expected local CoreML score for fixture: \(fixture.id)"
      )

      let midpoint = (fixture.expectedScoreMin + fixture.expectedScoreMax) / 2
      if midpoint > 0.1 {
        #expect(score > 0, "\(fixture.id) should stay positive under CoreML")
      } else if midpoint < -0.1 {
        #expect(score < 0, "\(fixture.id) should stay negative under CoreML")
      } else {
        #expect(abs(score) <= 0.5, "\(fixture.id) should stay near neutral under CoreML")
      }
    }
  }

  @Test
  func localGeneratedModelReturnsNilWhenTokenizerArtifactsAreMissing() throws {
    guard let sourceModelURL = localGeneratedModelURL() else { return }

    let workingDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workingDirectory) }

    let copiedModelURL = workingDirectory.appending(
      path: sourceModelURL.lastPathComponent, directoryHint: .notDirectory)
    try FileManager.default.copyItem(at: sourceModelURL, to: copiedModelURL)

    let scorer = CoreMLScorer()
    let score = scorer.scoreIfAvailable(
      "Amazing work. This is excellent.",
      languageCode: "en",
      modelURL: copiedModelURL
    )

    #expect(score == nil)
  }

  @Test
  func analyzerFallsBackCleanlyWhenExplicitCoreMLURLLacksTokenizerArtifacts() throws {
    guard let sourceModelURL = localGeneratedModelURL() else { return }

    let workingDirectory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: workingDirectory) }

    let copiedModelURL = workingDirectory.appending(
      path: sourceModelURL.lastPathComponent, directoryHint: .notDirectory)
    try FileManager.default.copyItem(at: sourceModelURL, to: copiedModelURL)

    var config = SentimentConfig()
    config.enableCoreML = true
    config.coreMLModelURL = copiedModelURL

    let analyzerWithBrokenCoreML = SentimentAnalyzer(config: config)
    let analyzerWithoutCoreML = SentimentAnalyzer()
    let message = "The interaction was pleasant but slightly confusing overall today"

    let withBrokenCoreML = analyzerWithBrokenCoreML.analyze(message)
    let withoutCoreML = analyzerWithoutCoreML.analyze(message)

    #expect(withBrokenCoreML == withoutCoreML)
  }

  private func localGeneratedModelURL() -> URL? {
    let modelURL = repositoryRoot()
      .appending(path: "Tools/CoreMLConversion/artifacts/SentimentKitSentiment.mlpackage")
    guard FileManager.default.fileExists(atPath: modelURL.path()) else {
      return nil
    }
    return modelURL
  }

  private func repositoryRoot() -> URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
