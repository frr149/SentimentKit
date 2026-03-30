import Foundation

/// Public entry point for sentiment analysis.
public struct SentimentAnalyzer: Sendable {
    public let config: SentimentConfig

    public init(config: SentimentConfig = SentimentConfig()) {
        self.config = config
    }

    public func analyze(_ message: String) -> MessageAnalysis {
        guard config.enableKeywords else {
            return .neutral
        }

        let detector = KeywordDetector(dictionaries: config.additionalDictionaries)
        let matches = detector.detect(in: message)

        return MessageAnalysis(
            score: matches.score,
            profanity: matches.profanity,
            frustration: matches.frustration,
            positive: matches.positive,
            intensity: 0,
            language: nil
        )
    }

    public func analyzeSession(_ messages: [String]) -> SessionAnalysis {
        let analyses = messages.map(analyze)
        return Self.makeSessionAnalysis(from: analyses)
    }

    static func makeSessionAnalysis(from analyses: [MessageAnalysis]) -> SessionAnalysis {
        guard analyses.isEmpty == false else {
            return SessionAnalysis(
                messages: [],
                meanScore: 0,
                stddev: 0,
                angryNerdIndex: 0,
                patienceLevel: 0,
                topExpressions: [:],
                language: nil
            )
        }

        let scores = analyses.map(\.score)
        let meanScore = scores.reduce(0, +) / Double(scores.count)
        let variance = scores
            .map { score in
                let delta = score - meanScore
                return delta * delta
            }
            .reduce(0, +) / Double(scores.count)

        let expressionCount = analyses.reduce(into: 0) { total, analysis in
            total += analysis.profanity.count + analysis.frustration.count
        }

        let patienceIndex = analyses.firstIndex { analysis in
            analysis.profanity.isEmpty == false || analysis.frustration.isEmpty == false
        }

        let topExpressions = analyses.reduce(into: [Expression: Int]()) { counts, analysis in
            for expression in analysis.profanity + analysis.frustration + analysis.positive {
                counts[expression, default: 0] += 1
            }
        }

        return SessionAnalysis(
            messages: analyses,
            meanScore: meanScore,
            stddev: variance.squareRoot(),
            angryNerdIndex: Double(expressionCount) / Double(analyses.count),
            patienceLevel: patienceIndex.map { $0 + 1 } ?? 0,
            topExpressions: topExpressions,
            language: dominantLanguage(in: analyses)
        )
    }

    private static func dominantLanguage(in analyses: [MessageAnalysis]) -> String? {
        let counts = analyses.compactMap(\.language).reduce(into: [String: Int]()) { result, language in
            result[language, default: 0] += 1
        }

        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }?.key
    }
}
