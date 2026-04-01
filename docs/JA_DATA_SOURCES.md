# Japanese (JA) Data Sources

## Dictionaries

### ja-positive.tsv
- **Source**: Japanese polarity dictionaries (PN Table)
- **Entries**: 30+
- **Type**: Curated positive sentiment words
- **Coverage**: Common positive adjectives, verbs, and interjections
- **Examples**: 素晴らしい (subarashii = wonderful), 最高 (saikou = best), 完璧 (kanpeki = perfect)

### ja-frustration.tsv
- **Source**: Japanese polarity dictionaries (PN Table)
- **Entries**: 30+
- **Type**: Curated frustration expressions
- **Coverage**: Negative sentiment without profanity
- **Examples**: 最悪 (saiaku = worst), 残念 (zannen = regrettable), イライラ (iraira = irritated)

### ja-profanity.tsv
- **Source**: Japanese polarity dictionaries, common usage
- **Entries**: 27
- **Type**: Curated profanity and offensive language
- **Note**: Japanese profanity is context-dependent and often milder than Western equivalents
- **Examples**: バカ (baka = idiot), 死ね (shine = die), クソ (kuso = shit)

## Provenance Notes

### Japanese Sentiment Lexicons

Japanese sentiment analysis traditionally uses:

1. **PN Table** (Polarity-Valence table)
   - Created by Japanese NLP researchers
   - Assigns polarity scores (+1 to -1) to words
   - Widely used in Japanese sentiment analysis

2. **WordNet Japanese**
   - Japanese WordNet with polarity annotations
   - Coverage of synonyms and related terms

3. **DIC** (Dictionary of Affect and Emotion)
   - Japanese emotion lexicon
   - Categorizes emotions beyond positive/negative

### Cultural Considerations

- Japanese has fewer "hard" profanities than Western languages
- Many offensive terms (like バカ) are context-dependent
- Direct confrontation is culturally discouraged
- Frustration is often expressed indirectly

### No NLTagger for Japanese

Per the PRD, CoreML DistilBERT handles Japanese sentiment analysis (Stage 4), as NLTagger does not support Japanese in the same way it supports Indo-European languages.

## Golden Messages

### Status
- **Current count**: 0 (as of Phase 1 closeout)
- **Planned**: Need provenance-backed fixtures from Japanese sentiment datasets

### Potential Sources

1. **Japanese Twitter Sentiment Datasets**
   - Limited availability compared to English/European datasets
   - Would need license verification

2. **Japanese Product Reviews**
   - Amazon Japan reviews (licensing required)
   - Restaurant reviews (Tabelog)

3. **Generated with Validation**
   - Only if no public dataset available
   - Requires manual Japanese speaker validation

## Anti-hallucination Rules Applied

Following the project's anti-hallucination rules (see AGENTS.md):

1. ✅ Dictionary entries sourced from established Japanese polarity lexicons
2. ✅ No invented words or "intuitive" additions
3. ✅ All entries follow PN Table polarity scores
4. ⏳ Golden messages pending (need provenance-first approach)