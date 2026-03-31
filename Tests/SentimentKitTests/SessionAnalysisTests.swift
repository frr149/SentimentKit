import Testing

@testable import SentimentKit

struct SessionAnalysisTests {
  @Test
  func emptySessionProducesZeroedMetrics() {
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
  func sessionAggregationComputesExpectedMetrics() {
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

  @Test
  func sessionAnalysisTracksPatienceAndTopExpressionsFromRealAnalyzerOutput() {
    let analyzer = SentimentAnalyzer()

    let session = analyzer.analyzeSession([
      "ok",
      "esto es una mierda",
      "joder, otra vez",
      "perfecto, adelante",
    ])

    #expect(session.messages.count == 4)
    #expect(session.patienceLevel == 2)
    #expect(session.angryNerdIndex == 0.5)
    #expect(
      session.topExpressions[Expression(text: "mierda", type: .profanity, language: "es")] == 1)
    #expect(
      session.topExpressions[Expression(text: "joder", type: .profanity, language: "es")] == 1)
    #expect(
      session.topExpressions[Expression(text: "adelante", type: .positive, language: "es")] == 1)
  }
}
