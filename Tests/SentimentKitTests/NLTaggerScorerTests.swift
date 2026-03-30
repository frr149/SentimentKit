import Testing
@testable import SentimentKit

struct NLTaggerScorerTests {
    @Test
    func nltaggerFallbackIsAttenuatedWhenNoKeywordsMatch() throws {
        let scorer = NLTaggerScorer()
        let language = LanguageDetector().detectMessageLanguage("I am disappointed with this response")
        let rawScore = try #require(scorer.score("I am disappointed with this response", languageCode: language))
        let analyzer = SentimentAnalyzer()

        let result = analyzer.analyze("I am disappointed with this response")

        #expect(rawScore < 0)
        #expect(result.score < 0)
        #expect(abs(result.score) < abs(rawScore))
        #expect(result.profanity.isEmpty && result.frustration.isEmpty && result.positive.isEmpty)
    }

    @Test
    func technicalCommandsStayNeutralWithNLTaggerEnabled() {
        let analyzer = SentimentAnalyzer()

        let result = analyzer.analyze("run make test")

        #expect(abs(result.score) <= 0.1)
    }
}
