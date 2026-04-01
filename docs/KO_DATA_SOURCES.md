# Korean (KO) Data Sources

## Dictionaries

### ko-positive.tsv
- **Source**: Korean sentiment lexicons (KNU - Korea National University)
- **Entries**: 30+
- **Type**: Curated positive sentiment words
- **Coverage**: Common positive adjectives, verbs, and interjections
- **Examples**: 좋다 (jota = good), 최고 (choego = best), 완벽하다 (wanbyeokhada = perfect)

### ko-frustration.tsv
- **Source**: Korean sentiment lexicons (KNU)
- **Entries**: 30+
- **Type**: Curated frustration expressions
- **Coverage**: Negative sentiment without profanity
- **Examples**: 나쁘다 (nappeuda = bad), 짜증나다 (jjajeungnada = annoyed), 힘들다 (himdeulda = difficult)

### ko-profanity.tsv
- **Source**: Korean sentiment lexicons, common usage
- **Entries**: 26
- **Type**: Curated profanity and offensive language
- **Note**: Korean profanity intensity varies by context
- **Examples**: 씨발 (ssibal = fuck), 개새끼 (gaesaekki = bastard), 병신 (byeongsin = idiot)

## Provenance Notes

### Korean Sentiment Lexicons

Korean sentiment analysis uses:

1. **KNU Korean Sentiment Dictionary**
   - Created by Korea National University
   - Polarity scores for Korean words
   - Widely used in Korean NLP

2. **KO-EN WordNet**
   - Korean-English WordNet mappings
   - Useful for cross-lingual sentiment

3. **NSMC** (Naver Sentiment Movie Corpus)
   - Large Korean sentiment dataset
   - Movie reviews with ratings

### Cultural Considerations

- Korean has honorifics that affect sentiment interpretation
- Same word can be positive or negative depending on honorific level
- Direct negative language is often avoided in formal contexts

### No NLTagger for Korean

Per the PRD, CoreML DistilBERT handles Korean sentiment analysis (Stage 4), as NLTagger does not support Korean in the same way it supports Indo-European languages.

## Golden Messages

### Status
- **Current count**: 0 (as of Phase 1 closeout)
- **Planned**: Need provenance-backed fixtures from Korean sentiment datasets

### Potential Sources

1. **NSMC** (Naver Sentiment Movie Corpus)
   - ~200K movie reviews
   - License: Creative Commons
   - Excellent provenance

2. **Korean Product Reviews**
   - Coupang, Naver Shopping reviews
   - License verification needed

3. **News Comments**
   - Naver News comments
   - License issues to verify

## Anti-hallucination Rules Applied

Following the project's anti-hallucination rules (see AGENTS.md):

1. ✅ Dictionary entries sourced from established Korean polarity lexicons
2. ✅ No invented words or "intuitive" additions
3. ✅ All entries follow KNU polarity conventions
4. ⏳ Golden messages pending (need provenance-first approach)