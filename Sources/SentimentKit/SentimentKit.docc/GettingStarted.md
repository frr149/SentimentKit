# Getting Started

Create a ``SentimentAnalyzer`` and analyze individual messages or whole sessions.

## Analyze a Message

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()
let result = analyzer.analyze("qué coño es esto, no funciona una mierda")
```

`MessageAnalysis` contains:

- the final numeric `score`
- matched `profanity`
- matched `frustration`
- matched `positive`
- inferred `language`

## Analyze a Session

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()
let session = analyzer.analyzeSession([
    "perfecto, adelante",
    "esto es una mierda",
    "ok",
    "joder, otra vez",
])
```

`SessionAnalysis` aggregates:

- `meanScore`
- `stddev`
- `angryNerdIndex`
- `patienceLevel`
- `topExpressions`

## Add Custom Dictionaries

Built-in dictionaries are intentionally conservative. You can extend them with your own TSV files.

```swift
import SentimentKit

let customDictionary = try ExpressionDictionary(contentsOf: URL(filePath: "/path/to/en-frustration.tsv"))

var config = SentimentConfig()
config.additionalDictionaries = [customDictionary]

let analyzer = SentimentAnalyzer(config: config)
```

## Use the Optional Async LLM Layer

The main API stays synchronous and offline-friendly. If you want an optional hosted scorer, use the async overload.

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()
let scorer = try OpenAISentimentScorer()

let session = try await analyzer.analyzeSession([
    "works now",
    "this spacing looks weird",
], using: scorer)
```

Hosted scorers may replace only `SessionAnalysis.meanScore`. They never invent expressions.

## Data Policy

Built-in dictionaries and golden fixtures follow the provenance rules documented in `docs/DATA_PROVENANCE.md` in the repository.
