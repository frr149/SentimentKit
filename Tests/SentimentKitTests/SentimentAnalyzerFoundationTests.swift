import Testing
@testable import SentimentKit

struct SentimentAnalyzerFoundationTests {
    @Test
    func analyzeReturnsNeutralResultUntilDeterministicStagesLand() {
        let analyzer = SentimentAnalyzer()

        let result = analyzer.analyze("delete the temp file")

        #expect(result == .neutral)
    }

    @Test
    func analyzeUsesBundledSeedDictionariesByDefault() {
        let analyzer = SentimentAnalyzer()

        let result = analyzer.analyze("qué coño es esto")

        #expect(result.profanity.map(\.text) == ["qué coño"])
        #expect(result.score < 0)
    }

    @Test
    func analyzeUsesInjectedKeywordDictionaries() throws {
        let profanity = try ExpressionDictionary(
            language: "es",
            type: .profanity,
            entries: [
                .init(expression: "qué coño", score: -1.2),
                .init(expression: "mierda", score: -1.0),
            ]
        )
        let positive = try ExpressionDictionary(
            language: "en",
            type: .positive,
            entries: [
                .init(expression: "great", score: 1.0),
            ]
        )
        let analyzer = SentimentAnalyzer(
            config: SentimentConfig(additionalDictionaries: [profanity, positive])
        )

        let result = analyzer.analyze("Qué coño, this is great... y una mierda")

        #expect(abs(result.score - (-1.2)) < 0.000_001)
        #expect(result.profanity.map(\.text) == ["qué coño", "mierda"])
        #expect(result.positive.map(\.text) == ["great"])
        #expect(result.frustration.isEmpty)
    }

    @Test
    func analyzeSessionReturnsZeroMetricsForEmptyInput() {
        let analyzer = SentimentAnalyzer()

        let session = analyzer.analyzeSession([])

        #expect(session.messages.isEmpty)
        #expect(session.meanScore == 0)
        #expect(session.stddev == 0)
        #expect(session.angryNerdIndex == 0)
        #expect(session.patienceLevel == 0)
        #expect(session.topExpressions.isEmpty)
        #expect(session.language == nil)
    }

    @Test
    func sessionAggregationComputesMetricsFromMessageAnalyses() {
        let expression = Expression(text: "joder", type: .profanity, language: "es")
        let positive = Expression(text: "great", type: .positive, language: "en")

        let analyses = [
            MessageAnalysis(
                score: -1.0,
                profanity: [expression],
                frustration: [],
                positive: [],
                intensity: 0.4,
                language: "es"
            ),
            MessageAnalysis(
                score: 1.0,
                profanity: [],
                frustration: [],
                positive: [positive],
                intensity: 0.2,
                language: "en"
            ),
            MessageAnalysis(
                score: -0.5,
                profanity: [],
                frustration: [],
                positive: [],
                intensity: 0.1,
                language: "es"
            ),
        ]

        let session = SentimentAnalyzer.makeSessionAnalysis(from: analyses)

        #expect(session.messages == analyses)
        #expect(session.meanScore == -0.16666666666666666)
        #expect(session.stddev == 0.8498365855987975)
        #expect(session.angryNerdIndex == 0.3333333333333333)
        #expect(session.patienceLevel == 1)
        #expect(session.topExpressions[expression] == 1)
        #expect(session.topExpressions[positive] == 1)
        #expect(session.language == "es")
    }
}
