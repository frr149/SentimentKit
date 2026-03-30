#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

cd "$SCRIPT_DIR"

uv sync --python 3.11
uv run python convert_model.py

if [ "${1:-}" = "--compile" ]; then
  rm -rf artifacts/compiled
  mkdir -p artifacts/compiled
  xcrun coremlcompiler compile artifacts/SentimentKitSentiment.mlpackage artifacts/compiled
fi
