#!/usr/bin/env python3
"""Extract real user prompts from Codex local logs."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterator


@dataclass
class CodexMessageRecord:
    session_id: str
    thread_name: str
    timestamp: str
    source: str
    cwd: str
    content: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract user prompts from Codex logs.")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.home() / ".codex",
        help="Codex state root.",
    )
    parser.add_argument(
        "--cwd-pattern",
        default=None,
        help="Only include sessions whose cwd contains this substring.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=200,
        help="Maximum number of output records.",
    )
    parser.add_argument(
        "--format",
        choices=("jsonl", "tsv"),
        default="jsonl",
        help="Output format.",
    )
    return parser.parse_args()


def load_thread_names(root: Path) -> dict[str, str]:
    index = root / "session_index.jsonl"
    mapping: dict[str, str] = {}
    if not index.exists():
        return mapping
    with index.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            mapping[obj["id"]] = obj.get("thread_name", "")
    return mapping


def iter_history(root: Path, thread_names: dict[str, str]) -> Iterator[CodexMessageRecord]:
    history = root / "history.jsonl"
    if not history.exists():
        return
    with history.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            session_id = obj.get("session_id", "")
            yield CodexMessageRecord(
                session_id=session_id,
                thread_name=thread_names.get(session_id, ""),
                timestamp=str(obj.get("ts", "")),
                source="history",
                cwd="",
                content=obj.get("text", "").strip(),
            )


def iter_sessions(root: Path, thread_names: dict[str, str]) -> Iterator[CodexMessageRecord]:
    sessions_root = root / "sessions"
    if not sessions_root.exists():
        return
    for path in sorted(sessions_root.rglob("*.jsonl")):
        cwd = ""
        session_id = ""
        with path.open() as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                record_type = obj.get("type")
                payload = obj.get("payload") or {}
                if record_type == "session_meta":
                    session_id = payload.get("id", session_id)
                    cwd = payload.get("cwd", cwd)
                elif record_type == "event_msg" and payload.get("type") == "user_message":
                    yield CodexMessageRecord(
                        session_id=session_id,
                        thread_name=thread_names.get(session_id, ""),
                        timestamp=obj.get("timestamp", ""),
                        source="session_event",
                        cwd=cwd,
                        content=str(payload.get("message", "")).strip(),
                    )


def keep(record: CodexMessageRecord, cwd_pattern: str | None) -> bool:
    if not record.content:
        return False
    if cwd_pattern and cwd_pattern not in record.cwd:
        return False
    return True


def write_jsonl(records: Iterator[CodexMessageRecord], limit: int) -> int:
    count = 0
    for record in records:
        print(json.dumps(asdict(record), ensure_ascii=False))
        count += 1
        if count >= limit:
            break
    return count


def write_tsv(records: Iterator[CodexMessageRecord], limit: int) -> int:
    print("session_id\tthread_name\ttimestamp\tsource\tcwd\tcontent")
    count = 0
    for record in records:
        safe = [
            record.session_id,
            record.thread_name.replace("\t", " ").replace("\n", " "),
            record.timestamp,
            record.source,
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
    thread_names = load_thread_names(args.root)
    records = (
        record
        for source in (iter_history(args.root, thread_names), iter_sessions(args.root, thread_names))
        for record in source
        if keep(record, args.cwd_pattern)
    )
    writer = write_jsonl if args.format == "jsonl" else write_tsv
    count = writer(records, args.limit)
    if count == 0:
        print("No matching records found.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
