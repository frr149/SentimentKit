#!/usr/bin/env swift

import Foundation

// MARK: - Normalize Dictionaries Script
// One-shot script to pre-normalize all dictionary TSV files
// Run: swift Tools/normalize-dictionaries.swift

struct NormalizeDictionaries {
  
  let resourcesPath = {
    let scriptPath = #file
    return scriptPath
      .replacingOccurrences(of: "Tools/normalize-dictionaries.swift", with: "Sources/SentimentKit/Resources/dictionaries")
  }()
  
  func run() throws {
    print("🔍 Scanning dictionaries in: \(resourcesPath)")
    
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(atPath: resourcesPath)
    
    var tsvFiles: [String] = []
    while let file = enumerator?.nextObject() as? String {
      if file.hasSuffix(".tsv") {
        tsvFiles.append(file)
      }
    }
    
    print("📂 Found \(tsvFiles.count) TSV files\n")
    
    var totalChanges = 0
    var changesByFile: [String: [(original: String, normalized: String)]] = [:]
    
    for file in tsvFiles.sorted() {
      let filePath = resourcesPath + "/" + file
      let changes = try normalizeFile(at: filePath)
      
      if !changes.isEmpty {
        changesByFile[file] = changes
        totalChanges += changes.count
      }
    }
    
    // Print summary
    print("\n" + String(repeating: "=", count: 60))
    print("SUMMARY")
    print(String(repeating: "=", count: 60))
    
    if totalChanges == 0 {
      print("✅ All entries are already normalized. No changes needed.")
    } else {
      print("📝 \(totalChanges) entries normalized across \(changesByFile.count) files:\n")
      
      for (file, changes) in changesByFile.sorted(by: { $0.key < $1.key }) {
        print("📄 \(file):")
        for change in changes {
          print("   \(change.original) → \(change.normalized)")
        }
        print("")
      }
      
      print("✅ All TSV files have been updated.")
    }
  }
  
  private func normalizeFile(at path: String) throws -> [(original: String, normalized: String)] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)
    
    // Extract language from filename (e.g., "es-profanity.tsv" → "es")
    let filename = URL(fileURLWithPath: path).lastPathComponent
    let language = filename.components(separatedBy: "-").first ?? "en"
    
    var changes: [(original: String, normalized: String)] = []
    var normalizedLines: [String] = []
    
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      // Comments and empty lines stay as-is
      if trimmed.isEmpty || trimmed.hasPrefix("#") {
        normalizedLines.append(line)
        continue
      }
      
      // Parse TSV: expression \t score
      let parts = line.components(separatedBy: "\t")
      guard parts.count >= 1 else {
        normalizedLines.append(line)
        continue
      }
      
      let originalExpression = parts[0].trimmingCharacters(in: .whitespaces)
      let score = parts.count >= 2 ? parts[1] : ""
      
      // Normalize
      let normalizedExpression = normalizeExpression(originalExpression, language: language)
      
      // Track changes
      if normalizedExpression != originalExpression {
        changes.append((original: originalExpression, normalized: normalizedExpression))
      }
      
      // Rebuild line
      if score.isEmpty {
        normalizedLines.append(normalizedExpression)
      } else {
        normalizedLines.append("\(normalizedExpression)\t\(score)")
      }
    }
    
    // Write back if there were changes
    if !changes.isEmpty {
      let normalizedContent = normalizedLines.joined(separator: "\n")
      try normalizedContent.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    return changes
  }
  
  private func normalizeExpression(_ expression: String, language: String) -> String {
    // Use the same normalization as TextNormalization.swift
    let locale = Locale(identifier: "en_US_POSIX")
    
    return expression
      .precomposedStringWithCompatibilityMapping
      .folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: locale
      )
  }
}

// Run
do {
  try NormalizeDictionaries().run()
} catch {
  print("❌ Error: \(error)")
  exit(1)
}