Dictionary resources live here.

This directory now contains the shipped ES+EN sentiment dictionaries used by the deterministic pipeline.

Coverage is validated in-repo through:

- `Fixtures/golden/messages.json`
- `Fixtures/golden/expressions.json`
- `GoldenMessageTests`
- `GoldenExpressionTests`
- `DictionaryCoverageTests`

Additions here must stay provenance-backed and must ship with corresponding golden coverage.
