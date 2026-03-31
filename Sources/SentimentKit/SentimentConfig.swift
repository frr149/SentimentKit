import Foundation

/// Configuration for the sentiment analyzer pipeline.
public struct SentimentConfig: Sendable {
    public var enableKeywords: Bool
    public var enableVADERRules: Bool
    public var enableNLTagger: Bool
    public var enableCoreML: Bool
    public var coreMLModelURL: URL?
    public var nlTaggerAttenuation: Double
    public var additionalDictionaries: [ExpressionDictionary]

    public init(
        enableKeywords: Bool = true,
        enableVADERRules: Bool = true,
        enableNLTagger: Bool = true,
        enableCoreML: Bool = false,
        coreMLModelURL: URL? = nil,
        nlTaggerAttenuation: Double = 0.5,
        additionalDictionaries: [ExpressionDictionary] = []
    ) {
        self.enableKeywords = enableKeywords
        self.enableVADERRules = enableVADERRules
        self.enableNLTagger = enableNLTagger
        self.enableCoreML = enableCoreML
        self.coreMLModelURL = coreMLModelURL
        self.nlTaggerAttenuation = nlTaggerAttenuation
        self.additionalDictionaries = additionalDictionaries
    }
}
