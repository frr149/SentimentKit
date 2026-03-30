import Foundation

/// Result of analyzing a batch of messages.
public struct SessionAnalysis: Sendable {
    public let messages: [MessageAnalysis]
    public let meanScore: Double
    public let stddev: Double
    public let angryNerdIndex: Double
    public let patienceLevel: Int
    public let topExpressions: [Expression: Int]
    public let language: String?

    public init(
        messages: [MessageAnalysis],
        meanScore: Double,
        stddev: Double,
        angryNerdIndex: Double,
        patienceLevel: Int,
        topExpressions: [Expression: Int],
        language: String?
    ) {
        self.messages = messages
        self.meanScore = meanScore
        self.stddev = stddev
        self.angryNerdIndex = angryNerdIndex
        self.patienceLevel = patienceLevel
        self.topExpressions = topExpressions
        self.language = language
    }
}
