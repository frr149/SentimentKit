import Foundation

/// Public entry point for sentiment analysis.
public struct SentimentAnalyzer: Sendable {
  public let config: SentimentConfig
  private let languageDetector = LanguageDetector()
  private let nlTaggerScorer = NLTaggerScorer()
  private let technicalCommandGuard = TechnicalCommandGuard()
  private let coreMLScorer = CoreMLScorer()

  public init(config: SentimentConfig = SentimentConfig()) {
    self.config = config
  }

  public func analyze(_ message: String) -> MessageAnalysis {
    let language = languageDetector.detectMessageLanguage(message)
    let tokens = MessageTokenizer.tokenize(message, language: language)
    let dictionaryCandidates =
      BuiltInLexicons.dictionaries.map { ($0, allowCrossLanguage: false) }
      + config.additionalDictionaries.map { ($0, allowCrossLanguage: true) }
    let detector = KeywordDetector(dictionaries: dictionaryCandidates)
    let matches =
      config.enableKeywords
      ? detector.detect(in: tokens, language: language)
      : .init(
        profanity: [],
        frustration: [],
        positive: [],
        score: 0,
        matches: []
      )
    let vaderRules = BuiltInLexicons.vaderRules
    let adjusted: (score: Double, intensity: Double) =
      config.enableVADERRules
      ? vaderRules.apply(to: matches.matches, in: message, tokens: tokens)
      : (matches.score, 0.0)
    let visibleMatches =
      config.enableVADERRules
      ? matches.matches.filter { vaderRules.isNegated($0, tokens: tokens) == false }
      : matches.matches

    let profanity =
      visibleMatches
      .filter { $0.expression.type == .profanity }
      .map(\.expression)
    let frustration =
      visibleMatches
      .filter { $0.expression.type == .frustration }
      .map(\.expression)
    let positive =
      visibleMatches
      .filter { $0.expression.type == .positive }
      .map(\.expression)
    let finalScore: Double

    if matches.matches.isEmpty == false {
      finalScore = max(-2, min(2, adjusted.score))
    } else if config.enableNLTagger,
      technicalCommandGuard.shouldSuppressNLTagger(for: message, tokens: tokens) == false,
      let nlTaggerScore = nlTaggerScorer.score(message, languageCode: language)
    {
      finalScore = max(-2, min(2, nlTaggerScore * config.nlTaggerAttenuation))
    } else {
      finalScore = 0
    }

    let maybeCoreMLScore: Double?
    if config.enableCoreML, tokens.count >= 8, abs(finalScore) < 0.3 {
      if let coreMLModelURL = config.coreMLModelURL {
        maybeCoreMLScore = coreMLScorer.scoreIfAvailable(
          message,
          languageCode: language,
          modelURL: coreMLModelURL
        )
      } else {
        maybeCoreMLScore = coreMLScorer.scoreIfAvailable(message, languageCode: language)
      }
    } else {
      maybeCoreMLScore = nil
    }

    return MessageAnalysis(
      score: maybeCoreMLScore ?? finalScore,
      profanity: profanity,
      frustration: frustration,
      positive: positive,
      intensity: adjusted.intensity,
      language: language
    )
  }

  public func analyzeSession(_ messages: [String]) -> SessionAnalysis {
    let sessionLanguage = languageDetector.detectSessionLanguage(messages)
    let analyses = messages.map { message in
      var analysis = analyze(message)
      if analysis.language == nil {
        analysis = MessageAnalysis(
          score: analysis.score,
          profanity: analysis.profanity,
          frustration: analysis.frustration,
          positive: analysis.positive,
          intensity: analysis.intensity,
          language: sessionLanguage
        )
      }
      return analysis
    }
    return Self.makeSessionAnalysis(from: analyses, sessionLanguage: sessionLanguage)
  }

  /// Analyzes a session with the deterministic pipeline first, then lets an optional async scorer
  /// replace only the session-level `meanScore`.
  public func analyzeSession(
    _ messages: [String],
    using scorer: any SentimentScorer
  ) async throws -> SessionAnalysis {
    let baseAnalysis = analyzeSession(messages)
    guard messages.isEmpty == false else {
      return baseAnalysis
    }

    let meanScore = try await scorer.meanScore(for: messages, baseAnalysis: baseAnalysis)
    return baseAnalysis.replacingMeanScore(max(-2, min(2, meanScore)))
  }

  static func makeSessionAnalysis(from analyses: [MessageAnalysis], sessionLanguage: String? = nil)
    -> SessionAnalysis
  {
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
    let variance =
      scores
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
      language: sessionLanguage ?? dominantLanguage(in: analyses)
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
