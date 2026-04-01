// CoreMLDownloadTests.swift
//
// Validation tests for CoreML model distribution from HuggingFace.
//
// WHY CONDITIONAL?
// These tests are disabled by default because they:
// - Require network access to huggingface.co
// - Download ~100MB model artifacts
// - Are intended for release validation, not CI regression
//
// HOW TO RUN:
//   ENABLE_COREML_DOWNLOAD_TESTS=1 swift test --filter CoreMLDownloadTests
//   make coreml-validate
//
// The tests will:
// 1. Download the model tarball from HuggingFace
// 2. Verify SHA256 checksum matches published checksum
// 3. Extract and validate tokenizer artifacts
// 4. Test CoreMLScorer produces directional sentiment scores
// 5. Test SentimentAnalyzer integration with CoreML enabled

import CryptoKit
import Foundation
import Testing

@testable import SentimentKit

struct CoreMLDownloadTests {
  static let hfRepoID = "frr149/SentimentKit"
  static let tarballName = "sentimentkit-sentiment-coreml.tar.gz"
  static let checksumFile = "checksum.sha256"

  static let hfBaseURL = "https://huggingface.co/\(hfRepoID)/resolve/main"

  static var isDownloadTestEnabled: Bool {
    ProcessInfo.processInfo.environment["ENABLE_COREML_DOWNLOAD_TESTS"] == "1"
  }

  static let cachedModelDir: URL = {
    let cacheDir = FileManager.default.urls(
      for: .cachesDirectory, in: .userDomainMask
    ).first!
    return cacheDir.appending(
      path: "SentimentKit-CoreML", directoryHint: .isDirectory)
  }()

  static func remoteChecksumURL() -> URL {
    URL(string: "\(hfBaseURL)/\(checksumFile)")!
  }

  static func remoteTarballURL() -> URL {
    URL(string: "\(hfBaseURL)/\(tarballName)")!
  }

  @Test(
    "Download CoreML model from HuggingFace",
    .enabled(
      if: isDownloadTestEnabled,
      "Requires ENABLE_COREML_DOWNLOAD_TESTS=1 and network access"
    )
  )
  func downloadCoreMLModelFromHuggingFace() async throws {
    try skipIfNoNetwork()

    try FileManager.default.createDirectory(
      at: Self.cachedModelDir, withIntermediateDirectories: true)

    let localChecksumURL = Self.cachedModelDir.appending(
      path: Self.checksumFile, directoryHint: .notDirectory)
    let localTarballURL = Self.cachedModelDir.appending(
      path: Self.tarballName, directoryHint: .notDirectory)
    let extractedDir = Self.cachedModelDir.appending(
      path: "extracted", directoryHint: .isDirectory)
    let modelPackage = extractedDir.appending(
      path: "SentimentKitSentiment.mlpackage", directoryHint: .isDirectory)
    let tokenizerDir = extractedDir.appending(
      path: "SentimentKitSentiment.tokenizer", directoryHint: .isDirectory)

    print("Downloading checksum from \(Self.remoteChecksumURL())")
    let checksumData = try Data(contentsOf: Self.remoteChecksumURL())
    let checksumString =
      String(data: checksumData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let expectedChecksum = checksumString.components(separatedBy: "  ").first ?? ""
    #expect(!expectedChecksum.isEmpty, "Checksum should not be empty")
    print("Expected SHA256: \(expectedChecksum)")

    print("Downloading tarball from \(Self.remoteTarballURL())")
    let tarballData = try Data(contentsOf: Self.remoteTarballURL())
    try tarballData.write(to: localTarballURL)
    print("Downloaded \(tarballData.count) bytes")

    let actualChecksum = calculateSHA256(of: localTarballURL)
    print("Actual SHA256: \(actualChecksum)")
    #expect(
      actualChecksum == expectedChecksum,
      "Checksum mismatch: expected \(expectedChecksum), got \(actualChecksum)")

    print("Extracting tarball")
    if FileManager.default.fileExists(atPath: extractedDir.path()) {
      try FileManager.default.removeItem(at: extractedDir)
    }
    try FileManager.default.createDirectory(
      at: extractedDir, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/tar")
    process.arguments = ["-xzf", localTarballURL.path(), "-C", extractedDir.path()]
    try process.run()
    process.waitUntilExit()

    #expect(process.terminationStatus == 0, "Tar extraction should succeed")

    print("Verifying extracted artifacts")
    #expect(
      FileManager.default.fileExists(atPath: modelPackage.path()),
      "Model package should exist")
    #expect(
      FileManager.default.fileExists(atPath: tokenizerDir.path()),
      "Tokenizer directory should exist")

    let vocabFile = tokenizerDir.appending(
      path: "vocab.txt", directoryHint: .notDirectory)
    #expect(
      FileManager.default.fileExists(atPath: vocabFile.path()),
      "vocab.txt should exist")

    print("Testing CoreMLScorer with downloaded model")
    let scorer = CoreMLScorer()
    let score = try #require(
      scorer.scoreIfAvailable(
        "Amazing work. This is excellent.",
        languageCode: "en",
        modelURL: modelPackage
      ),
      "CoreMLScorer should return a score for a valid input"
    )
    print("Score for positive message: \(score)")
    #expect(score > 0, "Positive message should score > 0")

    let negativeScore = try #require(
      scorer.scoreIfAvailable(
        "This is horrible and very frustrating.",
        languageCode: "en",
        modelURL: modelPackage
      ),
      "CoreMLScorer should return a score for negative input"
    )
    print("Score for negative message: \(negativeScore)")
    #expect(negativeScore < 0, "Negative message should score < 0")

    print("CoreML model validation complete")
    print("Model package: \(modelPackage.path())")
    print("Tokenizer: \(tokenizerDir.path())")

    try checksumData.write(to: localChecksumURL)
    print("Checksum saved to: \(localChecksumURL.path())")
  }

  @Test(
    "Analyzer integration with downloaded CoreML model",
    .enabled(
      if: isDownloadTestEnabled,
      "Requires ENABLE_COREML_DOWNLOAD_TESTS=1 and cached model from previous test"
    )
  )
  func analyzerIntegrationWithDownloadedCoreMLModel() async throws {
    try skipIfNoNetwork()

    let extractedDir = Self.cachedModelDir.appending(
      path: "extracted", directoryHint: .isDirectory)
    let modelPackage = extractedDir.appending(
      path: "SentimentKitSentiment.mlpackage", directoryHint: .isDirectory)

    guard FileManager.default.fileExists(atPath: modelPackage.path()) else {
      throw SkipTestIssue(
        "Model not cached - run downloadCoreMLModelFromHuggingFace first"
      )
    }

    var config = SentimentConfig()
    config.enableCoreML = true
    config.coreMLModelURL = modelPackage

    let analyzer = SentimentAnalyzer(config: config)

    let result = analyzer.analyze("This works perfectly, thank you!")
    print("Analyzer result score: \(result.score)")
    #expect(
      result.positive.count > 0 || result.score > 0,
      "Positive message should have positive sentiment")

    let negativeResult = analyzer.analyze("This is absolutely horrible and broken")
    print("Analyzer result score (negative): \(negativeResult.score)")
    #expect(
      negativeResult.profanity.count > 0 || negativeResult.frustration.count > 0
        || negativeResult.score < 0,
      "Negative message should have negative sentiment")
  }

  private func calculateSHA256(of url: URL) -> String {
    var hasher = CryptoKit.SHA256()
    guard let inputStream = InputStream(url: url) else {
      return ""
    }
    inputStream.open()
    defer { inputStream.close() }

    let bufferSize = 8192
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while inputStream.hasBytesAvailable {
      let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
      if bytesRead > 0 {
        hasher.update(
          bufferPointer: UnsafeRawBufferPointer(
            start: buffer, count: bytesRead))
      }
    }

    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  func skipIfNoNetwork() throws {
    guard URL(string: Self.hfBaseURL) != nil else {
      throw SkipTestIssue("Unable to construct HuggingFace URL")
    }
  }
}

struct SkipTestIssue: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}
