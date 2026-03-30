# CLAUDE.md — SentimentKit

## Project

Swift package for multilingual sentiment analysis, designed for developer/technical text. See `docs/PRD.md` for the full spec.

## Commands

```bash
swift build           # Build
swift test            # Run all tests (must pass in < 5s)
make check            # Build + test + lint (CI gate)
```

## Stack

- Swift 6, strict concurrency
- macOS 14+ / iOS 17+
- Swift Testing framework (not XCTest)
- No external dependencies (Phase 1)

## Architecture

Layered pipeline: Keywords → VADER rules → NLTagger (attenuated) → CoreML (optional) → LLM (optional).

Each layer is independent and testable. Cheap deterministic layers run first, expensive ML last.

## Anti-hallucination rules (CRITICAL)

This code is written by an LLM. These rules prevent data contamination:

1. **NEVER invent dictionary entries** without evidence from real user sessions. If unsure, mark with `# UNVERIFIED` in the TSV.
2. **NEVER add technical terms to any sentiment dictionary.** Words like "kill", "abort", "crash", "fatal", "destroy", "nuke", "dump", "die", "panic", "execute" are technical terms. If in doubt, add to `must_not_match` in golden expressions.
3. **NEVER generate golden data.** Golden messages must come from real sessions or established datasets. Synthetic messages only for NeutralCommandTests regression guards.
4. **NEVER use NLTagger score as primary signal.** Always attenuated ×0.5, only when keywords detect nothing.
5. **Every dictionary change must come with a golden test.** No golden test → no merge.
6. **Every bug fix must come with a golden message.** No golden message → no merge.
7. **NEVER silence a linter warning.** Fix the code.

## Testing

- `GoldenMessageTests`: exact match on expressions + score range per golden message. Zero tolerance.
- `GoldenExpressionTests`: every dict entry verified, must_not_match enforced.
- `DictionaryCoverageTests`: PHANTOM + UNCONSUMED detection.
- `NeutralCommandTests`: all technical commands must score 0.0 ± 0.1.
- `NegationTests`: VADER rules for negation, intensifiers, diminishers.
- `SessionAnalysisTests`: batch metrics (angryNerdIndex, patience, meanScore).

## Dictionary format

Tab-separated values in `Sources/SentimentKit/Resources/dictionaries/`:

```
# language: es
# type: profanity
joder	-1.0
mierda	-1.0
```

Multi-word expressions matched greedily (longest first).

## Implementation order

Follow `docs/PRD.md` Phase 1 checklist exactly. Do not skip ahead to Phase 2/3/4.
