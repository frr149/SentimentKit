#!/usr/bin/env python3
"""Analyze Claude local JSONL usage like a quantified-self dashboard."""

from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


TOPIC_PATTERNS = {
    "blog": r"\bblog\b|post|artículo|articulo|borrador|draft",
    "linear": r"\blinear\b|issue|backlog|ticket",
    "worktrees": r"worktree|worktrees",
    "codex": r"\bcodex\b",
    "claude": r"\bclaude\b",
    "bbedit": r"\bbbedit\b",
    "ghostty": r"ghostty|ghostti",
    "tmux": r"\btmux\b",
    "traducción": r"traduc|translate|translation",
    "review": r"review|revisa|revisar|code review",
}

URL_RE = re.compile(r"https?://[^\s)>\"]+")
WORD_RE = re.compile(r"\b[\wáéíóúñüÁÉÍÓÚÑÜ]{3,}\b", re.UNICODE)


@dataclass
class SessionStats:
    project: str
    session_id: str
    path: str
    created_at: datetime | None
    modified_at: datetime | None
    summary: str
    first_prompt: str
    message_count: int
    user_messages: int = 0
    queue_messages: int = 0
    assistant_messages: int = 0
    tool_uses: int = 0
    turn_duration_ms: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    cache_creation_tokens: int = 0
    permission_modes: Counter | None = None
    cwd_counter: Counter | None = None
    models: Counter | None = None
    topic_hits: Counter | None = None
    slash_commands: Counter | None = None
    urls: Counter | None = None

    def __post_init__(self) -> None:
        self.permission_modes = Counter()
        self.cwd_counter = Counter()
        self.models = Counter()
        self.topic_hits = Counter()
        self.slash_commands = Counter()
        self.urls = Counter()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze Claude project JSONL usage.")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.home() / ".claude" / "projects",
        help="Root folder containing Claude project JSONL logs.",
    )
    parser.add_argument(
        "--project-pattern",
        default=None,
        help="Only include projects whose path contains this substring.",
    )
    parser.add_argument(
        "--cwd-pattern",
        default=None,
        help="Only include sessions whose working directory contains this substring.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=10,
        help="How many top items to show in ranked sections.",
    )
    return parser.parse_args()


def parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def iter_session_indexes(root: Path, project_pattern: str | None):
    for path in sorted(root.glob("*/sessions-index.json")):
        if project_pattern and project_pattern not in path.as_posix():
            continue
        yield path


def session_stats_from_index_entry(project: str, entry: dict) -> SessionStats:
    return SessionStats(
        project=project,
        session_id=entry["sessionId"],
        path=entry["fullPath"],
        created_at=parse_ts(entry.get("created")),
        modified_at=parse_ts(entry.get("modified")),
        summary=entry.get("summary", ""),
        first_prompt=entry.get("firstPrompt", ""),
        message_count=entry.get("messageCount", 0),
    )


def resolve_session_path(project_dir: Path, entry: dict) -> Path:
    indexed = Path(entry["fullPath"])
    if indexed.exists():
        return indexed
    fallback = project_dir / f"{entry['sessionId']}.jsonl"
    return fallback


def infer_stats_from_jsonl_path(path: Path) -> SessionStats:
    session_id = path.stem
    return SessionStats(
        project=path.parent.name,
        session_id=session_id,
        path=str(path),
        created_at=None,
        modified_at=None,
        summary="",
        first_prompt="",
        message_count=0,
    )


def update_topic_hits(counter: Counter, text: str) -> None:
    lowered = text.lower()
    for topic, pattern in TOPIC_PATTERNS.items():
        if re.search(pattern, lowered):
            counter[topic] += 1


def update_slash_commands(counter: Counter, text: str) -> None:
    stripped = text.strip()
    if stripped.startswith("/"):
        command = stripped.split()[0]
        counter[command] += 1


def update_urls(counter: Counter, text: str) -> None:
    for url in URL_RE.findall(text):
        host = re.sub(r"^https?://", "", url).split("/", 1)[0].lower()
        counter[host] += 1


def analyze_session(path: Path, stats: SessionStats) -> SessionStats:
    first_ts = None
    last_ts = None
    for line in path.open():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        record_type = obj.get("type")
        timestamp = parse_ts(obj.get("timestamp"))
        if timestamp is not None:
            if first_ts is None or timestamp < first_ts:
                first_ts = timestamp
            if last_ts is None or timestamp > last_ts:
                last_ts = timestamp
        cwd = obj.get("cwd")
        if cwd:
            stats.cwd_counter[cwd] += 1

        permission_mode = obj.get("permissionMode")
        if permission_mode:
            stats.permission_modes[permission_mode] += 1

        if record_type == "user":
            message = obj.get("message") or {}
            content = message.get("content")
            if isinstance(content, str) and not obj.get("isMeta"):
                stats.user_messages += 1
                if not stats.first_prompt:
                    stats.first_prompt = content
                update_topic_hits(stats.topic_hits, content)
                update_slash_commands(stats.slash_commands, content)
                update_urls(stats.urls, content)

        elif record_type == "queue-operation" and obj.get("operation") == "enqueue":
            content = obj.get("content")
            if isinstance(content, str):
                stats.queue_messages += 1
                update_topic_hits(stats.topic_hits, content)
                update_slash_commands(stats.slash_commands, content)
                update_urls(stats.urls, content)

        elif record_type == "assistant":
            stats.assistant_messages += 1
            message = obj.get("message") or {}
            model = message.get("model")
            if model:
                stats.models[model] += 1
            usage = message.get("usage") or {}
            stats.input_tokens += int(usage.get("input_tokens", 0) or 0)
            stats.output_tokens += int(usage.get("output_tokens", 0) or 0)
            stats.cache_read_tokens += int(usage.get("cache_read_input_tokens", 0) or 0)
            stats.cache_creation_tokens += int(
                usage.get("cache_creation_input_tokens", 0) or 0
            )
            for item in message.get("content") or []:
                if isinstance(item, dict) and item.get("type") == "tool_use":
                    stats.tool_uses += 1

        elif record_type == "system" and obj.get("subtype") == "turn_duration":
            stats.turn_duration_ms += int(obj.get("durationMs", 0) or 0)

    stats.message_count = stats.user_messages + stats.assistant_messages + stats.queue_messages
    if stats.created_at is None:
        stats.created_at = first_ts
    if stats.modified_at is None:
        stats.modified_at = last_ts
    if not stats.summary and stats.first_prompt:
        stats.summary = stats.first_prompt[:120]
    return stats


def top_words(sessions: list[SessionStats], limit: int) -> list[tuple[str, int]]:
    counts: Counter[str] = Counter()
    stop = {
        "para",
        "esto",
        "esta",
        "está",
        "como",
        "quiero",
        "hacer",
        "puede",
        "puedo",
        "sobre",
        "tiene",
        "tengo",
        "porque",
        "donde",
        "ahora",
        "luego",
        "todo",
        "solo",
        "nada",
        "más",
        "mas",
        "muy",
        "con",
        "sin",
        "del",
        "los",
        "las",
        "una",
        "uno",
        "unos",
        "unas",
        "que",
        "por",
        "pero",
        "me",
        "mi",
        "tu",
        "lo",
        "el",
        "la",
        "de",
        "en",
        "un",
        "y",
    }
    for session in sessions:
        for text in (session.first_prompt,):
            for word in WORD_RE.findall(text.lower()):
                if word not in stop:
                    counts[word] += 1
    return counts.most_common(limit)


def fmt_duration(seconds: float) -> str:
    minutes = int(seconds // 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def main() -> int:
    args = parse_args()
    sessions: list[SessionStats] = []

    for index_path in iter_session_indexes(args.root, args.project_pattern):
        project = index_path.parent.name
        payload = json.loads(index_path.read_text())
        seen_paths: set[Path] = set()
        for entry in payload.get("entries", []):
            stats = session_stats_from_index_entry(project, entry)
            session_path = resolve_session_path(index_path.parent, entry)
            stats.path = str(session_path)
            if session_path.exists():
                seen_paths.add(session_path.resolve())
                analyzed = analyze_session(session_path, stats)
                if args.cwd_pattern and not any(args.cwd_pattern in cwd for cwd in analyzed.cwd_counter):
                    continue
                sessions.append(analyzed)

        for session_path in sorted(index_path.parent.glob("*.jsonl")):
            if session_path.name == "sessions-index.json":
                continue
            resolved = session_path.resolve()
            if resolved in seen_paths:
                continue
            analyzed = analyze_session(session_path, infer_stats_from_jsonl_path(session_path))
            if args.cwd_pattern and not any(args.cwd_pattern in cwd for cwd in analyzed.cwd_counter):
                continue
            sessions.append(analyzed)

    if not sessions:
        print("No sessions found.")
        return 1

    sessions.sort(key=lambda s: s.created_at or datetime.min.replace(tzinfo=timezone.utc))

    project_counts = Counter(s.project for s in sessions)
    session_days = Counter((s.created_at.date().isoformat() if s.created_at else "unknown") for s in sessions)
    weekday_counts = Counter((s.created_at.strftime("%A") if s.created_at else "unknown") for s in sessions)
    hour_counts = Counter((s.created_at.strftime("%H") if s.created_at else "unknown") for s in sessions)
    all_models = Counter()
    all_topics = Counter()
    all_slash = Counter()
    all_urls = Counter()
    all_cwds = Counter()
    permission_modes = Counter()

    for session in sessions:
        all_models.update(session.models)
        all_topics.update(session.topic_hits)
        all_slash.update(session.slash_commands)
        all_urls.update(session.urls)
        all_cwds.update(session.cwd_counter)
        permission_modes.update(session.permission_modes)

    user_messages = sum(s.user_messages for s in sessions)
    queue_messages = sum(s.queue_messages for s in sessions)
    assistant_messages = sum(s.assistant_messages for s in sessions)
    tool_uses = sum(s.tool_uses for s in sessions)
    turn_duration_ms = sum(s.turn_duration_ms for s in sessions)
    input_tokens = sum(s.input_tokens for s in sessions)
    output_tokens = sum(s.output_tokens for s in sessions)
    cache_read_tokens = sum(s.cache_read_tokens for s in sessions)
    cache_creation_tokens = sum(s.cache_creation_tokens for s in sessions)
    created_times = [s.created_at for s in sessions if s.created_at]
    modified_times = [s.modified_at for s in sessions if s.modified_at]
    message_counts = [s.message_count for s in sessions]
    user_counts = [s.user_messages for s in sessions]

    print("# Claude Usage Report")
    print()
    print(f"- Sessions: {len(sessions)}")
    print(f"- Projects: {len(project_counts)}")
    if created_times and modified_times:
        print(f"- Date range: {min(created_times).date()} -> {max(modified_times).date()}")
    print(f"- User messages: {user_messages}")
    print(f"- Queued user messages: {queue_messages}")
    print(f"- Assistant messages: {assistant_messages}")
    print(f"- Tool uses: {tool_uses}")
    print(f"- Total turn duration: {fmt_duration(turn_duration_ms / 1000)}")
    print(f"- Input tokens: {input_tokens:,}")
    print(f"- Output tokens: {output_tokens:,}")
    print(f"- Cache read tokens: {cache_read_tokens:,}")
    print(f"- Cache creation tokens: {cache_creation_tokens:,}")
    print()

    print("## Session Shape")
    print(f"- Median indexed messages per session: {statistics.median(message_counts):.1f}")
    print(f"- Median user messages per session: {statistics.median(user_counts):.1f}")
    print(f"- Avg user messages per session: {statistics.mean(user_counts):.1f}")
    print()

    print("## Top Projects")
    for project, count in project_counts.most_common(args.top):
        print(f"- {project}: {count} sessions")
    print()

    print("## Most Active Days")
    for day, count in session_days.most_common(args.top):
        print(f"- {day}: {count} sessions")
    print()

    print("## Preferred Weekdays")
    for day, count in weekday_counts.most_common():
        print(f"- {day}: {count} sessions")
    print()

    print("## Preferred Start Hours (UTC)")
    for hour, count in hour_counts.most_common(args.top):
        print(f"- {hour}:00 -> {count} sessions")
    print()

    print("## Top Models")
    for model, count in all_models.most_common(args.top):
        print(f"- {model}: {count} assistant messages")
    print()

    print("## Permission Modes")
    for mode, count in permission_modes.most_common():
        print(f"- {mode}: {count}")
    print()

    print("## Slash Commands")
    for command, count in all_slash.most_common(args.top):
        print(f"- {command}: {count}")
    print()

    print("## Recurrent Topics")
    for topic, count in all_topics.most_common():
        print(f"- {topic}: {count}")
    print()

    print("## Frequent URL Hosts")
    for host, count in all_urls.most_common(args.top):
        print(f"- {host}: {count}")
    print()

    print("## Frequent Working Directories")
    for cwd, count in all_cwds.most_common(args.top):
        print(f"- {cwd}: {count} events")
    print()

    print("## Biggest Sessions by User Messages")
    biggest = sorted(sessions, key=lambda s: (s.user_messages, s.message_count), reverse=True)[: args.top]
    for session in biggest:
        prompt = session.first_prompt.replace("\n", " ")[:110]
        print(f"- {session.session_id}: {session.user_messages} user msgs, {session.project}, `{prompt}`")
    print()

    print("## Most Tool-Heavy Sessions")
    tool_heavy = sorted(sessions, key=lambda s: s.tool_uses, reverse=True)[: args.top]
    for session in tool_heavy:
        prompt = session.first_prompt.replace("\n", " ")[:110]
        print(f"- {session.session_id}: {session.tool_uses} tool uses, {session.project}, `{prompt}`")
    print()

    print("## Common First-Prompt Words")
    for word, count in top_words(sessions, args.top):
        print(f"- {word}: {count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
