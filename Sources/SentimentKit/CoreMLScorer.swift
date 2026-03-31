@preconcurrency import CoreML
import Foundation
import os.lock

enum CoreMLScorerError: Error, Equatable, LocalizedError {
  case missingModel(String)

  var errorDescription: String? {
    switch self {
    case .missingModel(let name):
      return "CoreML model not found: \(name)"
    }
  }
}

struct CoreMLScorer: Sendable {
  private static let modelCache = ModelCache()
  private static let tokenizerCache = TokenizerCache()

  let modelName: String
  let sequenceLength: Int

  init(modelName: String = "SentimentKitSentiment", sequenceLength: Int = 128) {
    self.modelName = modelName
    self.sequenceLength = sequenceLength
  }

  func modelURL(in bundle: Bundle = .module) -> URL? {
    bundle.url(forResource: modelName, withExtension: "mlmodelc")
      ?? bundle.url(forResource: modelName, withExtension: "mlpackage")
      ?? bundle.url(forResource: modelName, withExtension: "mlmodel")
  }

  func loadModel(in bundle: Bundle = .module) throws -> MLModel {
    guard let url = modelURL(in: bundle) else {
      throw CoreMLScorerError.missingModel(modelName)
    }

    return try loadModel(at: url)
  }

  func loadModel(at url: URL) throws -> MLModel {
    if let cached = Self.modelCache.model(for: url) {
      return cached
    }

    let loadURL: URL
    switch url.pathExtension {
    case "mlmodelc":
      loadURL = url
    case "mlpackage", "mlmodel":
      loadURL = try MLModel.compileModel(at: url)
    default:
      loadURL = url
    }

    let model = try MLModel(contentsOf: loadURL)
    Self.modelCache.store(model, for: url)
    return model
  }

  func scoreIfAvailable(_ message: String, languageCode: String?, in bundle: Bundle = .module)
    -> Double?
  {
    guard let modelURL = modelURL(in: bundle) else {
      return nil
    }

    return scoreIfAvailable(message, languageCode: languageCode, modelURL: modelURL, bundle: bundle)
  }

  func scoreIfAvailable(
    _ message: String, languageCode: String?, modelURL: URL, bundle: Bundle = .module
  ) -> Double? {
    let _ = languageCode
    guard let model = try? loadModel(at: modelURL),
      let tokenizer = try? loadTokenizer(forModelAt: modelURL, in: bundle),
      let provider = makeFeatureProvider(for: message, tokenizer: tokenizer),
      let prediction = try? model.prediction(from: provider),
      let logits = extractLogits(from: prediction)
    else {
      return nil
    }

    return score(fromLogits: logits)
  }

  private func loadTokenizer(forModelAt modelURL: URL, in bundle: Bundle) throws
    -> WordPieceTokenizer
  {
    if let cached = Self.tokenizerCache.tokenizer(for: modelURL) {
      return cached
    }

    let tokenizer: WordPieceTokenizer
    if let bundleVocabularyURL = bundle.url(
      forResource: "vocab", withExtension: "txt", subdirectory: "tokenizer")
    {
      tokenizer = try WordPieceTokenizer(
        vocabularyURL: bundleVocabularyURL, maximumLength: sequenceLength)
    } else {
      let siblingTokenizerURL =
        modelURL
        .deletingLastPathComponent()
        .appendingPathComponent("\(modelName).tokenizer", isDirectory: true)
        .appendingPathComponent("vocab.txt")
      tokenizer = try WordPieceTokenizer(
        vocabularyURL: siblingTokenizerURL, maximumLength: sequenceLength)
    }

    Self.tokenizerCache.store(tokenizer, for: modelURL)
    return tokenizer
  }

  private func makeFeatureProvider(for message: String, tokenizer: WordPieceTokenizer)
    -> MLDictionaryFeatureProvider?
  {
    let encoded = tokenizer.encode(message)
    guard let inputIDs = makeArray(encoded.inputIDs),
      let attentionMask = makeArray(encoded.attentionMask)
    else {
      return nil
    }

    return try? MLDictionaryFeatureProvider(
      dictionary: [
        "input_ids": MLFeatureValue(multiArray: inputIDs),
        "attention_mask": MLFeatureValue(multiArray: attentionMask),
      ]
    )
  }

  private func makeArray(_ values: [Int32]) -> MLMultiArray? {
    guard
      let array = try? MLMultiArray(shape: [1, NSNumber(value: values.count)], dataType: .int32)
    else {
      return nil
    }

    for (index, value) in values.enumerated() {
      array[index] = NSNumber(value: value)
    }
    return array
  }

  private func extractLogits(from provider: MLFeatureProvider) -> [Double]? {
    for outputName in provider.featureNames {
      guard let multiArray = provider.featureValue(for: outputName)?.multiArrayValue else {
        continue
      }

      let values = multiArray.toDoubles()
      if values.count >= 3 {
        return Array(values.suffix(3))
      }
    }
    return nil
  }

  private func score(fromLogits logits: [Double]) -> Double {
    let probabilities = softmax(logits)
    guard probabilities.count >= 3 else {
      return 0
    }

    let positive = probabilities[0]
    let negative = probabilities[2]
    return max(-2, min(2, (positive - negative) * 2))
  }

  private func softmax(_ logits: [Double]) -> [Double] {
    guard let maxLogit = logits.max() else {
      return []
    }

    let exponentials = logits.map { Foundation.exp($0 - maxLogit) }
    let sum = exponentials.reduce(0, +)
    guard sum > 0 else {
      return Array(repeating: 0, count: logits.count)
    }

    return exponentials.map { $0 / sum }
  }
}

private final class ModelCache: @unchecked Sendable {
  private let lock = OSAllocatedUnfairLock(initialState: [String: MLModel]())

  func model(for url: URL) -> MLModel? {
    lock.withLock { models in
      models[url.standardizedFileURL.path]
    }
  }

  func store(_ model: MLModel, for url: URL) {
    lock.withLock { models in
      models[url.standardizedFileURL.path] = model
    }
  }
}

private final class TokenizerCache: @unchecked Sendable {
  private let lock = OSAllocatedUnfairLock(initialState: [String: WordPieceTokenizer]())

  func tokenizer(for url: URL) -> WordPieceTokenizer? {
    lock.withLock { tokenizers in
      tokenizers[url.standardizedFileURL.path]
    }
  }

  func store(_ tokenizer: WordPieceTokenizer, for url: URL) {
    lock.withLock { tokenizers in
      tokenizers[url.standardizedFileURL.path] = tokenizer
    }
  }
}

extension MLMultiArray {
  fileprivate func toDoubles() -> [Double] {
    (0..<count).map { index in
      self[index].doubleValue
    }
  }
}
