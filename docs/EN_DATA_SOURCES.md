# English Data Sources

Working notes for `PROD-679`.

This file tracks English-language candidate sources for dictionary and golden-fixture expansion under the rules in `docs/DATA_PROVENANCE.md`.

It is intentionally conservative: a source appearing here does not mean its contents are already approved for import.

## Candidate sources

### 1. Senti4SD gold standard and tooling repository

- Source URL: `https://github.com/collab-uniba/Senti4SD`
- Type: software-engineering-specific sentiment dataset and tool
- Provenance bucket: `verified-from-literature`
- Citation:
  Calefato, F., Lanubile, F., Maiorano, F., Novielli, N. (2018). *Sentiment Polarity Detection for Software Development*. Empirical Software Engineering, 23(3), 1352-1382. DOI: `10.1007/s10664-017-9546-9`
- Licensing note:
  The public repository is published under the MIT license. The repo README states that the classifier is trained and evaluated on a gold standard of over 4K Stack Overflow posts.
- Current import posture:
  Good candidate for English dictionary growth and for extracting short, self-contained golden-expression candidates.
- Risks / review notes:
  Even with a permissive repo license, individual Stack Overflow source texts still deserve attribution-aware handling when promoted into visible fixtures.
- Files inspected for the first import pass:
  - `Senti4SD_GoldStandard_and_DSM/Senti4SD_Train_Test_Partitions/train3098itemPOLARITY.csv`
  - `Senti4SD_GoldStandard_and_DSM/Senti4SD_Train_Test_Partitions/test1326itemPOLARITY.csv`
- First imported EN additions derived from this source:
  - frustration: `doesn't work`, `really hate`, `very annoying`, `really annoying`, `extremely annoying`, `very painful`, `terrible idea`, `extremely frustrating`, `really awful`, `incredibly frustrating`, `absolutely horrible`
  - positive: `works great`, `good luck`, `excellent tool`, `very helpful`
- Golden messages promoted in the `PROD-684` batch:
  - `test1326itemPOLARITY.csv` `t508`: `Excellent tool! Thanks for making it available.`
  - `train3098itemPOLARITY.csv` `t2770`: `Works great !`
  - `test1326itemPOLARITY.csv` `t224`: `@ThiagoLovizzaro no worries, you have to start somewhere ;) good luck in the future!`
  - `test1326itemPOLARITY.csv` `t13`: `When I refactor the following line: using Resharper's "Use Object Initializer", I get the following: I really hate this type of formatting because with longer object names and variables it just gets out of control. How can I get Resharper to do the following?`
  - `test1326itemPOLARITY.csv` `t1725`: `yes I'm having the exact same issue, very annoying!`
  - `test1326itemPOLARITY.csv` `t246`: `Ok this is really annoying, can't find a solution that works !`
  - `test1326itemPOLARITY.csv` `t173`: `I have a table that is referenced by a ton of other tables via foreign keys. I am trying to delete a Document record, and according to my execution plan, SQL Server is doing a clustered index scan on every one of the referencing tables. This is very painful.`
  - `test1326itemPOLARITY.csv` `t4293`: `this is a terrible idea for webapps`
  - `test1326itemPOLARITY.csv` `t399`: `Can't find any manual about changing width of taglist element size. Taglist element is wider than icons I had set. It looks really awful =( Screenshot:`
  - `train3098itemPOLARITY.csv` `t190`: `It's HORRIBLE! No, seriously, I don't like it.`

### 2. Stack Overflow emotion gold standard

- Source URL: `https://github.com/collab-uniba/EmotionDatasetMSR18`
- Type: manually annotated software-engineering emotion dataset
- Provenance bucket: `verified-from-literature`
- Citation:
  Novielli, N., Calefato, F., Lanubile, F. (2018). *A Gold Standard for Emotion Annotation in Stack Overflow*. Proceedings of MSR 2018. DOI: `10.1145/3196398.3196453`
- Licensing note:
  The repository page does not expose an explicit repository license in the metadata we reviewed. The underlying Stack Overflow content is publicly licensed under CC BY-SA, with version depending on post date.
- Supporting license reference:
  `https://stackoverflow.com/help/licensing/`
- Current import posture:
  Candidate for expression discovery and possibly for carefully attributed golden-message promotion.
- Risks / review notes:
  Before importing raw message text into fixtures, review attribution and share-alike implications case by case.

### 3. GitHub polarity gold standard

- Source URL:
  `https://figshare.com/articles/dataset/A_gold_standard_for_polarity_of_emotions_of_software_developers_in_GitHub/11604597`
- Type: manually annotated GitHub pull-request and commit comments
- Provenance bucket: `verified-from-literature`
- Citation:
  Novielli, N., Calefato, F., Dongiovanni, D., Girardi, D., Lanubile, F. (2020). *Can We Use SE-specific Sentiment Analysis Tools in a Cross-Platform Setting?* MSR 2020.
- Licensing note:
  The figshare dataset page reports `CC BY 4.0`.
- Current import posture:
  Strong candidate for English dictionary growth and for manually curated golden-message candidates sourced from GitHub-native communication.
- Risks / review notes:
  Even with a clearer dataset license than raw GitHub scraping, promoted fixtures should remain short, self-contained, and low-ambiguity.
- Files inspected for the first import pass:
  - `github_gold.csv`
- First imported EN additions derived from this source:
  - positive: `good catch`, `nice catch`, `good work`, `great work`, `makes sense`
  - frustration: `don't like`, `looks weird`
- First promoted EN golden messages derived from this source:
  - `Good catch! Did not think of this. Please revert.`
  - `I'm going to revert this then. I don't like the inconsistency between compilation SDKs.`
  - `This spacing looks weird.`
- Golden messages promoted in `PROD-684` (GitHub gold standard figshare 11604597):
  - `good work.` (ID 1723382)
  - `Makes sense.  Thanks for clarifying.` (ID 2501973)
  - `Ah no problem, ... wishing You good luck` (ID 48844)
  - `looks weird ` (ID 422534)
  - `I think there is a bug ... option doesn't work :S` (ID 79602)
- Golden messages promoted in the follow-up batch:
  - `good work!! thx all.` (ID 1766848)
  - `good work, thanks.` (ID 451861)
  - `yeah thx 4 the answer m8 great work` (ID 452151)
  - `broken compile. it needs a uint32 btw    count = 1  and ur chnage = 1  so why changed ?` (ID 1704370)
- Golden messages from the latest batch:
  - `Thanks for your amazing work, Malcrom ^_^` (ID 456384)
  - `Amazing. Well done.` (ID 780502)
  - `That is just amazing. Thank you.` (ID 467985)
  - `and like remark totally useless without crash line at least` (ID 32438)

### 4. Stack Overflow content license reference

- Source URL: `https://stackoverflow.com/help/licensing/`
- Type: platform license reference
- Provenance bucket: reference only
- Licensing note:
  Publicly accessible user contributions on Stack Overflow are licensed under CC BY-SA, with version depending on contribution date.
- Current import posture:
  This is not a dataset by itself. It is the licensing reference we should consult when evaluating Stack Overflow-derived corpora.

## Current decisions

- Preferred first source for English expansion: published SE-domain datasets and replication packages
- Preferred first import targets: dictionary entries and golden expressions
- Highest bar items: full golden messages
- Explicitly forbidden: synthetic LLM-translated messages as golden fixtures

## Next steps

1. Download and inspect the candidate datasets with the clearest licensing first.
2. Record exact files actually used, not just top-level source links.
3. Extract candidate English profanity, frustration, positive, and `must_not_match` phrases into a reviewable staging list.
4. Promote only reviewed evidence into bundled dictionaries and golden fixtures.
