Dictionary resources live here.

This directory contains the shipped deterministic dictionaries.

- ES+EN are the active seeded languages.
- `pt` scaffolding is prepared, but it is intentionally still empty until the first reviewed import lands.

Coverage is validated in-repo through:

- `Fixtures/golden/messages.json`
- `Fixtures/golden/expressions.json`
- `GoldenMessageTests`
- `GoldenExpressionTests`
- `DictionaryCoverageTests`

Additions here must stay provenance-backed and must ship with corresponding golden coverage.
