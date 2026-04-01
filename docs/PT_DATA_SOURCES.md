# Portuguese Data Sources

This file tracks the next language expansion after ES+EN.

See also `docs/MULTILINGUAL_DATA_SOURCES.md` for the comparative view across `pt`, `fr`, and `de`.

## Decision

The next language should be **Portuguese**, represented in-package as `pt`.

Reasoning:

- `pt-BR` is the user-facing target, but `NLLanguageRecognizer` reports Portuguese as `pt`, so dictionary resources and golden fixtures should use `pt`.
- Internal logs are not a viable source here: they are effectively all Spanish.
- Compared with French and German, Portuguese has the strongest immediately usable source stack for a deterministic seed:
  - multiple established Portuguese sentiment lexicons
  - explicit Brazilian-Portuguese coverage via OpLexicon
  - lower review friction because many Spanish expressions have close Portuguese counterparts, which makes manual filtering cheaper

## Why not French or German first

### French

- `FEEL` is useful as a candidate source, but it is primarily an emotion lexicon, not a developer-oriented profanity / frustration / positive seed.
- We do not currently have an internal French corpus to complement it.

### German

- `SentiWS` is mature and useful, but again general-domain.
- We do not currently have an internal German corpus to anchor a first batch of developer-text review.

## Candidate sources

### 1. SentiLex-PT02

- Type: Portuguese sentiment lexicon
- Source:
  - `https://b2find.eudat.eu/dataset/b6bd16c2-a8ab-598f-be41-1e7aeecd60d3`
  - `https://search.r-project.org/CRAN/refmans/lexiconPT/html/sentiLex_lem_PT02.html`
- Notes:
  - Good seed for positive / negative vocabulary review.
  - Needs manual filtering for developer-text relevance.
  - Not enough by itself for profanity-heavy developer slang.

### 2. OpLexicon 3.0

- Type: Portuguese opinion lexicon with Brazilian-Portuguese utility
- Source:
  - `https://www.inf.pucrs.br/linatural/wordpress/recursos-e-ferramentas/oplexicon/`
- Notes:
  - Strong candidate for `pt-BR`-leaning vocabulary.
  - Useful for positive / negative seed review and colloquial forms.
  - Still requires manual review before anything enters dictionaries or golden fixtures.

### 3. Maintainer-reviewed common vocabulary

- Type: maintainer-approved common vocabulary
- Notes:
  - Only for obvious short expressions once external-source review has already anchored the language.
  - Must stay minimal.

## Import policy for the first Portuguese batch

The first `pt` batch should be conservative:

1. Start with `profanity` and `frustration`.
2. Add only the clearest `positive` items.
3. Prefer short self-contained expressions over ambiguous workflow acknowledgments.
4. Do not promote full golden messages until we have a reviewed source with short, self-contained examples.

## Expected next step

1. Review SentiLex-PT02 and OpLexicon manually.
2. Build a candidate queue outside the bundled dictionaries.
3. Promote a tiny `pt` seed with golden coverage.

## First imported seed

The first imported `pt` seed in this repo is intentionally tiny and only uses
items that were easy to verify directly inside `lexiconPT_0.1.0`, which bundles
both `sentiLex_lem_PT02.rda` and `oplexicon_v3.0.rda`.

Imported expressions:

- profanity: `caralho`, `merda`
- frustration: `horrivel`, `ruim`
- positive: `excelente`, `genial`

Rationale:

- all six appear directly in the inspected lexicon package
- all six are short, self-contained, and low-ambiguity
- we deliberately excluded more doubtful items like `obrigado`, which the source
  package labels negatively and therefore looks unsuitable for this repo

## Second imported seed

Follow-up additions from the same verified source package:

- frustration: `horrendo`, `pessimo`, `terrivel`
- positive: `otimo`

These were accepted because both `sentiLex_lem_PT02` and `oplexicon_v3.0`
expose them as short polarity-bearing items with low contextual ambiguity.

Guardrails added:

- `obrigado`
- `obrigada`

These are explicitly covered in `must_not_match` so future imports do not
accidentally treat gratitude as negative sentiment.

## First imported golden messages

The first `pt` full-message fixtures come from:

- dataset: `cardiffnlp/tweet_sentiment_multilingual`
- source URL:
  - `https://huggingface.co/datasets/cardiffnlp/tweet_sentiment_multilingual`

Imported rows:

- `gold-pt-cardiff-pos-001`: `portuguese/train.jsonl` row 375
- `gold-pt-cardiff-pos-002`: `portuguese/train.jsonl` row 780
- `gold-pt-cardiff-neg-001`: `portuguese/train.jsonl` row 1603
- `gold-pt-cardiff-neg-002`: `portuguese/train.jsonl` row 151

Rationale:

- all four are short enough to review manually
- all four contain exact bundled expressions
- they improve coverage for `positive`, `frustration`, and `profanity`

## Second imported golden messages (PROD-753)

Additional `pt` fixtures from `cardiffnlp/tweet_sentiment_multilingual`:

| ID | Row | Expression | Type | Note |
|----|-----|------------|------|------|
| `gold-pt-cardiff-pos-001` | 338 | `maravilha` | positive | Short, clear exclamation |
| `gold-pt-cardiff-pos-002` | 11 | `maravilhoso` | positive | Hair comment |
| `gold-pt-cardiff-pos-003` | 71 | `espetacular` | positive | Ingredient diversity |
| `gold-pt-cardiff-fru-001` | 606 | `lamentavel` | frustration | Pseudoscience criticism |
| `gold-pt-cardiff-fru-002` | 846 | `vergonhoso` | frustration | Culinary knowledge gap |
| `gold-pt-cardiff-fru-003` | 1323 | `absurdo` | frustration | Reality TV criticism |
| `gold-pt-cardiff-pro-001` | 87 | `porra` | profanity | Exasperation |
| `gold-pt-cardiff-pro-002` | 63 | `bosta` | profanity | TV complaint |

Criteria applied:

- Short (<200 chars)
- Contains exactly one expression from bundled PT dictionary
- Label matches expression polarity (label 2 = positive, label 0 = negative)
- No ambiguous matches (filtered "show" as false positive for positive)
- Trazable to specific dataset row
