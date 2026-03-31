#!/usr/bin/env python3
"""Analyze Codex usage logs for quantified-self style reporting."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


WORD_RE = re.compile(r"\b[\wáéíóúñüÁÉÍÓÚÑÜ]{3,}\b", re.UNICODE)
URL_RE = re.compile(r"https?://[^\s)>\"]+")

TOPIC_PATTERNS = {
    "review": r"review|revisa|revisar",
    "tests": r"\btest\b|tests|testing|pbt",
    "blog": r"\bblog\b|post|artículo|articulo|draft",
    "linear": r"\blinear\b|issue|ticket|backlog",
    "sentiment": r"sentiment|nlp|lexicon|dictionary",
    "swift": r"\bswift\b|xcode|swiftpm",
    "python": r"\bpython\b",
    "worktrees": r"worktree|worktrees",
    "claude": r"\bclaude\b",
    "codex": r"\bcodex\b",
}


@dataclass
class CodexSessionStats:
    session_id: str
    thread_name: str = ""
    updated_at: datetime | None = None
    started_at: datetime | None = None
    cwd: str = ""
    prompt_count: int = 0
    user_message_count: int = 0
    assistant_message_count: int = 0
    commentary_count: int = 0
    final_count: int = 0
    tool_calls: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    cached_input_tokens: int = 0
    reasoning_output_tokens: int = 0
    models: Counter = field(default_factory=Counter)
    topics: Counter = field(default_factory=Counter)
    urls: Counter = field(default_factory=Counter)
    cwd_counter: Counter = field(default_factory=Counter)
    tools: Counter = field(default_factory=Counter)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze Codex local usage logs.")
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
        "--top",
        type=int,
        default=10,
        help="How many top items to show per section.",
    )
    return parser.parse_args()


def parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    if value.endswith("Z"):
        value = value.replace("Z", "+00:00")
    return datetime.fromisoformat(value).astimezone(timezone.utc)


def load_thread_index(root: Path) -> dict[str, CodexSessionStats]:
    stats: dict[str, CodexSessionStats] = {}
    index = root / "session_index.jsonl"
    if not index.exists():
        return stats
    with index.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            stats[obj["id"]] = CodexSessionStats(
                session_id=obj["id"],
                thread_name=obj.get("thread_name", ""),
                updated_at=parse_ts(obj.get("updated_at")),
            )
    return stats


def update_topics(counter: Counter, text: str) -> None:
    lowered = text.lower()
    for topic, pattern in TOPIC_PATTERNS.items():
        if re.search(pattern, lowered):
            counter[topic] += 1


def update_urls(counter: Counter, text: str) -> None:
    for url in URL_RE.findall(text):
        host = re.sub(r"^https?://", "", url).split("/", 1)[0].lower()
        counter[host] += 1


def load_history(root: Path, sessions: dict[str, CodexSessionStats]) -> None:
    history = root / "history.jsonl"
    if not history.exists():
        return
    with history.open() as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            session_id = obj.get("session_id")
            if not session_id:
                continue
            session = sessions.setdefault(session_id, CodexSessionStats(session_id=session_id))
            session.prompt_count += 1
            text = obj.get("text", "")
            if not session.thread_name:
                session.thread_name = text.splitlines()[0][:120]
            update_topics(session.topics, text)
            update_urls(session.urls, text)


def analyze_sessions(root: Path, sessions: dict[str, CodexSessionStats], cwd_pattern: str | None) -> list[CodexSessionStats]:
    for path in sorted((root / "sessions").rglob("*.jsonl")):
        with path.open() as handle:
            session: CodexSessionStats | None = None
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                record_type = obj.get("type")
                payload = obj.get("payload") or {}

                if record_type == "session_meta":
                    session_id = payload.get("id")
                    if not session_id:
                        continue
                    session = sessions.setdefault(session_id, CodexSessionStats(session_id=session_id))
                    session.started_at = parse_ts(payload.get("timestamp"))
                    session.cwd = payload.get("cwd", session.cwd)
                    if session.cwd:
                        session.cwd_counter[session.cwd] += 1
                    continue

                if session is None:
                    continue

                if cwd_pattern and cwd_pattern not in session.cwd:
                    continue

                if record_type == "event_msg":
                    event_type = payload.get("type")
                    if event_type == "user_message":
                        text = str(payload.get("message", ""))
                        session.user_message_count += 1
                        update_topics(session.topics, text)
                        update_urls(session.urls, text)
                    elif event_type == "agent_message":
                        phase = payload.get("phase")
                        if phase == "commentary":
                            session.commentary_count += 1
                        elif phase == "final_answer":
                            session.final_count += 1
                    elif event_type == "token_count":
                        info = payload.get("info") or {}
                        total = info.get("total_token_usage") or {}
                        session.input_tokens = max(session.input_tokens, int(total.get("input_tokens", 0) or 0))
                        session.output_tokens = max(session.output_tokens, int(total.get("output_tokens", 0) or 0))
                        session.cached_input_tokens = max(session.cached_input_tokens, int(total.get("cached_input_tokens", 0) or 0))
                        session.reasoning_output_tokens = max(session.reasoning_output_tokens, int(total.get("reasoning_output_tokens", 0) or 0))

                elif record_type == "response_item":
                    payload_type = payload.get("type")
                    if payload_type == "message":
                        role = payload.get("role")
                        if role == "assistant":
                            session.assistant_message_count += 1
                    elif payload_type == "function_call":
                        session.tool_calls += 1
                        name = payload.get("name")
                        if name:
                            session.tools[name] += 1

                elif record_type == "turn_context":
                    model = payload.get("model")
                    if model:
                        session.models[model] += 1

    filtered = [s for s in sessions.values() if not cwd_pattern or cwd_pattern in s.cwd]
    filtered.sort(key=lambda s: s.started_at or s.updated_at or datetime.min.replace(tzinfo=timezone.utc))
    return filtered


def top_words(sessions: list[CodexSessionStats], limit: int) -> list[tuple[str, int]]:
    stop = {
        "para","esto","esta","está","como","quiero","hacer","puede","puedo","sobre","ahora","todo","solo","más","mas",
        "con","sin","del","los","las","una","uno","unos","unas","que","por","pero","me","mi","tu","lo","el","la","de","en","un","y"
    }
    counts: Counter[str] = Counter()
    for session in sessions:
        for word in WORD_RE.findall(session.thread_name.lower()):
            if word not in stop:
                counts[word] += 1
    return counts.most_common(limit)


def main() -> int:
    args = parse_args()
    sessions = load_thread_index(args.root)
    load_history(args.root, sessions)
    sessions_list = analyze_sessions(args.root, sessions, args.cwd_pattern)
    if not sessions_list:
        print("No sessions found.")
        return 1

    project_cwds = Counter(s.cwd for s in sessions_list if s.cwd)
    daily = Counter((s.started_at.date().isoformat() if s.started_at else "unknown") for s in sessions_list)
    weekdays = Counter((s.started_at.strftime("%A") if s.started_at else "unknown") for s in sessions_list)
    hours = Counter((s.started_at.strftime("%H") if s.started_at else "unknown") for s in sessions_list)
    models = Counter()
    topics = Counter()
    urls = Counter()
    tools = Counter()
    prompt_counts = [s.prompt_count for s in sessions_list]
    user_counts = [s.user_message_count for s in sessions_list]
    assistant_counts = [s.assistant_message_count for s in sessions_list]

    for session in sessions_list:
        models.update(session.models)
        topics.update(session.topics)
        urls.update(session.urls)
        tools.update(session.tools)

    print("# Codex Usage Report")
    print()
    print(f"- Sessions: {len(sessions_list)}")
    print(f"- Prompt count (`history.jsonl`): {sum(s.prompt_count for s in sessions_list)}")
    print(f"- User messages (`sessions/*.jsonl`): {sum(s.user_message_count for s in sessions_list)}")
    print(f"- Assistant messages: {sum(s.assistant_message_count for s in sessions_list)}")
    print(f"- Commentary messages: {sum(s.commentary_count for s in sessions_list)}")
    print(f"- Final answers: {sum(s.final_count for s in sessions_list)}")
    print(f"- Tool calls: {sum(s.tool_calls for s in sessions_list)}")
    print(f"- Input tokens: {sum(s.input_tokens for s in sessions_list):,}")
    print(f"- Output tokens: {sum(s.output_tokens for s in sessions_list):,}")
    print(f"- Cached input tokens: {sum(s.cached_input_tokens for s in sessions_list):,}")
    print(f"- Reasoning output tokens: {sum(s.reasoning_output_tokens for s in sessions_list):,}")
    print()

    print("## Session Shape")
    print(f"- Median prompts per session: {statistics.median(prompt_counts):.1f}")
    print(f"- Median user messages per session: {statistics.median(user_counts):.1f}")
    print(f"- Median assistant messages per session: {statistics.median(assistant_counts):.1f}")
    print()

    print("## Working Directories")
    for cwd, count in project_cwds.most_common(args.top):
        print(f"- {cwd}: {count} sessions")
    print()

    print("## Most Active Days")
    for day, count in daily.most_common(args.top):
        print(f"- {day}: {count} sessions")
    print()

    print("## Preferred Weekdays")
    for day, count in weekdays.most_common():
        print(f"- {day}: {count} sessions")
    print()

    print("## Preferred Start Hours (UTC)")
    for hour, count in hours.most_common(args.top):
        print(f"- {hour}:00 -> {count} sessions")
    print()

    print("## Models")
    for model, count in models.most_common(args.top):
        print(f"- {model}: {count} sessions/turn contexts")
    print()

    print("## Recurrent Topics")
    for topic, count in topics.most_common():
        print(f"- {topic}: {count}")
    print()

    print("## Frequent URL Hosts")
    for host, count in urls.most_common(args.top):
        print(f"- {host}: {count}")
    print()

    print("## Most Used Tools")
    for tool, count in tools.most_common(args.top):
        print(f"- {tool}: {count}")
    print()

    print("## Biggest Sessions by Prompt Count")
    for session in sorted(sessions_list, key=lambda s: s.prompt_count, reverse=True)[: args.top]:
        print(f"- {session.session_id}: {session.prompt_count} prompts, `{session.thread_name}`")
    print()

    print("## Common Thread Words")
    for word, count in top_words(sessions_list, args.top):
        print(f"- {word}: {count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
