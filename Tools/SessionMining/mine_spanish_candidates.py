#!/usr/bin/env python3
"""Mine Spanish sentiment candidates from extracted session JSONL files.

This does not auto-promote anything into dictionaries. It builds a review queue
with evidence counts and representative real-session examples.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CandidateRule:
    phrase: str
    bucket: str
    kind: str
    pattern: str
    rationale: str


RULES = [
    CandidateRule(
        phrase="la puta madre",
        bucket="profanity",
        kind="keep",
        pattern=r"\bla puta madre\b",
        rationale="Direct vulgar outburst with no technical ambiguity.",
    ),
    CandidateRule(
        phrase="hasta los cojones",
        bucket="profanity",
        kind="keep",
        pattern=r"\bhasta los cojones\b",
        rationale="Strong vulgar frustration phrase in real sessions.",
    ),
    CandidateRule(
        phrase="ni hablar",
        bucket="frustration",
        kind="keep",
        pattern=r"\bni hablar\b",
        rationale="Clear rejection/frustration marker in Spanish.",
    ),
    CandidateRule(
        phrase="qué raro",
        bucket="frustration",
        kind="keep",
        pattern=r"\bqué raro\b",
        rationale="Common mild-frustration signal in technical discussion.",
    ),
    CandidateRule(
        phrase="no me convence",
        bucket="frustration",
        kind="keep",
        pattern=r"\bno me convence\b",
        rationale="Clear negative judgement without profanity.",
    ),
    CandidateRule(
        phrase="hay un problema",
        bucket="must_not_match",
        kind="review",
        pattern=r"\bhay un problema\b",
        rationale="Descriptive technical phrase; should stay neutral by default.",
    ),
    CandidateRule(
        phrase="está bien",
        bucket="positive",
        kind="review",
        pattern=r"\bestá bien\b",
        rationale="Often just approval/workflow acknowledgement; ambiguous.",
    ),
    CandidateRule(
        phrase="perfecto",
        bucket="positive",
        kind="review",
        pattern=r"\bperfecto\b",
        rationale="Useful positive signal but often a short workflow acknowledgment.",
    ),
]

IGNORED_PREFIXES = (
    "This session is being continued from a previous conversation",
    "Summary:",
    "Analysis:",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Mine Spanish sentiment candidates from extracted session JSONL."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        type=Path,
        help="Input JSONL files produced by the session extractors.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional markdown output path. Defaults to stdout.",
    )
    parser.add_argument(
        "--max-examples",
        type=int,
        default=3,
        help="Maximum number of example messages per candidate.",
    )
    return parser.parse_args()


def iter_messages(paths: list[Path]) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = []
    for path in paths:
        if not path.exists():
            continue
        with path.open() as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                content = (obj.get("content") or "").strip()
                if not content:
                    continue
                if content.startswith(IGNORED_PREFIXES):
                    continue
                if (
                    "This session is being continued from a previous conversation"
                    in content
                ):
                    continue
                messages.append(
                    {
                        "content": content.replace("\n", " "),
                        "source": str(path),
                        "cwd": str(obj.get("cwd", "")),
                        "session_id": str(obj.get("session_id", "")),
                    }
                )
    return messages


def collect_hits(
    messages: list[dict[str, str]], max_examples: int
) -> dict[CandidateRule, dict[str, object]]:
    results: dict[CandidateRule, dict[str, object]] = {}
    for rule in RULES:
        regex = re.compile(rule.pattern, re.IGNORECASE)
        count = 0
        examples: list[dict[str, str]] = []
        for message in messages:
            if regex.search(message["content"]):
                count += 1
                if len(examples) < max_examples:
                    examples.append(message)
        if count > 0:
            results[rule] = {"count": count, "examples": examples}
    return results


def collect_context_stats(messages: list[dict[str, str]]) -> dict[str, object]:
    by_source = Counter(Path(m["source"]).name for m in messages)
    by_project = Counter()
    for message in messages:
        cwd = message["cwd"]
        parts = Path(cwd).parts
        project = "unknown"
        if "code" in parts:
            idx = parts.index("code")
            if idx + 1 < len(parts):
                project = parts[idx + 1]
        by_project[project] += 1
    return {
        "total_messages": len(messages),
        "top_sources": by_source.most_common(5),
        "top_projects": by_project.most_common(10),
    }


def render_markdown(
    stats: dict[str, object], hits: dict[CandidateRule, dict[str, object]]
) -> str:
    lines: list[str] = []
    lines.append("# Spanish Session Candidate Mining")
    lines.append("")
    lines.append("Real-session review queue for Spanish sentiment evidence.")
    lines.append("")
    lines.append("## Corpus")
    lines.append("")
    lines.append(f"- Messages scanned: {stats['total_messages']}")
    top_projects = ", ".join(
        f"{name}({count})" for name, count in stats["top_projects"]  # type: ignore[index]
    )
    lines.append(f"- Top projects: {top_projects}")
    top_sources = ", ".join(
        f"{name}({count})" for name, count in stats["top_sources"]  # type: ignore[index]
    )
    lines.append(f"- Input files: {top_sources}")
    lines.append("")

    for bucket in ("profanity", "frustration", "must_not_match", "positive"):
        bucket_rules = [
            (rule, payload)
            for rule, payload in hits.items()
            if rule.bucket == bucket
        ]
        if not bucket_rules:
            continue
        lines.append(f"## {bucket}")
        lines.append("")
        for rule, payload in sorted(
            bucket_rules,
            key=lambda item: int(item[1]["count"]),  # type: ignore[arg-type]
            reverse=True,
        ):
            lines.append(
                f"### `{rule.phrase}` ({payload['count']} hits, {rule.kind})"
            )
            lines.append("")
            lines.append(f"- Rationale: {rule.rationale}")
            for example in payload["examples"]:  # type: ignore[index]
                lines.append(
                    f"- Example: `{example['content'][:220]}`"
                )
            lines.append("")

    lines.append("## Notes")
    lines.append("")
    lines.append(
        "- `hay un problema` stays out of sentiment dictionaries: descriptive, not affective."
    )
    lines.append(
        "- Short approvals like `está bien` and `perfecto` need more curation before promotion."
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    missing = [str(path) for path in args.inputs if not path.exists()]
    if missing:
        print(f"Missing inputs: {', '.join(missing)}", file=sys.stderr)
        return 1

    messages = iter_messages(args.inputs)
    if not messages:
        print("No messages found.", file=sys.stderr)
        return 1

    stats = collect_context_stats(messages)
    hits = collect_hits(messages, args.max_examples)
    markdown = render_markdown(stats, hits)

    if args.output:
        args.output.write_text(markdown)
    else:
        print(markdown, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
