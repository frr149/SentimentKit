# SentimentKit

Multilingual sentiment analysis for Swift. Designed for developer text where Apple's NLTagger fails.

## Why this exists

Apple's `NLTagger` with `.sentimentScore` is the default tool for sentiment analysis in Swift apps. It's free, built-in, and covers 6 languages. But it has a serious problem: **it was trained on consumer reviews, not technical text.**

When you feed it developer messages — the kind you'd write in a coding assistant, a CLI, or a commit message — it produces wildly inaccurate results:

| Message                  | NLTagger score | Reality                |
| ------------------------ | :------------: | ---------------------- |
| "delete the temp file"   |    **-0.8**    | Neutral command        |
| "ok"                     |    **-0.8**    | Neutral acknowledgment |
| "run make test"          |    **-0.6**    | Neutral command        |
| "great job, thanks!"     |      +1.0      | Correct                |
| "this is fucking broken" |      -1.0      | Correct                |
| "commit and push"        |    **-0.4**    | Neutral command        |

NLTagger interprets imperative technical language as negative sentiment. This makes it unusable for analyzing developer sessions, chat logs, CLI interactions, or any context where people give instructions to machines.

Nobody noticed because nobody uses NLTagger for production sentiment analysis. The ML/NLP community ignores it entirely — it doesn't appear in a single academic paper on sentiment analysis in software engineering. We tested it, documented the bias, and built something better.

## What SentimentKit does differently

SentimentKit uses a layered pipeline where cheap deterministic analysis runs first and expensive ML runs last:

```
Message
  │
  ├─ Layer 1: Keyword detector (deterministic, offline, ~20KB)
  │  Matches profanity, frustration, and positive expressions
  │  from curated dictionaries. ES + EN in v1.
  │
  ├─ Layer 2: VADER-inspired rules (deterministic, offline, ~500KB)
  │  Handles negation ("not good"), intensifiers ("very bad"),
  │  CAPS, punctuation. Works for Indo-European languages.
  │
  ├─ Layer 3: CoreML DistilBERT (optional, not bundled in v1)
  │  Multilingual model for when rules aren't enough.
  │  Conversion tooling lives in Tools/CoreMLConversion/.
  │  The model artifact is generated locally, not shipped in the repo.
  │
  └─ Layer 4: LLM scorer (optional, requires API)
     For ambiguous cases only. Never generates expressions.
```

Each layer is optional. v1 ships without the CoreML model; the default package works with keywords + VADER + NLTagger fallback.

## Key features

- **Three expression categories**: profanity (swear words), frustration (irritation without swearing), positive (approval). Cultural differences are normalized into a single **Angry Nerd Index**.
- **Built for developer text**: neutral technical commands ("delete file", "run tests", "commit") score 0, not -0.8.
- **Deterministic first**: keyword matching and VADER rules produce the same result every time. ML is only used when deterministic layers give no signal.
- **Adversarially tested**: golden data fixtures with exact-match assertions. PHANTOM detection (dictionary entries that never match real data) and UNCONSUMED detection (real expressions missing from dictionaries).
- **Multilingual**: ES + EN keywords, Indo-European VADER rules, 12-language CoreML. Extensible with lexicon files.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/frr149/SentimentKit.git", from: "0.1.0"),
]
```

## Quick start

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()

let result = analyzer.analyze("qué coño es esto, no funciona una mierda")
// result.score = -2.0
// result.profanity = ["qué coño", "mierda"]
// result.frustration = []

let neutral = analyzer.analyze("delete the temp file and run make test")
// neutral.score = 0.0
// neutral.profanity = []
```

## Custom dictionaries

Built-in dictionaries are intentionally sparse and conservative. If you need another language or domain-specific vocabulary, bring your own TSV files and merge them into the analyzer config.

```swift
import SentimentKit

let japaneseProfanity = try ExpressionDictionary(contentsOf: URL(filePath: "/path/to/ja-profanity.tsv"))
let japanesePositive = try ExpressionDictionary(contentsOf: URL(filePath: "/path/to/ja-positive.tsv"))

var config = SentimentConfig()
config.additionalDictionaries = [japaneseProfanity, japanesePositive]

let analyzer = SentimentAnalyzer(config: config)
let result = analyzer.analyze("本当にひどい")
```

Dictionary format:

```tsv
# language: ja
# type: profanity
くそ	-1.0
最悪	-1.0
```

This lets users specialize SentimentKit without waiting for built-in support. The deterministic pipeline treats custom dictionaries exactly like bundled ones.

## Session analysis

```swift
let session = analyzer.analyzeSession([
    "perfecto, adelante",
    "esto es una mierda",
    "ok",
    "joder, otra vez",
])

// session.meanScore
// session.angryNerdIndex
// session.patienceLevel
```

## Optional LLM session scoring

The default API stays synchronous and offline-first. If you want an optional remote LLM layer, use the separate async entrypoint.

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()
let scorer = try OpenAISentimentScorer()

let session = try await analyzer.analyzeSession([
    "works now, thanks",
    "this was painful to debug",
], using: scorer)

// `session.meanScore` may be refined by the LLM scorer.
// Expression matches still come only from deterministic layers.
```

The remote scorer only contributes `meanScore`. It never adds, removes, or invents expressions.

Provider wrappers currently included:

- `OpenAISentimentScorer` using OpenAI's Responses API
- `AnthropicSentimentScorer` using Anthropic's Messages API

Both wrappers enforce simple request budgets so the optional LLM layer remains explicit and bounded.

## CoreML layer

The CoreML layer is optional and not bundled with the package in v1. If you want to experiment with the multilingual model locally, generate it from the reproducible conversion pipeline:

```bash
./Tools/CoreMLConversion/convert.sh
```

To compile the generated package with Apple's toolchain:

```bash
./Tools/CoreMLConversion/convert.sh --compile
```

This keeps the SwiftPM package lightweight while preserving a documented path for local model generation.

## Data provenance

The rules for what may enter built-in dictionaries, golden fixtures, or synthetic candidate queues are documented in [docs/DATA_PROVENANCE.md](docs/DATA_PROVENANCE.md).

## License

MIT

## Credits

Built by [Fernando Rodríguez](https://frr.dev).

Inspired by [VADER](https://github.com/cjhutto/vaderSentiment) (Hutto & Gilbert, 2014) and born out of frustration with NLTagger classifying "borra el fichero temporal" as deeply negative.
