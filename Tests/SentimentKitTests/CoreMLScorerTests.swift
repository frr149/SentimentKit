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
}
