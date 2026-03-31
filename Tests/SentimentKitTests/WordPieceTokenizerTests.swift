import Foundation
import Testing

@testable import SentimentKit

struct WordPieceTokenizerTests {
  @Test
  func encodesPaddedSequenceWithSpecialTokens() throws {
    let tokenizer = try WordPieceTokenizer(
      vocabulary: [
        "[PAD]": 0,
        "[UNK]": 1,
        "[CLS]": 2,
        "[SEP]": 3,
        "this": 4,
        "answer": 5,
        "is": 6,
        "disappointing": 7,
        ".": 8,
      ],
      maximumLength: 8,
      doLowerCase: true
    )

    let encoded = tokenizer.encode("This answer is disappointing.")

    #expect(encoded.inputIDs == [2, 4, 5, 6, 7, 8, 3, 0])
    #expect(encoded.attentionMask == [1, 1, 1, 1, 1, 1, 1, 0])
  }

  @Test
  func fallsBackToWordPieceSplitsAndUnknownToken() throws {
    let tokenizer = try WordPieceTokenizer(
      vocabulary: [
        "[PAD]": 0,
        "[UNK]": 1,
        "[CLS]": 2,
        "[SEP]": 3,
        "dis": 4,
        "##app": 5,
        "##oint": 6,
        "##ing": 7,
      ],
      maximumLength: 8
    )

    let encoded = tokenizer.encode("disappointing mystery")

    #expect(encoded.inputIDs == [2, 4, 5, 6, 7, 1, 3, 0])
    #expect(encoded.attentionMask == [1, 1, 1, 1, 1, 1, 1, 0])
  }
}
