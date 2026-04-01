#!/usr/bin/env python3
"""
Analyze PHANTOM expressions - expressions in dictionaries but not in golden messages.
Outputs report grouped by language and type.
"""

import json
from pathlib import Path

FIXTURES_DIR = Path("Fixtures/golden")
DICT_DIR = Path("Sources/SentimentKit/Resources/dictionaries")


def load_dict_expressions(lang, type_):
    """Load expressions from dictionary TSV."""
    filepath = DICT_DIR / f"{lang}-{type_}.tsv"
    expressions = set()
    if not filepath.exists():
        return expressions
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) >= 1:
                expressions.add(parts[0].lower())
    return expressions


def load_golden_expressions(lang, type_):
    """Load expressions referenced in golden messages for a language/type."""
    with open(FIXTURES_DIR / "messages.json") as f:
        messages = json.load(f)

    expressions = set()
    type_key_map = {
        "positive": "expected_positive",
        "frustration": "expected_frustration",
        "profanity": "expected_profanity",
    }

    for msg in messages:
        if msg["language"] != lang:
            continue
        for expr in msg.get(type_key_map[type_], []):
            expressions.add(expr.lower())

    return expressions


# Languages to analyze
LANGUAGES = ["es", "en", "pt", "de", "fr", "zh", "ja", "ko"]
TYPES = ["positive", "frustration", "profanity"]

print("=" * 70)
print("PHANTOM EXPRESSION ANALYSIS")
print("=" * 70)
print()

total_dict = 0
total_golden = 0
total_phantom = 0

for lang in LANGUAGES:
    lang_total_dict = 0
    lang_total_golden = 0
    lang_phantom = []

    for type_ in TYPES:
        dict_exprs = load_dict_expressions(lang, type_)
        golden_exprs = load_golden_expressions(lang, type_)
        phantom = dict_exprs - golden_exprs

        lang_total_dict += len(dict_exprs)
        lang_total_golden += len(golden_exprs)
        lang_phantom.extend([(type_, e) for e in sorted(phantom)])

    total_dict += lang_total_dict
    total_golden += lang_total_golden
    total_phantom += len(lang_phantom)

    print(
        f"{lang.upper()}: {lang_total_dict} dict, {lang_total_golden} in golden, {len(lang_phantom)} PHANTOM"
    )

    # Show first 5 PHANTOM per type
    if lang_phantom:
        for type_ in TYPES:
            type_phantom = [e for t, e in lang_phantom if t == type_]
            if type_phantom:
                examples = type_phantom[:3]
                suffix = (
                    f"... (+{len(type_phantom) - 3} more)"
                    if len(type_phantom) > 3
                    else ""
                )
                print(f"  {type_}: {', '.join(examples)}{suffix}")

print()
print("=" * 70)
print(f"TOTAL: {total_dict} dict, {total_golden} in golden, {total_phantom} PHANTOM")
print(f"Coverage: {total_golden / total_dict * 100:.1f}%")
print("=" * 70)
