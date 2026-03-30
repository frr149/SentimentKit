import Foundation

struct WordPieceTokenizer: Sendable {
    enum Error: Swift.Error, Equatable, LocalizedError {
        case missingVocabulary(URL)
        case missingRequiredToken(String)

        var errorDescription: String? {
            switch self {
            case let .missingVocabulary(url):
                return "Tokenizer vocabulary not found: \(url.path)"
            case let .missingRequiredToken(token):
                return "Tokenizer vocabulary is missing required token: \(token)"
            }
        }
    }

    struct EncodedInput: Sendable, Equatable {
        let inputIDs: [Int32]
        let attentionMask: [Int32]
    }

    let vocabulary: [String: Int]
    let unknownToken: String
    let clsToken: String
    let sepToken: String
    let padToken: String
    let maximumLength: Int

    init(
        vocabulary: [String: Int],
        unknownToken: String = "[UNK]",
        clsToken: String = "[CLS]",
        sepToken: String = "[SEP]",
        padToken: String = "[PAD]",
        maximumLength: Int = 128
    ) throws {
        self.vocabulary = vocabulary
        self.unknownToken = unknownToken
        self.clsToken = clsToken
        self.sepToken = sepToken
        self.padToken = padToken
        self.maximumLength = maximumLength

        for token in [unknownToken, clsToken, sepToken, padToken] {
            guard vocabulary[token] != nil else {
                throw Error.missingRequiredToken(token)
            }
        }
    }

    init(vocabularyURL: URL, maximumLength: Int = 128) throws {
        guard FileManager.default.fileExists(atPath: vocabularyURL.path) else {
            throw Error.missingVocabulary(vocabularyURL)
        }

        let contents = try String(contentsOf: vocabularyURL, encoding: .utf8)
        var vocabulary: [String: Int] = [:]
        for (index, line) in contents.components(separatedBy: .newlines).enumerated() {
            let token = line.trimmingCharacters(in: .newlines)
            guard token.isEmpty == false else {
                continue
            }
            vocabulary[token] = index
        }

        try self.init(vocabulary: vocabulary, maximumLength: maximumLength)
    }

    func encode(_ text: String) -> EncodedInput {
        let baseTokens = basicTokens(from: text)
        let wordPieces = baseTokens.flatMap(wordPieces(for:))

        let clsID = tokenID(for: clsToken)
        let sepID = tokenID(for: sepToken)
        let padID = tokenID(for: padToken)

        let availableTokenBudget = max(0, maximumLength - 2)
        let trimmedPieces = Array(wordPieces.prefix(availableTokenBudget))
        let pieceIDs = trimmedPieces.map(tokenID(for:))

        var inputIDs = [clsID] + pieceIDs + [sepID]
        var attentionMask = Array(repeating: Int32(1), count: inputIDs.count)

        if inputIDs.count < maximumLength {
            let paddingCount = maximumLength - inputIDs.count
            inputIDs += Array(repeating: padID, count: paddingCount)
            attentionMask += Array(repeating: Int32(0), count: paddingCount)
        }

        if inputIDs.count > maximumLength {
            inputIDs = Array(inputIDs.prefix(maximumLength))
            attentionMask = Array(attentionMask.prefix(maximumLength))
        }

        return EncodedInput(inputIDs: inputIDs, attentionMask: attentionMask)
    }

    private func tokenID(for token: String) -> Int32 {
        Int32(vocabulary[token] ?? vocabulary[unknownToken] ?? 0)
    }

    private func wordPieces(for token: String) -> [String] {
        guard token.isEmpty == false else {
            return []
        }

        if vocabulary[token] != nil {
            return [token]
        }

        var pieces: [String] = []
        var startIndex = token.startIndex

        while startIndex < token.endIndex {
            var endIndex = token.endIndex
            var currentPiece: String?

            while startIndex < endIndex {
                let substring = String(token[startIndex..<endIndex])
                let candidate = startIndex == token.startIndex ? substring : "##\(substring)"
                if vocabulary[candidate] != nil {
                    currentPiece = candidate
                    break
                }
                endIndex = token.index(before: endIndex)
            }

            guard let currentPiece else {
                return [unknownToken]
            }

            pieces.append(currentPiece)
            startIndex = endIndex
        }

        return pieces
    }

    private func basicTokens(from text: String) -> [String] {
        guard text.isEmpty == false else {
            return []
        }

        let normalized = text.precomposedStringWithCompatibilityMapping
        var buffer = ""
        var tokens: [String] = []

        func flushBuffer() {
            guard buffer.isEmpty == false else {
                return
            }
            tokens.append(buffer)
            buffer.removeAll(keepingCapacity: true)
        }

        for scalar in normalized.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) {
                flushBuffer()
                continue
            }

            if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                flushBuffer()
                tokens.append(String(scalar).lowercased())
                continue
            }

            buffer.append(String(scalar).lowercased())
        }

        flushBuffer()
        return tokens.filter { $0.isEmpty == false }
    }
}
