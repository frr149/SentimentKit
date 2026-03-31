# OpenCode Review Rubric

Use this checklist when reviewing the implementation produced by `opencode` / `glm5` in Tokamak.

## Scope

- Does it analyze more than one project under `~/code`?
- Does it support both Claude and Codex?
- Does it provide a global view?
- Does it provide a per-project breakdown?
- Does it include a comparison layer between Claude and Codex?

## Data correctness

- Does Claude parsing avoid `tasks/*.json` as transcript sources?
- Does it prefer real top-level session JSONL files over stale index paths?
- Does it avoid mixing subagents into top-level stats unless explicitly labelled?
- Does it ignore local-command and task-notification noise?
- Does Codex parsing combine `history.jsonl`, `session_index.jsonl` and `sessions/**/*.jsonl` coherently?

## Metric quality

- Are the metrics genuinely derived from logs rather than guessed?
- Are non-comparable metrics clearly marked as such?
- Are suspicious metrics called out with caveats?
- Does the implementation avoid fake precision?
- Does it distinguish direct user prompts from queued / replayed / synthetic events?

## Product value

- Is there a useful overview for normal users?
- Is there a meaningful per-project view?
- Are there at least a few “nerdy” or playful stats with real user value?
- Does the output help answer how the system is actually being used?

## Technical quality

- Is the implementation dependency-light unless there is a strong reason otherwise?
- Is it robust to missing files, stale indexes and malformed records?
- Is it reasonably fast for local use?
- Is it easy to extend with new metrics later?
- Is the code organized so the parsing layer is separate from the derived-metrics layer?

## Review questions to ask

- Which metrics would you actually show in Nerd Stats v1?
- Which metrics are internal diagnostics only?
- Which numbers are still too noisy to expose?
- Which comparisons between Claude and Codex are real, and which are cosmetic?
- What is the minimum slice that could ship now without misleading the user?

## Red flags

- Hardcoded repo names like `frr-dev` or `SentimentKit`
- Metrics that only work for one project
- Queue-operation counts presented as ground truth without caveats
- Top-level and subagent sessions merged invisibly
- UI-heavy work with weak data modelling underneath
- Fancy charts on top of poor semantics
