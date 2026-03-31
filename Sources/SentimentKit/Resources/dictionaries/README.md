Dictionary resources live here.

This directory contains the shipped deterministic dictionaries.

- ES, EN, PT, and DE are the active seeded languages.
- `fr` remains documented as a future language, but it is not bundled yet.

Coverage is validated in-repo through:

- `Fixtures/golden/messages.json`
- `Fixtures/golden/expressions.json`
- `GoldenMessageTests`
- `GoldenExpressionTests`
- `DictionaryCoverageTests`

Additions here must stay provenance-backed and must ship with corresponding golden coverage.
