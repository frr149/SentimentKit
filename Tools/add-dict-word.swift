#!/usr/bin/env swift

import Foundation

// MARK: - Add Dictionary Word Script
// Usage: swift run/add-dict-word <language> <type> "<word>" <score>

struct AddDictWord {
  enum ValidationError: Error, LocalizedError {
    case invalidLanguage(String)
    case invalidType(String)
    case invalidScore(String)
    case wordAlreadyExists(String, String)
    case fileNotFound(String)

    var errorDescription: String? {
      switch self {
      case .invalidLanguage(let lang):
        return "Invalid language: '\(lang)'. Valid: es, en, pt, de, fr, zh"
      case .invalidType(let type):
        return "Invalid type: '\(type)'. Valid: profanity, frustration, positive"
      case .invalidScore(let score):
        return "Invalid score: '\(score)'. Must be a number like -1.0, 0.8, 1.5"
      case .wordAlreadyExists(let word, let file):
        return "Word '\(word)' already exists in \(file)"
      case .fileNotFound(let file):
        return "Dictionary file not found: \(file)"
      }
    }
  }

  let validLanguages = ["es", "en", "pt", "de", "fr", "zh"]
  let validTypes = ["profanity", "frustration", "positive"]

  func run() throws {
    let args = CommandLine.arguments

    guard args.count == 5 else {
      printHelp()
      return
    }

    let language = args[1].lowercased()
    let type = args[2].lowercased()
    let word = args[3]
    let scoreString = args[4]

    // Validate language
    guard validLanguages.contains(language) else {
      throw ValidationError.invalidLanguage(language)
    }

    // Validate type
    guard validTypes.contains(type) else {
      throw ValidationError.invalidType(type)
    }

    // Validate score
    guard let score = Double(scoreString) else {
      throw ValidationError.invalidScore(scoreString)
    }

    // Find dictionary file
    let fileName = "\(language)-\(type).tsv"
    let resourcesPath = #file
      .replacingOccurrences(of: "Tools/add-dict-word.swift", with: "Sources/SentimentKit/Resources/dictionaries")
    let filePath = resourcesPath + "/" + fileName

    guard FileManager.default.fileExists(atPath: filePath) else {
      throw ValidationError.fileNotFound(filePath)
    }

    // Read existing entries
    let content = try String(contentsOfFile: filePath, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)

    // Normalize the new word
    let normalizedWord = normalizeWord(word, language: language)

    // Check for existing entries (all entries in the file are already normalized)
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }

      let parts = trimmed.components(separatedBy: "\t")
      let existingWord = parts[0].trimmingCharacters(in: .whitespaces)

      // Since all entries are pre-normalized, just compare directly
      if existingWord == normalizedWord {
        throw ValidationError.wordAlreadyExists(normalizedWord, fileName)
      }
    }

    // Append the new entry (normalized form)
    let newEntry = "\(normalizedWord)\t\(scoreString)"
    let newContent = content + newEntry + "\n"
    try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)

    print("✅ Added '\(normalizedWord)' to \(fileName) with score \(scoreString)")
    if normalizedWord != word {
      print("   (normalized from '\(word)')")
    }
  }

  func normalizeWord(_ word: String, language: String) -> String {
    let strategy: String = language == "zh" ? "cjk" : "generic"

    if strategy == "cjk" {
      // CJK: no accent normalization
      return word.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    } else {
      // Western: full normalization
      return word
        .precomposedStringWithCompatibilityMapping
        .folding(
          options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
          locale: Locale(identifier: "en_US_POSIX")
        )
    }
  }

  func printHelp() {
    print("""
    Usage: swift Tools/add-dict-word.swift <language> <type> "<word>" <score>

    Arguments:
      language  Language code: es, en, pt, de, fr, zh
      type      Dictionary type: profanity, frustration, positive
      word      Word or phrase to add (in quotes if contains spaces)
      score     Sentiment score: negative for profanity, positive for positive

    Examples:
      swift Tools/add-dict-word.swift fr profanity "tabarnac" -1.5
      swift Tools/add-dict-word.swift es positive "genial" 1.0
      swift Tools/add-dict-word.swift zh frustration "头疼" -0.7

    The script will:
      1. Normalize the word (remove accents, lowercase)
      2. Check for duplicates (exact and normalized)
      3. Append to the correct dictionary file

    Dictionary files are at:
      Sources/SentimentKit/Resources/dictionaries/<language>-<type>.tsv
    """)
  }
}

do {
  try AddDictWord().run()
} catch {
  print("Error: \(error.localizedDescription)")
  exit(1)
}