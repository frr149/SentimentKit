import Foundation
import NaturalLanguage

struct NLTaggerScorer: Sendable {
    func score(_ message: String, languageCode: String?) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = message

        if let languageCode {
            let language = NLLanguage(rawValue: languageCode)
            tagger.setLanguage(language, range: message.startIndex..<message.endIndex)
        }

        guard let rawValue = tagger.tag(
            at: message.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        ).0?.rawValue else {
            return nil
        }

        guard let score = Double(rawValue), score.isFinite else {
            return nil
        }

        return score
    }
}
