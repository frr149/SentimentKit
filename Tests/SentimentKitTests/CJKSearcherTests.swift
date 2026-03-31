import Testing

@testable import SentimentKit

struct CJKSearcherTests {
  private let testDict: Set<String> = [
    "太好了",
    "不好",
    "棒",
    "很棒",
    "非常棒",
    "坏",
    "很坏",
  ]

  @Test
  func mergeSingleWord() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["太", "好", "了"])

    #expect(result == ["太好了"])
  }

  @Test
  func mergePreservesNonMatching() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["esto", "es", "太", "好", "了"])

    #expect(result == ["esto", "es", "太好了"])
  }

  @Test
  func greedyPicksLongest() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["非", "常", "棒"])

    #expect(result == ["非常棒"])
  }

  @Test
  func fallbackToShorterMatch() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["不", "好"])

    #expect(result == ["不好"])
  }

  @Test
  func noMatchKeepsOriginal() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["这", "是", "词"])

    #expect(result == ["这", "是", "词"])
  }

  @Test
  func multipleMatches() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge(["太", "好", "了", " ", "不", "好"])

    #expect(result == ["太好了", " ", "不好"])
  }

  @Test
  func maxFourChars() {
    let dict: Set<String> = ["一二三四五"]
    let searcher = CJKSearcher(dictionary: dict)
    let result = searcher.merge(["一", "二", "三", "四", "五"])

    #expect(result == ["一", "二", "三", "四", "五"])
  }

  @Test
  func emptyInput() {
    let searcher = CJKSearcher(dictionary: testDict)
    let result = searcher.merge([])

    #expect(result.isEmpty)
  }

  @Test
  func builtInDictionaryContainsTaileHao() {
    let searcher = BuiltInLexicons.cjkSearcher
    #expect(searcher.contains("太好了") == true)
  }

  // Debug: What tokens are produced for ZH text?
  @Test
  func debugTokenizeTaoHaoLe() {
    let tokens = MessageTokenizer.tokenize("太好了", language: "zh")
    let rawTokens = tokens.map(\.raw)
    // Expect: should contain "太好了" as a single token after CJKSearcher merge
    #expect(rawTokens.contains("太好了"))
  }

  @Test
  func debugTokenizeZheBuShiHuai() {
    let tokens = MessageTokenizer.tokenize("这不是坏", language: "zh")
    let rawTokens = tokens.map(\.raw)
    // These should remain separate for VADER negation to work
    #expect(rawTokens.contains("不"))
    #expect(rawTokens.contains("坏"))
  }

  @Test
  func debugTokenizeZheHenHuai() {
    let tokens = MessageTokenizer.tokenize("这很坏", language: "zh")
    let rawTokens = tokens.map(\.raw)
    #expect(rawTokens.contains("很"))
    #expect(rawTokens.contains("坏"))
  }

  // Debug: What tokens for 非常坏?
  @Test
  func debugTokenizeFeiChangHuai() {
    let tokens = MessageTokenizer.tokenize("这非常坏", language: "zh")
    let rawTokens = tokens.map(\.raw)
    // 非常 should remain separate for VADER intensifier to work
    #expect(rawTokens.contains("非常"))
    #expect(rawTokens.contains("坏"))
  }
}

// MARK: - ZH Sentiment Integration Tests
// These tests document known issues with ZH sentiment detection

struct ZHSentimentIntegrationTests {

  // BUG: 太好了 should be detected as positive
  @Test(.bug("CJKSearcher not merging tokens into sentiment words"))
  func taoHaoLeShouldBePositive() {
    let result = SentimentAnalyzer().analyze("太好了")
    // Currently returns neutral score (~0)
    // Should detect "太好了" as positive
    #expect(result.score > 0.5)
    #expect(result.positive.isEmpty == false)
  }

  // BUG: 这太好了 should detect 太好了 as positive
  @Test(.bug("CJKSearcher not finding sentiment words in mixed content"))
  func zheTaoHaoLeShouldBePositive() {
    let result = SentimentAnalyzer().analyze("这太好了")
    #expect(result.score > 0.5)
    #expect(result.positive.isEmpty == false)
  }

  // Negation with 不 should flip sentiment
  @Test
  func zheBuShiHuaiShouldBePositive() {
    let baseline = SentimentAnalyzer().analyze("这是坏")
    let negated = SentimentAnalyzer().analyze("这不是坏")

    // "这是坏" (this is bad) should be negative
    #expect(baseline.score < 0)

    // "这不是坏" (this is not bad) should be positive or neutral
    #expect(negated.score > baseline.score)
    #expect(negated.score > 0)
  }

  // Intensifier 很/非常 should amplify sentiment
  // "这非常坏" should be MORE negative than "这很坏" because 非常 is stronger than 很
  @Test
  func zheHenHuaiVsZheFeiChangHuai() {
    let baseline = SentimentAnalyzer().analyze("这很坏")
    let intensified = SentimentAnalyzer().analyze("这非常坏")

    // Both should be negative
    #expect(baseline.score < 0)
    #expect(intensified.score < 0)

    // intensified should be MORE negative than baseline
    #expect(intensified.score < baseline.score, "Intensifier 非常 should amplify more than 很")
  }

  // Intensifier 很/非常 should amplify positive sentiment
  // "这非常棒" should be MORE positive than "这很棒" because 非常 is stronger than 很
  @Test
  func zheHenBangVsZheFeiChangBang() {
    let baseline = SentimentAnalyzer().analyze("这很棒")
    let intensified = SentimentAnalyzer().analyze("这非常棒")

    // Both should be positive
    #expect(baseline.score > 0)
    #expect(intensified.score > 0)

    // intensified should be MORE positive than baseline
    #expect(intensified.score > baseline.score, "Intensifier 非常 should amplify more than 很")
  }

  // BUG: Great phrase 太好了 should be strongly positive
  @Test(.bug("太好了 not detected as positive"))
  func taiHaoLeShouldBeStronglyPositive() {
    let result = SentimentAnalyzer().analyze("这太好了")
    #expect(result.score > 0.5)
    #expect(result.positive.contains(where: { $0.text.contains("太") }))
  }
}
