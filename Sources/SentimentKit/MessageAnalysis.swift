import Foundation

/// Result of analyzing a single message.
public struct MessageAnalysis: Sendable, Equatable {
    public let score: Double
    public let profanity: [Expression]
    public let frustration: [Expression]
    public let positive: [Expression]
    public let intensity: Double
    public let language: String?

    public init(
        score: Double,
        profanity: [Expression],
        frustration: [Expression],
        positive: [Expression],
        intensity: Double,
        language: String?
    ) {
        self.score = score
        self.profanity = profanity
        self.frustration = frustration
        self.positive = positive
        self.intensity = intensity
        self.language = language
    }
}

extension MessageAnalysis {
    static let neutral = MessageAnalysis(
        score: 0,
        profanity: [],
        frustration: [],
        positive: [],
        intensity: 0,
        language: nil
    )
}
