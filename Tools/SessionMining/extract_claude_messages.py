#!/usr/bin/env python3
"""Extract real user messages from Claude session JSONL logs.

This is designed for mining candidate golden messages and dictionary evidence
from local `~/.claude/projects` session archives without loading everything
manually into memory.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterator


SPANISH_HINTS = {
    "el",
    "la",
    "los",
    "las",
    "de",
    "del",
    "que",
    "esto",
    "esta",
    "está",
    "hay",
    "para",
    "porque",
    "por",
    "otra",
    "otra vez",
    "quiero",
    "haz",
    "dime",
    "revisa",
    "mira",
    "vale",
    "bien",
    "joder",
    "mierda",
    "coño",
    "cojones",
    "gracias",
    "perfecto",
}

ENGLISH_HINTS = {
    "the",
    "this",
    "that",
    "with",
    "from",
    "please",
    "thanks",
    "thank",
    "good",
    "great",
    "work",
    "fix",
    "review",
    "issue",
}

LOCAL_COMMAND_PREFIXES = (
    "<local-command-caveat>",
    "<local-command-stdout>",
    "<local-command-stderr>",
)

IGNORED_PREFIXES = LOCAL_COMMAND_PREFIXES + (
    "<task-notification>",
)


@dataclass
class MessageRecord:
    project: str
    session_id: str
    timestamp: str
    cwd: str
    source_path: str
    source_type: str
    language: str
    content: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract real user messages from Claude JSONL project logs."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.home() / ".claude" / "projects",
        help="Root folder containing Claude project JSONL logs.",
    )
    parser.add_argument(
        "--project-pattern",
        default=None,
        help="Only include JSONL paths containing this substring.",
    )
    parser.add_argument(
        "--cwd-pattern",
        default=None,
        help="Only include records whose cwd contains this substring.",
    )
    parser.add_argument(
        "--language",
        choices=("es", "en", "unknown"),
        default=None,
        help="Only include records matching this detected language.",
    )
    parser.add_argument(
        "--assume-language",
        choices=("es", "en", "unknown"),
        default=None,
        help="Override language detection and mark every kept record with this language.",
    )
    parser.add_argument(
        "--min-length",
        type=int,
        default=8,
        help="Minimum content length after cleanup.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=200,
        help="Maximum number of output records.",
    )
    parser.add_argument(
        "--include-queue-ops",
        action="store_true",
        help="Include queue-operation enqueue content as user text.",
    )
    parser.add_argument(
        "--include-slash-commands",
        action="store_true",
        help="Keep messages starting with '/'.",
    )
    parser.add_argument(
        "--format",
        choices=("jsonl", "tsv"),
        default="jsonl",
        help="Output format.",
    )
    return parser.parse_args()


def detect_language(text: str) -> str:
    lowered = f" {text.lower()} "
    es_score = 0
    en_score = 0

    if re.search(r"[áéíóúñ¿¡]", lowered):
        es_score += 2

    for hint in SPANISH_HINTS:
        if f" {hint} " in lowered:
            es_score += 1

    for hint in ENGLISH_HINTS:
        if f" {hint} " in lowered:
            en_score += 1

    if es_score > en_score and es_score >= 1:
        return "es"
    if en_score > es_score and en_score >= 1:
        return "en"
    return "unknown"


def iter_session_files(root: Path, project_pattern: str | None) -> Iterator[Path]:
    for path in sorted(root.rglob("*.jsonl")):
        if "/subagents/" in path.as_posix():
            continue
        if project_pattern and project_pattern not in path.as_posix():
            continue
        yield path


def extract_user_content(obj: dict, include_queue_ops: bool) -> tuple[str, str] | None:
    record_type = obj.get("type")

    if record_type == "user":
        if obj.get("isMeta"):
            return None
        message = obj.get("message")
        if not isinstance(message, dict):
            return None
        if message.get("role") != "user":
            return None
        content = message.get("content")
        if isinstance(content, str):
            return ("user", content)
        return None

    if include_queue_ops and record_type == "queue-operation":
        if obj.get("operation") != "enqueue":
            return None
        content = obj.get("content")
        if isinstance(content, str):
            return ("queue-operation", content)

    return None


def should_keep_content(
    text: str, min_length: int, include_slash_commands: bool
) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if stripped.startswith(IGNORED_PREFIXES):
        return False
    if not include_slash_commands and stripped.startswith("/"):
        return False
    if len(stripped) < min_length:
        return False
    return True


def iter_records(args: argparse.Namespace) -> Iterator[MessageRecord]:
    for path in iter_session_files(args.root, args.project_pattern):
        project = path.parent.name
        with path.open() as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                extracted = extract_user_content(obj, args.include_queue_ops)
                if extracted is None:
                    continue

                source_type, content = extracted
                if not should_keep_content(
                    content, args.min_length, args.include_slash_commands
                ):
                    continue

                cwd = obj.get("cwd", "")
                if args.cwd_pattern and args.cwd_pattern not in cwd:
                    continue

                language = args.assume_language or detect_language(content)
                if args.language and language != args.language:
                    continue

                session_id = obj.get("sessionId", path.stem)
                timestamp = obj.get("timestamp", "")

                yield MessageRecord(
                    project=project,
                    session_id=session_id,
                    timestamp=timestamp,
                    cwd=cwd,
                    source_path=str(path),
                    source_type=source_type,
                    language=language,
                    content=content.strip(),
                )


def write_jsonl(records: Iterator[MessageRecord], limit: int) -> int:
    count = 0
    for record in records:
        print(json.dumps(asdict(record), ensure_ascii=False))
        count += 1
        if count >= limit:
            break
    return count


def write_tsv(records: Iterator[MessageRecord], limit: int) -> int:
    print("project\tsession_id\ttimestamp\tlanguage\tsource_type\tcwd\tcontent")
    count = 0
    for record in records:
        safe = [
            record.project,
            record.session_id,
            record.timestamp,
            record.language,
            record.source_type,
            record.cwd.replace("\t", " ").replace("\n", " "),
            record.content.replace("\t", " ").replace("\n", " "),
        ]
        print("\t".join(safe))
        count += 1
        if count >= limit:
            break
    return count


def main() -> int:
    args = parse_args()
    if not args.root.exists():
        print(f"Root does not exist: {args.root}", file=sys.stderr)
        return 1

    writer = write_jsonl if args.format == "jsonl" else write_tsv
    count = writer(iter_records(args), args.limit)
    if count == 0:
        print("No matching records found.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
