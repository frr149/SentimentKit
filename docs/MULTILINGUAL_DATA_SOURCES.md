# Multilingual Data Sources

This note tracks candidate external sources for the first language expansion after ES+EN.

## Summary

Current priority order:

1. `pt` (user-facing target: `pt-BR`)
2. `de`
3. `fr`

Why:

- `pt` has the best immediate combination of public lexicons and lower review friction for this repo.
- `de` has a very solid polarity lexicon (`SentiWS`) plus auxiliary resources.
- `fr` has useful emotion resources, but a weaker immediate fit for the profanity / frustration / positive split used by SentimentKit.

Current status:

- `pt`: first reviewed seed imported
- `de`: first reviewed seed imported
- `fr`: first reviewed seed imported

## Portuguese (`pt`)

Use `pt` in resource names and fixtures. `pt-BR` is the target variety, but `NLLanguageRecognizer` reports Portuguese as `pt`.

### Candidate sources

#### SentiLex-PT02

- Type: Portuguese sentiment lexicon
- URLs:
  - `https://b2find.eudat.eu/dataset/b6bd16c2-a8ab-598f-be41-1e7aeecd60d3`
  - `https://search.r-project.org/CRAN/refmans/lexiconPT/html/sentiLex_lem_PT02.html`
- Why it matters:
  - good seed for clearly positive / negative lexical items
  - easy to inspect and filter manually

#### OpLexicon

- Type: Portuguese opinion lexicon with Brazilian-Portuguese relevance
- URLs:
  - `https://ontolp.inf.pucrs.br/Recursos/downloads-OpLexicon.php`
  - `https://www.rdocumentation.org/packages/lexiconPT/versions/0.1.0`
- Why it matters:
  - strongest immediate source for a `pt-BR`-leaning seed
  - likely better than generic multilingual resources for colloquial polarity

#### Multilingual sentence-level dataset

- Type: short sentiment-labeled tweets in multiple languages
- URL:
  - `https://homepages.dcc.ufmg.br/~fabricio/sentiment-languages-dataset/index.htm`
- Why it matters:
  - candidate source for short full-message fixtures after manual review
  - includes Portuguese alongside French and German

## German (`de`)

### Candidate sources

#### SentiWS

- Type: German sentiment lexicon
- URL:
  - `https://www.wortschatz.uni-leipzig.de/en/download`
- Why it matters:
  - mature publicly available German polarity resource
  - explicit weights and inflected forms
  - stronger immediate seed than the current French options

#### German Polarity Clues

- Type: German polarity lexicon
- URL:
  - `https://sentiment.ulliwaltinger.de/`
- Why it matters:
  - useful cross-check for manual review and overlap analysis
  - could help validate items pulled from SentiWS

#### Multilingual sentence-level dataset

- Type: short sentiment-labeled tweets in multiple languages
- URL:
  - `https://homepages.dcc.ufmg.br/~fabricio/sentiment-languages-dataset/index.htm`
- Why it matters:
  - candidate source for self-contained German full-message fixtures

## French (`fr`)

### Candidate sources

#### FEEL

- Type: French Expanded Emotion Lexicon
- URL:
  - `https://advanse.lirmm.fr/feel.php`
- Why it matters:
  - useful candidate source for affective vocabulary
  - less direct fit for our polarity-oriented deterministic buckets

#### Multilingual sentence-level dataset

- Type: short sentiment-labeled tweets in multiple languages
- URL:
  - `https://homepages.dcc.ufmg.br/~fabricio/sentiment-languages-dataset/index.htm`
- Why it matters:
  - likely the cleanest path to early French full-message fixtures

## Import strategy

For any of these languages:

1. Start with tiny manual review batches.
2. Prefer profanity + frustration before broad positive vocabulary.
3. Keep workflow acknowledgments out unless they prove clearly affective in real examples.
4. Treat public lexicons as candidate sources, not auto-imported truth.
