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
