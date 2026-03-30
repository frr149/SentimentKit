# SentimentKit — Product Requirements Document

**Version**: 1.0
**Date**: 2026-03-30
**Author**: Fernando Rodríguez
**Status**: Approved

## 1. Purpose

SentimentKit is a Swift package for multilingual sentiment analysis, designed for developer/technical text where Apple's NLTagger fails. It uses a layered ETL pipeline: cheap deterministic analysis first, expensive ML last.

## 2. Architecture

### 2.1 Pipeline overview

```
Message (String)
  │
  ├─ Stage 0: Language detection
  │  NLLanguageRecognizer on first N messages of a session.
  │  Result cached for the session. Reliable for phrases >= 5 words.
  │
  ├─ Stage 1: Keyword detector (deterministic, always runs)
  │  Pattern matching against curated dictionaries.
  │  Output: profanity[], frustration[], positive[], keyword_score
  │
  ├─ Stage 2: VADER-inspired rules (deterministic, always runs)
  │  Negation, intensifiers, CAPS, punctuation, conjunction handling.
  │  Modifies keyword_score based on context.
  │  Output: adjusted_score
  │
  ├─ Stage 3: Score combination
  │  If keywords detected: score = adjusted_score (deterministic, reliable)
  │  If no keywords AND NLTagger ≠ 0: score = nltagger × 0.5 (attenuated)
  │  If nothing detected: score = 0 (neutral)
  │  Output: final_score
  │
  └─ Stage 4: CoreML DistilBERT (optional, on-demand)
     Only when Stage 1-3 give ambiguous result (|score| < 0.3 on long messages).
     12 languages including JA, ZH, AR, HI.
     Output: ml_score (replaces final_score if available)
```

### 2.2 Expression categories

| Category        | What it detects             | Score impact   | Examples                          |
| --------------- | --------------------------- | -------------- | --------------------------------- |
| **profanity**   | Unambiguous swear words     | -1.0 per match | joder, mierda, fuck, shit         |
| **frustration** | Irritation without swearing | -0.7 per match | aberración, insufrible, es basura |
| **positive**    | Approval, satisfaction      | +1.0 per match | perfecto, genial, great, awesome  |

### 2.3 Angry Nerd Index

The single user-facing metric that combines profanity and frustration:

```
angry_nerd_index = (profanityCount + frustrationCount) / messageCount
```

This normalizes cultural differences: a Spaniard who swears constantly and a Japanese developer who expresses frustration formally get comparable scores.

### 2.4 VADER-inspired rules

These rules apply to all Indo-European languages. They modify the keyword_score:

| Rule                  | Effect                                     | Example                        |
| --------------------- | ------------------------------------------ | ------------------------------ |
| **Negation**          | Inverts polarity of next expression × 0.75 | "not good" → negative          |
| **Intensifiers**      | Amplifies next expression × 1.3            | "very bad" → more negative     |
| **Diminishers**       | Attenuates next expression × 0.7           | "kind of bad" → less negative  |
| **ALL CAPS**          | Amplifies expression × 1.2                 | "THIS IS BAD" → more negative  |
| **Exclamation**       | Amplifies × (1 + 0.1 per !) up to 1.4      | "bad!!!" → more negative       |
| **Question marks**    | Slight attenuation × 0.9                   | "is this bad?" → less negative |
| **"but" conjunction** | Post-but clause gets 1.5× weight           | "good but bad" → net negative  |

Negation words (per language):

- EN: not, no, never, neither, nobody, nothing, nowhere, hardly, barely, scarcely, don't, doesn't, didn't, isn't, wasn't, wouldn't, couldn't, shouldn't, won't, can't, mustn't
- ES: no, ni, nunca, jamás, tampoco, ningún, ninguno, ninguna, apenas, nadie, nada

Intensifiers (per language):

- EN: very, extremely, really, absolutely, incredibly, totally, utterly, fucking, so, such
- ES: muy, extremadamente, realmente, absolutamente, increíblemente, totalmente, tremendamente, jodidamente, súper, tan

Diminishers (per language):

- EN: kind of, sort of, a bit, slightly, somewhat, barely, hardly
- ES: un poco, algo, ligeramente, apenas, medio

But-conjunctions:

- EN: but, however, although, yet, nevertheless
- ES: pero, sin embargo, aunque, no obstante

## 3. Data model

### 3.1 Public types

```swift
/// Result of analyzing a single message.
public struct MessageAnalysis: Sendable, Equatable {
    public let score: Double           // -2.0 to +2.0
    public let profanity: [Expression] // matched profanity expressions
    public let frustration: [Expression] // matched frustration expressions
    public let positive: [Expression]  // matched positive expressions
    public let intensity: Double       // 0.0 to 1.0 (CAPS, punctuation)
    public let language: String?       // detected language code ("es", "en")
}

/// A matched expression from the dictionary.
public struct Expression: Sendable, Equatable, Hashable {
    public let text: String     // the matched text ("qué coño")
    public let type: ExpressionType
    public let language: String // source dictionary language ("es", "en")
}

/// Expression categories.
public enum ExpressionType: String, Sendable, Codable, CaseIterable {
    case profanity
    case frustration
    case positive
}

/// Result of analyzing a batch of messages (a session).
public struct SessionAnalysis: Sendable {
    public let messages: [MessageAnalysis]
    public let meanScore: Double
    public let stddev: Double
    public let angryNerdIndex: Double   // (profanity + frustration) / messageCount
    public let patienceLevel: Int       // messages until first profanity or frustration (0 = none found)
    public let topExpressions: [Expression: Int] // expression → count
    public let language: String?        // dominant language of the session
}

/// Configuration for the analyzer.
public struct SentimentConfig: Sendable {
    /// Which layers to enable.
    public var enableKeywords: Bool = true
    public var enableVADERRules: Bool = true
    public var enableNLTagger: Bool = true   // attenuated ×0.5
    public var enableCoreML: Bool = false    // requires model in bundle

    /// NLTagger attenuation factor (0.0 to 1.0).
    /// Applied when keywords detect nothing. Default 0.5.
    public var nlTaggerAttenuation: Double = 0.5

    /// Custom dictionaries (merged with built-in).
    public var additionalDictionaries: [ExpressionDictionary] = []
}
```

### 3.2 Dictionary format

Each dictionary is a plain text file with tab-separated values:

```
# language: es
# type: profanity
joder	-1.0
mierda	-1.0
me cago en la puta	-1.5
qué coño	-1.2
```

Fields: `expression<TAB>score`

Multi-word expressions are supported and matched greedily (longest first). The score is the base polarity before VADER rules modify it.

Dictionaries are embedded as bundle resources in `Sources/SentimentKit/Resources/`:

```
Resources/
  dictionaries/
    es-profanity.tsv
    es-frustration.tsv
    es-positive.tsv
    en-profanity.tsv
    en-frustration.tsv
    en-positive.tsv
    en-negation.tsv
    es-negation.tsv
    en-intensifiers.tsv
    es-intensifiers.tsv
    en-diminishers.tsv
    es-diminishers.tsv
```

## 4. Public API

### 4.1 Single message

```swift
let analyzer = SentimentAnalyzer()  // default config
let result = analyzer.analyze("qué coño es esto")
// result.score == -1.2
// result.profanity == [Expression(text: "qué coño", type: .profanity, language: "es")]
```

### 4.2 Session (batch)

```swift
let messages = ["perfecto, adelante", "esto es una mierda", "ok", "joder, otra vez"]
let session = analyzer.analyzeSession(messages)
// session.meanScore, session.angryNerdIndex, session.patienceLevel, etc.
```

### 4.3 Configuration

```swift
var config = SentimentConfig()
config.enableCoreML = true
config.enableNLTagger = false  // disable if not wanted
let analyzer = SentimentAnalyzer(config: config)
```

### 4.4 Custom dictionaries

```swift
let customDict = try ExpressionDictionary(contentsOf: url)
var config = SentimentConfig()
config.additionalDictionaries = [customDict]
let analyzer = SentimentAnalyzer(config: config)
```

## 5. Adversarial testing strategy

This is the most critical section. SentimentKit is built by an LLM and used to analyze human emotions. Both the code AND the data can contain hallucinations. Every claim must be mechanically verified.

### 5.1 Golden data

Two fixture files, hand-curated and version-controlled:

#### `Fixtures/golden/messages.json`

~80 messages with exact expected results:

```json
[
  {
    "id": "gold-es-001",
    "text": "qué coño es esto, no funciona una mierda",
    "language": "es",
    "expected_profanity": ["qué coño", "mierda"],
    "expected_frustration": [],
    "expected_positive": [],
    "expected_score_min": -2.0,
    "expected_score_max": -1.5,
    "note": "Two profanity matches, no frustration"
  },
  {
    "id": "gold-en-neutral-001",
    "text": "delete the temp file and run make test",
    "language": "en",
    "expected_profanity": [],
    "expected_frustration": [],
    "expected_positive": [],
    "expected_score_min": 0.0,
    "expected_score_max": 0.0,
    "note": "REGRESSION: must be neutral. NLTagger scores this -0.6"
  },
  {
    "id": "gold-en-negation-001",
    "text": "this is not good at all",
    "language": "en",
    "expected_profanity": [],
    "expected_frustration": [],
    "expected_positive": [],
    "expected_score_min": -1.0,
    "expected_score_max": -0.5,
    "note": "Negation rule: 'not' inverts 'good'"
  },
  {
    "id": "gold-es-frustration-001",
    "text": "esto es una aberración, chapucero total",
    "language": "es",
    "expected_profanity": [],
    "expected_frustration": ["aberración", "chapucero"],
    "expected_positive": [],
    "expected_score_min": -1.5,
    "expected_score_max": -0.8,
    "note": "Frustration without profanity"
  },
  {
    "id": "gold-noise-001",
    "text": "borra el fichero temporal",
    "language": "es",
    "expected_profanity": [],
    "expected_frustration": [],
    "expected_positive": [],
    "expected_score_min": 0.0,
    "expected_score_max": 0.0,
    "note": "REGRESSION: 'borra' is a command, not profanity. Haiku hallucinated this."
  },
  {
    "id": "gold-noise-002",
    "text": "huelga decir que exterminio no es la solución",
    "language": "es",
    "expected_profanity": [],
    "expected_frustration": [],
    "expected_positive": [],
    "expected_score_min": -0.5,
    "expected_score_max": 0.0,
    "note": "REGRESSION: 'huelga', 'exterminio' are not profanity. Haiku hallucinated these."
  }
]
```

#### `Fixtures/golden/expressions.json`

Every dictionary entry with its correct classification, plus entries that must NOT match:

```json
{
  "must_match": [
    { "text": "joder", "type": "profanity", "language": "es" },
    { "text": "fuck", "type": "profanity", "language": "en" },
    { "text": "aberración", "type": "frustration", "language": "es" },
    { "text": "perfect", "type": "positive", "language": "en" }
  ],
  "must_not_match": [
    { "text": "borra", "note": "command, not profanity" },
    { "text": "huelga", "note": "neutral word" },
    { "text": "exterminio", "note": "technical context" },
    { "text": "hehco", "note": "typo, not profanity" },
    { "text": "murió", "note": "technical context" },
    { "text": "animal", "note": "ambiguous" },
    { "text": "ok", "note": "neutral acknowledgment" },
    { "text": "delete", "note": "technical command" },
    { "text": "kill", "note": "technical command (kill process)" },
    { "text": "abort", "note": "technical command (abort operation)" },
    { "text": "execute", "note": "technical command" },
    { "text": "dump", "note": "technical command (dump data)" },
    { "text": "die", "note": "technical (die/dice in German, die() in PHP)" },
    { "text": "crash", "note": "technical term" },
    { "text": "fatal", "note": "technical term (fatal error)" },
    { "text": "panic", "note": "technical term (kernel panic)" },
    { "text": "destroy", "note": "technical term (destroy object)" },
    { "text": "nuke", "note": "technical slang (nuke the cache)" }
  ]
}
```

### 5.2 Test suites

#### `GoldenMessageTests.swift`

For each golden message:

1. Run `analyzer.analyze(message.text)`
2. Assert `result.profanity` matches `expected_profanity` **exactly** (no more, no less)
3. Assert `result.frustration` matches `expected_frustration` **exactly**
4. Assert `result.positive` matches `expected_positive` **exactly**
5. Assert `result.score` is within `[expected_score_min, expected_score_max]`

**Zero tolerance. One mismatch = red test.**

#### `GoldenExpressionTests.swift`

1. For each `must_match`: verify the expression exists in the dictionary with correct type and language
2. For each `must_not_match`: verify the expression does NOT exist in any dictionary
3. Verify that analyzing a message containing each `must_not_match` word alone produces score = 0

#### `DictionaryCoverageTests.swift`

- **PHANTOM**: expression in dictionary that matches zero golden messages → warning (needs golden case or removal)
- **UNCONSUMED**: expression in golden messages that's not in any dictionary → error (needs adding)
- Every dictionary entry must appear in at least one golden message or be flagged

#### `NegationTests.swift`

Specific tests for VADER rules:

- "not good" → negative (negation inverts positive)
- "not bad" → slightly positive (negation inverts negative, attenuated)
- "no es bueno" → negative (Spanish negation)
- "never been better" → positive (double negation)
- "very bad" → more negative than "bad" (intensifier)
- "un poco malo" → less negative than "malo" (diminisher)
- "good but bad" → net negative (but-conjunction weighting)

#### `NeutralCommandTests.swift`

REGRESSION GUARD. These must ALL score 0.0 ± 0.1:

```
"delete the temp file"
"run make test"
"commit and push"
"borra el fichero temporal"
"ejecuta los tests"
"ok"
"sí"
"no" (as response, not negation)
"usa .foregroundStyle(.tertiary)"
"cambia el var por let"
"git reset --hard"
"kill the process"
"nuke the cache"
"drop the database"
"abort the operation"
```

If any of these scores outside [-0.1, 0.1], the test fails. This is the primary defense against the NLTagger bias problem.

#### `SessionAnalysisTests.swift`

- Angry Nerd Index calculation with known inputs
- Patience level = correct message index
- meanScore and stddev match expected values
- topExpressions ranked correctly
- Empty session → all zeros

#### `LanguageDetectionTests.swift`

- Spanish messages → "es"
- English messages → "en"
- Mixed messages → dominant language
- Code-only messages → nil or "en"
- Expression language comes from dictionary, not from message

### 5.3 Anti-hallucination rules

These rules are for Codex/any LLM implementing this PRD:

1. **NEVER invent dictionary entries** without evidence from real user sessions. If unsure whether an expression is profanity or frustration, mark it with `# UNVERIFIED` in the TSV and add a golden test that the maintainer must review.

2. **NEVER add technical terms to any sentiment dictionary.** Words like "kill", "abort", "crash", "fatal", "destroy", "nuke", "dump", "die", "panic", "execute" are technical terms in developer context. If in doubt, add to `must_not_match` in golden expressions.

3. **NEVER generate golden data.** Golden messages must come from real user sessions or established sentiment datasets (SST-2, TASS, SemEval). Synthetic messages are allowed ONLY for the `NeutralCommandTests` regression guards and must be clearly labeled.

4. **NEVER use NLTagger score as primary signal.** It is always attenuated (×0.5) and only used when keywords detect nothing. The NeutralCommandTests exist to catch regressions.

5. **Every dictionary change must come with a golden test.** Adding a word? Add a golden message that contains it. Removing a word? Verify no golden message expects it.

6. **Every bug fix must come with a golden message that would have caught the bug.** No golden message → no merge.

### 5.4 CI gate

```bash
make test          # All tests including golden
make coverage      # Golden messages covered by dictionary (PHANTOM/UNCONSUMED report)
make lint          # SwiftLint
make check         # test + coverage + lint (CI gate)
```

## 6. Implementation phases

### Phase 1: Core (keyword detector + VADER rules)

- [ ] `SentimentAnalyzer` with `analyze()` and `analyzeSession()`
- [ ] `KeywordDetector`: load TSV dictionaries, greedy multi-word matching, dedup
- [ ] `VADERRules`: negation, intensifiers, diminishers, CAPS, punctuation, but-conjunction
- [ ] `ExpressionDictionary`: parser for TSV format, validation
- [ ] ES dictionaries: profanity (~60 entries), frustration (~30 entries), positive (~40 entries)
- [ ] EN dictionaries: profanity (~40 entries), frustration (~20 entries), positive (~30 entries)
- [ ] Negation/intensifier/diminisher word lists for ES and EN
- [ ] Golden messages fixture (~80 messages)
- [ ] Golden expressions fixture (all entries + must_not_match)
- [ ] All test suites: GoldenMessage, GoldenExpression, DictionaryCoverage, Negation, NeutralCommand, SessionAnalysis, LanguageDetection
- [ ] `Makefile` with test, coverage, lint, check targets
- [ ] `CLAUDE.md` with anti-hallucination rules

### Phase 2: NLTagger integration

- [ ] `NLTaggerScorer`: wraps NLTagger as attenuated secondary signal
- [ ] Language detection via `NLLanguageRecognizer`
- [ ] Integration into pipeline Stage 3
- [ ] Tests verifying attenuation works correctly
- [ ] Tests verifying NeutralCommandTests still pass with NLTagger enabled

### Phase 3: CoreML DistilBERT (optional layer)

- [ ] Convert `lxyuan/distilbert-base-multilingual-cased-sentiments-student` to CoreML with INT8 quantization
- [ ] `CoreMLScorer`: loads model on-demand, runs inference
- [ ] Integration into pipeline Stage 4
- [ ] Tests for 12 languages
- [ ] On-Demand Resources support (model downloaded separately)
- [ ] Fallback: if model not available, pipeline works without it

### Phase 4: LLM scorer (optional layer)

- [ ] `SentimentScorer` protocol
- [ ] `AnthropicSentimentScorer` implementation (Haiku)
- [ ] `OpenAISentimentScorer` implementation (GPT-4o-mini)
- [ ] LLM only contributes meanScore, NEVER expressions
- [ ] Rate limiting and cost control
- [ ] Tests with mock LLM responses

## 7. Non-goals (v1)

- Training custom ML models (use pre-trained DistilBERT)
- Languages beyond ES + EN for keyword dictionaries (tracked in separate issues)
- Emoji sentiment analysis (defer to Phase 3 CoreML)
- Sarcasm detection (extremely hard, defer)
- Real-time streaming analysis (batch is fine)

## 8. Success criteria

1. All golden tests pass (zero tolerance)
2. NeutralCommandTests: all technical commands score 0.0 ± 0.1
3. Known profanity matches 100% (no false negatives on dictionary entries)
4. Zero false positives on `must_not_match` list
5. PHANTOM count = 0 (every dictionary entry has a golden test)
6. UNCONSUMED count = 0 (every golden expression is in a dictionary)
7. `swift test` completes in < 5 seconds

## 9. References

- [VADER: Valence Aware Dictionary and sEntiment Reasoner](https://github.com/cjhutto/vaderSentiment) (Hutto & Gilbert, ICWSM 2014)
- [On Negative Results When Using Sentiment Analysis Tools for SE Research](https://link.springer.com/article/10.1007/s10664-016-9493-x) (Jongeling et al., 2017)
- [Sentiment Analysis Tools in SE: Systematic Mapping](https://arxiv.org/html/2502.07893v1) (2025)
- [NLTagger sentimentScore bias on Reddit](https://swiftrocks.com/sentiment-analysis-reddit-negativity) (SwiftRocks)
- [DistilBERT multilingual sentiment](https://huggingface.co/lxyuan/distilbert-base-multilingual-cased-sentiments-student) (lxyuan)
- [Deploying Transformers on Apple Neural Engine](https://machinelearning.apple.com/research/neural-engine-transformers) (Apple, 2022)
- [Pattern sentiment lexicons](https://github.com/clips/pattern) (CLiPS, BSD/PDDL)
