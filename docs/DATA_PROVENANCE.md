# Data Provenance Policy

SentimentKit analyzes human emotional language. That makes data provenance part of the product, not an afterthought.

Every built-in dictionary entry and every golden fixture must be traceable to a real source. Synthetic data may be useful for exploration, but it must not silently become validation data.

## Artifact types

SentimentKit keeps four different data artifacts. They have different trust requirements and should not be mixed together.

### 1. Built-in dictionaries

Files under `Sources/SentimentKit/Resources/dictionaries/`.

These ship with the package and define the expressions the deterministic pipeline can match directly.

Examples:

- profanity dictionaries
- frustration dictionaries
- positive dictionaries
- negation / intensifier / diminisher lists

### 2. Golden message fixtures

`Fixtures/golden/messages.json`

These are full messages with expected sentiment outcomes. They are the strongest regression oracle in the repo, so they require the highest provenance bar.

### 3. Golden expression fixtures

`Fixtures/golden/expressions.json`

These contain expressions we expect to match, plus `must_not_match` noise terms. They validate dictionary coverage and false-positive resistance.

### 4. Candidate-generation sources

These are upstream sources we inspect to propose future dictionary or fixture additions. They do not automatically become repo data.

Examples:

- published SE sentiment corpora
- replication packages
- manually reviewed public GitHub / Stack Overflow examples
- internal verified session data
- synthetic LLM translations proposed for review

## Provenance buckets

Every future data addition should be classified into one of these buckets.

### `verified-real`

Real developer text with clear provenance and manual review.

Examples:

- approved production-session excerpts
- manually curated internal support / engineering conversations
- verified historical data already approved by the maintainer

### `verified-from-literature`

Data backed by a published software-engineering sentiment dataset or replication package, where the original source is already manually annotated or explicitly curated.

Examples:

- Stack Overflow gold-standard datasets from SE papers
- GitHub / Jira / code-review corpora released with manual annotation

### `reviewed-public-source`

Public text that was not originally part of a gold-standard package, but which we manually inspected and approved for a specific use.

Examples:

- a public GitHub PR comment promoted into a dictionary after review
- a Stack Overflow snippet promoted into `must_not_match` after review

### `maintainer-approved-common-vocabulary`

Universally common sentiment or profanity expressions explicitly approved by the maintainer when an external citation would add little value and the risk of hallucination is effectively zero.

Examples:

- basic lexicon words explicitly approved in PR review (`good`, `bad`, `bueno`, `malo`)
- obvious English profanity or emphasis phrases approved in PR review

### `synthetic-candidate`

Automatically generated candidate data that has not yet been verified.

Examples:

- LLM translations from ES to EN
- LLM-proposed lexicon expansions
- automatically mined phrases without manual review

## Admission rules

### Built-in dictionaries

Allowed:

- `verified-real`
- `verified-from-literature`
- `reviewed-public-source`
- `maintainer-approved-common-vocabulary`

Not allowed:

- unreviewed `synthetic-candidate`

### `golden/expressions.json`

Allowed:

- `verified-real`
- `verified-from-literature`
- carefully reviewed `reviewed-public-source`
- `maintainer-approved-common-vocabulary` for short obvious expressions only

Not allowed:

- synthetic data
- weakly sourced or ambiguous public text

### `golden/messages.json`

Allowed:

- `verified-real`
- `verified-from-literature`
- only the clearest self-contained `reviewed-public-source` examples

Not allowed:

- translated synthetic messages
- ambiguous context-dependent comments
- raw unlabeled public text

## English data policy

For English expansion, prefer sources in this order:

1. Software-engineering-specific manually annotated datasets
2. Replication packages released with SE sentiment papers
3. Manually reviewed public Stack Overflow examples
4. Manually reviewed public GitHub examples
5. Synthetic candidate generation for review only

Generic consumer-sentiment datasets are out of scope as seed data. They are high-volume but wrong-domain, and they reproduce the same bias that makes `NLTagger` unreliable on technical text.

## Translation policy

LLM translation from ES to EN is allowed only as candidate generation.

It may help propose likely English equivalents, but it must not be treated as proof of real English usage.

Rules:

- translated data may enter a review queue
- translated data must not enter built-in dictionaries without manual approval
- translated data must never enter golden fixtures directly

## Traceability requirements

When importing a new dataset or promoting new examples into fixtures, record:

- source name
- source URL or repository path
- paper citation, if applicable
- license
- provenance bucket
- what was imported
- who approved it

If a single fixture or dictionary batch comes from a published paper, note the paper citation and license in the importing commit, PR comment, or adjacent documentation.

## Current approved sources

At the time of writing, the repo already relies on these approved sources:

- `docs/PRD.md`
- Tokamak ADR-001 sections explicitly referenced in PR comments for the imported Spanish seed dictionaries
- approved golden seed examples from the PRD
- maintainer approval in PR #1 for basic/common vocabulary and obvious profanity where exact external citation is unnecessary

Synthetic calibration data from Tokamak's generation scripts is explicitly excluded from golden fixtures.
