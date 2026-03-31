import Testing

@testable import SentimentKit

struct LanguageDetectionTests {
  @Test
  func spanishMessageDetectsSpanish() {
    let result = SentimentAnalyzer().analyze("esto no funciona bien y me está frustrando bastante")

    #expect(result.language == "es")
  }

  @Test
  func englishMessageDetectsEnglish() {
    let result = SentimentAnalyzer().analyze("this answer is helpful and the structure feels clear")

    #expect(result.language == "en")
  }

  @Test
  func portugueseMessageDetectsPortuguese() {
    let result = SentimentAnalyzer().analyze("isso não funciona bem e estou bastante frustrado")

    #expect(result.language == "pt")
  }

  @Test
  func germanMessageDetectsGerman() {
    let result = SentimentAnalyzer().analyze("das ist wirklich furchtbar und super nervig")

    #expect(result.language == "de")
  }

  @Test
  func frenchMessageDetectsFrench() {
    let result = SentimentAnalyzer().analyze("c'est vraiment horrible mais parfois génial")

    #expect(result.language == "fr")
  }

  @Test
  func mixedSessionUsesDominantLanguage() {
    let analyzer = SentimentAnalyzer()
    let session = analyzer.analyzeSession([
      "esto no funciona nada bien en este contexto",
      "sigue fallando incluso después del cambio",
      "this still breaks sometimes",
    ])

    #expect(session.language == "es")
  }

  @Test
  func codeOnlyMessagesStayNilOrEnglish() {
    let result = SentimentAnalyzer().analyze("git reset --hard")

    #expect(result.language == nil || result.language == "en")
  }

  @Test
  func expressionLanguageComesFromDictionary() throws {
    let custom = try ExpressionDictionary(
      language: "en",
      type: .positive,
      entries: [
        .init(expression: "solid", score: 0.8)
      ]
    )
    let analyzer = SentimentAnalyzer(config: SentimentConfig(additionalDictionaries: [custom]))

    let result = analyzer.analyze("esto ha quedado solid")

    #expect(result.positive.map(\.language) == ["en"])
  }
}
