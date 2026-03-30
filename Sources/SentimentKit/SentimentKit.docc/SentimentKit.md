# ``SentimentKit``

Deterministic-first sentiment analysis for Swift, built for developer text.

## Overview

`SentimentKit` analyzes short messages and whole sessions without depending on consumer-review sentiment models by default.

The package is structured as a layered pipeline:

- Keyword dictionaries for profanity, frustration, and positive language
- VADER-inspired adjustment rules for negation, intensity, and conjunctions
- Optional `NLTagger` fallback when dictionaries find no signal
- Optional async hosted scorers that only refine session-level `meanScore`

Use ``SentimentAnalyzer`` as the main entrypoint.

## Topics

### Essentials

- <doc:GettingStarted>
- ``SentimentAnalyzer``
- ``SentimentConfig``
- ``ExpressionDictionary``

### Optional Hosted Scoring

- ``SentimentScorer``
- ``OpenAISentimentScorer``
- ``AnthropicSentimentScorer``
- ``LLMScoringPolicy``

### Output Types

- ``MessageAnalysis``
- ``SessionAnalysis``
- ``Expression``
- ``ExpressionType``
