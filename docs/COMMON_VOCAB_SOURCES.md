# Common Vocabulary Sources

This note records dictionary entries that are allowed because they are obvious common vocabulary explicitly approved by the maintainer during review, not because they were imported from a named dataset.

Provenance bucket:

- `maintainer-approved-common-vocabulary`

Approval source:

- PR #1 review comments by `frr149`
- rationale: these are common English sentiment/profanity expressions and keeping them does not rely on synthetic generation

Current entries covered by this note:

- `en-frustration`: `frustrating`
- `en-frustration`: `nonsense`
- `en-profanity`: `what the fuck`
- `en-profanity`: `for fuck s sake`
- `en-profanity`: `what the hell`
- `en-profanity`: `shit`
- `en-profanity`: `damn`
- `en-profanity`: `bullshit`
- `en-profanity`: `wtf`
- `en-profanity`: `ffs`

Normalization note:

- `for fuck s sake` is the dictionary-internal normalized form used by the tokenizer
- human-facing spelling may include the apostrophe: `for fuck's sake`
