# Global Findings — 2026-03-31

Preliminary findings from the local prototype scripts over agent archives, scoped to working directories under `~/code`.

These are not the final Tokamak product metrics. They are a review aid and a sanity check for the future implementation.

## Claude

Command used:

```bash
python3 Tools/SessionMining/analyze_claude_usage.py \
  --cwd-pattern /Users/fernando/code/ \
  --top 20
```

High-signal observations:

- `48` sessions across `4` top-level project buckets
- date range: `2026-02-28 -> 2026-03-31`
- `1,533` direct user messages
- `14,079` assistant messages
- `8,576` tool uses
- about `33h 46m` of measured turn duration
- dominant visible projects:
  - `wuwei`
  - `kc-raven`
  - `frr-dev`
  - `qinqin`
- dominant topics:
  - `claude`
  - `linear`
  - `review`
  - `blog`

Interesting / nerdy observations:

- Claude appears especially strong in long, tool-heavy infra / ops sessions in `wuwei`.
- Several of the largest sessions are very plan-driven and operational, not just writing-heavy.
- URL host mix suggests a lot of web-backed research during those sessions.
- `bypassPermissions` dominates the visible permission mode profile.

Important caveat:

- Claude `queue-operation` volume is currently very noisy and may overcount queued prompts or replay-like events. Treat that number as provisional until Tokamak models it more carefully.

## Codex

Command used:

```bash
python3 Tools/SessionMining/analyze_codex_usage.py \
  --cwd-pattern /Users/fernando/code/ \
  --top 20
```

High-signal observations:

- `31` sessions across many repos under `~/code`
- `631` prompts from `history.jsonl`
- `657` user messages from rollout logs
- `2,202` assistant messages
- `3,956` tool calls
- about `331.7M` input tokens
- about `314.7M` cached input tokens
- dominant working directories:
  - `SentimentKit`
  - `wuwei`
  - `qinqin`
  - `tokamak`
- dominant topics:
  - `linear`
  - `claude`
  - `codex`
  - `review`
  - `tests`

Interesting / nerdy observations:

- Codex is extremely tool-heavy. `exec_command` dominates by a large margin.
- The cache ratio is very high, which suggests repeated long-context sessions with strong cache reuse.
- Monday is currently the strongest day in the visible sample.
- Prompt titles reveal a strong bias toward issue triage, reviews, infra analysis, and implementation follow-through.

## Claude vs Codex

What already looks interesting:

- Claude is much more session-heavy in the currently visible `~/code` sample.
- Codex looks more mechanically tool-driven.
- Claude’s current visible mix is more ops / research / writing blended together.
- Codex’s current visible mix is more issue-driven, repo-local, and command-heavy.
- Both systems show strong `Linear` adjacency.
- Both systems deserve per-project breakdowns; the global totals alone hide too much.

## What Tokamak should be careful about

- do not trust stale Claude `sessions-index.json` paths blindly
- do not mix Claude top-level sessions with subagent logs without labelling
- do not present Claude queue-operation counts as hard truth until de-duplicated
- do not pretend Claude and Codex have one-to-one event semantics
- do not ship only global counters; per-project views are essential
