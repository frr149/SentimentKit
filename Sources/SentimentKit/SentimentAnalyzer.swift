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

        let tokens = MessageTokenizer.tokenize(message)
        let detector = KeywordDetector(dictionaries: BuiltInLexicons.dictionaries + config.additionalDictionaries)
        let matches = detector.detect(in: tokens)
        let vaderRules = BuiltInLexicons.vaderRules
        let adjusted: (score: Double, intensity: Double) = config.enableVADERRules
            ? vaderRules.apply(to: matches.matches, in: message, tokens: tokens)
            : (matches.score, 0.0)
        let visibleMatches = config.enableVADERRules
            ? matches.matches.filter { vaderRules.isNegated($0, tokens: tokens) == false }
            : matches.matches

        let profanity = visibleMatches
            .filter { $0.expression.type == .profanity }
            .map(\.expression)
        let frustration = visibleMatches
            .filter { $0.expression.type == .frustration }
            .map(\.expression)
        let positive = visibleMatches
            .filter { $0.expression.type == .positive }
            .map(\.expression)

        return MessageAnalysis(
            score: max(-2, min(2, adjusted.score)),
            profanity: profanity,
            frustration: frustration,
            positive: positive,
            intensity: adjusted.intensity,
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
