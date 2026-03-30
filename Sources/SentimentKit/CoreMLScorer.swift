import CoreML
import Foundation

enum CoreMLScorerError: Error, Equatable, LocalizedError {
    case missingModel(String)

    var errorDescription: String? {
        switch self {
        case let .missingModel(name):
            return "CoreML model not found: \(name)"
        }
    }
}

struct CoreMLScorer: Sendable {
    let modelName: String

    init(modelName: String = "SentimentKitSentiment") {
        self.modelName = modelName
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

        return try MLModel(contentsOf: url)
    }

    func scoreIfAvailable(_ message: String, languageCode: String?, in bundle: Bundle = .module) -> Double? {
        let _ = message
        let _ = languageCode
        guard (try? loadModel(in: bundle)) != nil else {
            return nil
        }

        // The model asset is not bundled yet. This returns nil until the converted model lands.
        return nil
    }
}
