# Chinese deterministic lexicons

- Source: NTUSD positive/negative word lists published by National Taiwan University (open under MIT) hosted in the `Chinese_Hate_Speech-Baseline-` repo.
  - Positive words: `https://github.com/chingachleung/Chinese_Hate_Speech-Baseline-/blob/master/NTUSD_positive_sentiment.txt`
  - Negative words: `https://github.com/chingachleung/Chinese_Hate_Speech-Baseline-/blob/master/NTUSD_negative_sentiment.txt`
  - We extracted the entries `一帆风顺`, `开心`, `完美`, `优秀` for `zh-positive.tsv` (+1.0), `糟糕`, `烦死`, `失望`, `烦躁` for `zh-frustration.tsv` (-0.7) and `滚`, `滚蛋`, `去死`, `贱人` for `zh-profanity.tsv` (-1.0).

These tuples are documented in `docs/MULTILINGUAL_DATA_SOURCES.md` so downstream users know which datasets each language relies on.
