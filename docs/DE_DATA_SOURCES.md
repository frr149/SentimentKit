# German Data Sources

This file tracks the first conservative German seed imported after Portuguese.

See also `docs/MULTILINGUAL_DATA_SOURCES.md` for the cross-language comparison.

## Decision

German is the next language after Portuguese, represented in-package as `de`.

Reasoning:

- internal logs are not a viable source: they are effectively all Spanish
- `SentiWS` is a public, weighted German sentiment lexicon with inflected forms
- it is strong enough for a tiny manual-review seed focused on obvious affective vocabulary

## Source

### SentiWS 2.0

- Type: German sentiment lexicon
- Source:
  - `https://www.wortschatz.uni-leipzig.de/en/download`
  - direct download used for review:
    - `https://downloads.wortschatz-leipzig.de/etc/SentiWS/SentiWS_v2.0.zip`
- Notes:
  - mature polarity resource with explicit weights
  - broad general-domain coverage, so manual filtering is mandatory
  - useful for short positive and frustration adjectives, plus obvious profanity variants

## First imported seed

The first `de` seed in this repo is intentionally tiny and only uses short,
low-ambiguity items verified directly inside `SentiWS_v2.0_Positive.txt` and
`SentiWS_v2.0_Negative.txt`.

Imported expressions:

- profanity: `scheiße`, `scheisse`
- frustration: `frustrierend`, `furchtbar`, `katastrophal`
- positive: `hervorragend`, `prima`, `super`

Rationale:

- all seven appear directly in the inspected SentiWS archive
- all seven are short and clearly affective
- we deliberately excluded technical or workflow-adjacent terms even when the source scored them

## First imported golden messages

The first `de` full-message fixtures come from:

- dataset: `cardiffnlp/tweet_sentiment_multilingual`
- source URL:
  - `https://huggingface.co/datasets/cardiffnlp/tweet_sentiment_multilingual`

Imported rows:

- `gold-de-cardiff-pos-001`: `german/train.jsonl` row 477
- `gold-de-cardiff-pos-002`: `german/train.jsonl` row 975
- `gold-de-cardiff-neg-001`: `german/train.jsonl` row 202

Rationale:

- all three are short and manually reviewable
- each one contains an exact bundled expression
- this first batch hardens `positive` and `profanity` immediately while we continue looking for stronger `frustration` fixtures
