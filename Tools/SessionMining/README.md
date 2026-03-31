# Session Mining

Utilities for mining real user messages from local Claude session archives.

The main use case in this repo is extracting candidate evidence for sentiment
dictionaries and golden fixtures from `~/.claude/projects` without manually
opening huge JSONL files.

## Extract Spanish user messages

```bash
python3 Tools/SessionMining/extract_claude_messages.py \
  --project-pattern frr-dev \
  --assume-language es \
  --limit 50 \
  --format tsv
```

## Include queued user messages too

```bash
python3 Tools/SessionMining/extract_claude_messages.py \
  --project-pattern frr-dev \
  --assume-language es \
  --include-queue-ops \
  --limit 100
```

## Usage analytics

```bash
python3 Tools/SessionMining/analyze_claude_usage.py \
  --project-pattern frr-dev
```

## Extract Codex prompts

```bash
python3 Tools/SessionMining/extract_codex_messages.py \
  --cwd-pattern SentimentKit \
  --language es \
  --limit 50 \
  --format tsv
```

## Mine Spanish sentiment candidates

```bash
python3 Tools/SessionMining/mine_spanish_candidates.py \
  /tmp/sentimentkit_claude_es_detected.jsonl \
  /tmp/sentimentkit_codex_es_detected.jsonl
```

## Codex analytics

```bash
python3 Tools/SessionMining/analyze_codex_usage.py \
  --cwd-pattern SentimentKit
```

## Review artifacts

- `GLOBAL_FINDINGS_2026-03-31.md`: preliminary findings from the prototype run
- `OPENCODE_REVIEW_RUBRIC.md`: checklist for reviewing the later Tokamak implementation

## Notes

- `tasks/*.json` are not chat transcripts; they are task metadata.
- Real transcript data lives under `~/.claude/projects/**/*.jsonl`.
- The extractor ignores:
  - meta user messages
  - `local-command-*` payloads
  - `task-notification` payloads
  - slash commands, unless `--include-slash-commands` is enabled
  - subagent logs
- `--assume-language es` is the right default when you already know a corpus is
  fully Spanish.
- Language detection is heuristic and intentionally simple when you do use it.
  Treat output as a review queue, not as auto-approved golden data.
- Codex extraction now supports the same `--language`, `--assume-language`, and
  `--min-length` filters as the Claude extractor.
