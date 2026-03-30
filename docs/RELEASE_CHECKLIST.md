# Release Checklist

Release process for publishing SentimentKit as a Swift package.

## Before tagging

- verify the working tree is clean
- run `swift test`
- run `make check`
- confirm README examples still match the public API
- confirm DocC overview and getting-started pages still match the public API
- confirm `docs/DATA_PROVENANCE.md` and `docs/EN_DATA_SOURCES.md` reflect the latest imported data

## Versioning

- choose the next semantic version tag, for example `0.1.0`
- update any release notes or changelog material
- create and push the git tag

## GitHub release

- create a GitHub Release from the pushed tag
- summarize the main user-visible changes
- call out any optional layers that are not bundled, especially CoreML
- link to the PR and relevant issues when useful

## Swift package distribution

- verify `Package.swift` still resolves cleanly from a fresh checkout
- verify the package can be added from the GitHub repository URL
- submit or refresh the package metadata on Swift Package Index if needed

## Documentation

- ensure `Sources/SentimentKit/SentimentKit.docc/` is present and up to date
- ensure public symbols have enough documentation comments for DocC output to be useful
- keep README short; package API guidance should live primarily in DocC
