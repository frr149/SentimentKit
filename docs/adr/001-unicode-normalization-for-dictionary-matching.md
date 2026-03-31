# ADR-001: Unicode Normalization for Dictionary Matching

**Status**: Accepted
**Date**: 2026-03-31

## Context

`SentimentKit` matches curated dictionary expressions against real user text.

That looks simple until Unicode reality shows up:

- accented vs unaccented forms
  - `ótimo` vs `otimo`
  - `péssimo` vs `pessimo`
- canonically equivalent strings that render the same but are encoded differently
  - precomposed NFC: `ó`
  - decomposed NFD: `o + U+0301`
- width and compatibility variants that should not create false misses

Without a strict normalization policy, the system becomes fragile in exactly the
wrong place: the deterministic matcher.

That creates multiple classes of bugs:

1. real messages fail to match obvious dictionary entries
2. dictionaries accumulate duplicate variants of the same expression
3. tests compare raw strings and mask canonical-equivalence problems
4. future contributors normalize ad hoc in different files, producing silent drift

This is not a minor implementation detail. It is part of the correctness
contract of the matcher.

## Decision

### 1. One normalization entry point

All deterministic text normalization for dictionary matching must go through:

- `TextNormalization.normalizeToken(_:language:)`
- `TextNormalization.normalizeExpression(_:language:)`

No other production code path may perform Unicode normalization directly for the
dictionary matcher.

### 2. Unicode normalization policy

The normalization entry point must:

1. canonicalize Unicode consistently
2. remove diacritic sensitivity for matching purposes
3. normalize case
4. normalize width / compatibility variants
5. preserve the original matched expression text returned to callers

The matcher should compare normalized forms, but public results must keep the
dictionary entry text, not the normalized internal form.

### 3. Language-specific strategies are allowed, but only inside the same point

Different languages may eventually need slightly different normalization
strategies.

Examples:

- Turkish dotted/dotless `i`
- language-specific apostrophe behavior
- future edge cases in languages added later

That is acceptable **only** if the branching happens inside `TextNormalization`.

We do **not** allow each matcher, tokenizer, dictionary loader, or test helper
to invent its own language-specific normalization.

So the architecture is:

```swift
TextNormalization.normalizeToken(_:language:)
TextNormalization.normalizeExpression(_:language:)
```

with internal strategy selection by language when necessary.

### 4. The normalizer is part of the test contract

Tests must explicitly cover:

- accented vs unaccented equivalence
- NFC vs NFD equivalence
- duplicate dictionary entries after canonical normalization
- no regression in golden-expression lookup

### 5. Add a normalization lint guard

The repo must contain a test/lint guard that fails when production files bypass
`TextNormalization` and perform Unicode normalization directly.

At minimum, this guard should flag direct usage of:

- `.folding(...)`
- `precomposedStringWith...`
- `decomposedStringWith...`

outside the approved normalization file(s).

Tokenizer implementations with a distinct purpose, such as model-specific
tokenization, may be explicitly whitelisted if they are not part of the
deterministic dictionary matcher.

## Consequences

### Positive

- deterministic matching becomes robust to common Unicode variance
- dictionaries stop growing duplicate orthographic variants
- multilingual support becomes cheaper to maintain
- tests start protecting canonical-equivalence correctness explicitly
- future language-specific special cases still have a controlled home

### Negative

- some existing dictionary entries that were previously allowed as “different”
  raw strings may now become duplicates and must be consolidated
- test helpers that relied on raw-string equality may need to compare
  normalized keys instead
- contributors lose flexibility to normalize ad hoc, by design

## Implementation notes

This ADR applies to the deterministic matcher path:

- dictionary loading
- message tokenization for keyword matching
- phrase matching / lexicon comparison
- test infrastructure that validates dictionary coverage

It does **not** require public APIs to expose normalized strings.
Normalized forms are an internal matching concern.

## Non-goals

This ADR does not attempt to solve:

- stemming / lemmatization
- transliteration across scripts
- language detection
- model tokenization for CoreML / BERT beyond explicitly whitelisted cases

## Acceptance criteria

We consider this ADR implemented when:

1. deterministic matching uses a single normalization point
2. Unicode-equivalent strings match correctly
3. duplicate dictionary entries collapse under canonical normalization
4. a lint/test guard fails on normalization bypasses
5. golden and coverage tests remain green under the new semantics
