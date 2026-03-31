# French Data Sources

This file tracks the first conservative French seed imported after Portuguese and German.

See also `docs/MULTILINGUAL_DATA_SOURCES.md` for the cross-language comparison.

## Decision

French is the third additional bundled language, represented in-package as `fr`.

Reasoning:

- internal logs are not a viable source: they are effectively all Spanish
- the original FEEL site is currently unreachable from this environment
- a public wrapper package (`rfeel`) republishes FEEL-derived polarity data in a reproducible form
- that is good enough for a tiny manual-review seed as long as we document the indirection honestly

## Source

### FEEL via `rfeel`

- Type: French polarity lexicon derived from FEEL
- Source:
  - FEEL paper:
    - `https://www.lirmm.fr/~poncelet/publications/papers/FEEL-LRE-VF-Revised_AmineAbdaoui2016.pdf`
  - public wrapper repository used for data extraction:
    - `https://github.com/ColinFay/rfeel`
- Notes:
  - `rfeel` packages FEEL-derived polarity data in `data/sentiments_polarity.rda`
  - the old direct CSV URL referenced by the wrapper now returns `404`
  - for this repo, treat the imported batch as `reviewed-public-source`, not as a direct official FEEL dump

## First imported seed

The first `fr` seed in this repo is intentionally tiny and only uses short,
low-ambiguity items verified directly inside `rfeel/data/sentiments_polarity.rda`.

Imported expressions:

- profanity: `merde`, `putain`
- frustration: `affreux`, `horrible`, `nul`
- positive: `excellent`, `formidable`, `génial`

Rationale:

- all eight appear directly in the inspected polarity data
- all eight are short and clearly affective
- we deliberately excluded weaker workflow acknowledgments like `merci`
