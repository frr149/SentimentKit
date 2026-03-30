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
        let modelURL = repositoryRoot()
            .appending(path: "Tools/CoreMLConversion/artifacts/SentimentKitSentiment.mlpackage")

        guard FileManager.default.fileExists(atPath: modelURL.path()) else {
            return
        }

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

    private func repositoryRoot() -> URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
