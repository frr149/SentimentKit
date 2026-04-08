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
  │  Multilingual model for long ambiguous messages only.
  │  Conversion tooling lives in Tools/CoreMLConversion/.
  │  The model artifact is generated locally, not shipped in the repo.
  │
  └─ Layer 4: LLM scorer (optional)
     For ambiguous cases only. Never generates expressions.
     Cloud: OpenAI, Anthropic (requires API key).
     On-device: Apple Intelligence via FoundationModels
     (macOS 26+ / iOS 26+, no API key, no network).
```

Each layer is optional. v1 ships without the CoreML model; the default package works with keywords + VADER + NLTagger fallback.
CoreML is only consulted when you explicitly enable it and the deterministic pipeline still produces an ambiguous result on a longer message.

## Key features

- **Three expression categories**: profanity (swear words), frustration (irritation without swearing), positive (approval). Cultural differences are normalized into a single **Angry Nerd Index**.
- **Built for developer text**: neutral technical commands ("delete file", "run tests", "commit") score 0, not -0.8.
- **Deterministic first**: keyword matching and VADER rules produce the same result every time. ML is only used when deterministic layers give no signal.
- **Adversarially tested**: golden data fixtures with exact-match assertions. PHANTOM detection (dictionary entries that never match real data) and UNCONSUMED detection (real expressions missing from dictionaries).
- **Multilingual**: 8 languages with built-in dictionaries (ES, EN, PT, DE, FR, ZH, JA, KO), Indo-European VADER rules, 12-language CoreML. Extensible with custom lexicon files.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/frr149/SentimentKit.git", from: "1.0.0"),
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

Built-in dictionaries cover ES, EN, PT, DE, FR, ZH, JA, and KO. For additional languages or domain-specific vocabulary, bring your own TSV files and merge them into the analyzer config.

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

The default API stays synchronous and offline-first. If you want an optional LLM layer, use the separate async entrypoint.

### On-device with Apple Intelligence (no API key, no network)

```swift
import SentimentKit

let analyzer = SentimentAnalyzer()
let scorer = try AppleIntelligenceScorer()  // macOS 26+ / iOS 26+

let session = try await analyzer.analyzeSession([
    "works now, thanks",
    "this was painful to debug",
], using: scorer)
```

Runs entirely on-device via Apple's FoundationModels framework (~3B parameter model). Typical latency: ~600ms for a session of 50 messages. Check availability at runtime with `AppleIntelligenceScorer.isAvailable`.

### Cloud providers

```swift
let scorer = try OpenAISentimentScorer()
// or
let scorer = try AnthropicSentimentScorer()
```

All scorers only contribute `meanScore`. They never add, remove, or invent expressions.

Provider wrappers currently included:

- `AppleIntelligenceScorer` using Apple Intelligence on-device (FoundationModels, macOS 26+/iOS 26+)
- `OpenAISentimentScorer` using OpenAI's Responses API
- `AnthropicSentimentScorer` using Anthropic's Messages API

All wrappers enforce simple request budgets so the LLM layer remains explicit and bounded.

## CoreML layer

The CoreML layer is optional and not bundled with the package in v1. If you want to experiment with the multilingual model locally, generate it from the reproducible conversion pipeline:

```bash
./Tools/CoreMLConversion/convert.sh
```

To compile the generated package with Apple's toolchain:

```bash
./Tools/CoreMLConversion/convert.sh --compile
```

The generated package is the INT8-quantized `SentimentKitSentiment.mlpackage`. The conversion tooling also leaves an intermediate `SentimentKitSentiment.raw.mlpackage` for inspection, but that artifact is not what the package expects to load by default.

You can already wire a locally generated model into the public API:

```swift
import SentimentKit

var config = SentimentConfig()
config.enableCoreML = true
config.coreMLModelURL = URL(filePath: "/path/to/SentimentKitSentiment.mlpackage")

let analyzer = SentimentAnalyzer(config: config)
```

When CoreML is enabled, it is still not part of the hot path for every message. The analyzer only asks CoreML for a score when all of these are true:

- `enableCoreML == true`
- the tokenized message has at least 8 tokens
- the pre-CoreML score is still ambiguous (`abs(score) < 0.3`)

That keeps the deterministic path as the default and reserves the model for borderline cases.

Current status of distribution:

- there is no hosted model URL yet
- the package must keep working when the model is absent
- the generated model must stay next to its tokenizer directory: `SentimentKitSentiment.tokenizer/`
- if either artifact is missing, SentimentKit falls back to the deterministic pipeline

What is validated today:

- the package falls back cleanly when the model or tokenizer is missing
- a locally generated model produces directionally correct positive/negative scores in smoke tests
- the analyzer integrates with an explicit local model path without breaking the deterministic pipeline

What is not claimed yet:

- no benchmark-backed latency numbers are published in the repo
- no final accuracy/F1 comparison between deterministic-only and deterministic+CoreML is published yet

This keeps the SwiftPM package lightweight while preserving a documented path for local model generation and integration testing before distribution is finalized.

## Data provenance

The rules for what may enter built-in dictionaries, golden fixtures, or synthetic candidate queues are documented in [AGENTS.md](AGENTS.md) (anti-hallucination rules).

Golden messages source datasets:

- ES/EN/PT/DE/FR: [cardiffnlp/tweet_sentiment_multilingual](https://huggingface.co/datasets/cardiffnlp/tweet_sentiment_multilingual) (CC BY-SA 3.0)
- ZH: [sepidmnorozy/Chinese_sentiment](https://huggingface.co/datasets/sepidmnorozy/Chinese_sentiment)

## Golden messages

144 golden fixtures with exact-match assertions: ES (35), EN (35), PT (20), DE (19), FR (20), ZH (15). JA/KO dictionaries are included but golden fixtures are pending provenance-first sourcing.

## License

MIT

## Credits

Built by [Fernando Rodríguez](https://frr.dev).

Inspired by [VADER](https://github.com/cjhutto/vaderSentiment) (Hutto & Gilbert, 2014) and born out of frustration with NLTagger classifying "borra el fichero temporal" as deeply negative.
