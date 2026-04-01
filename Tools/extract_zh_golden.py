#!/usr/bin/env python3
"""
Extract Chinese golden messages from sepidmnorozy/Chinese_sentiment.
"""

import json
import subprocess
from pathlib import Path
from huggingface_hub import hf_hub_download

DICT_DIR = Path("Sources/SentimentKit/Resources/dictionaries")


def load_expressions(filepath):
    expressions = []
    if not filepath.exists():
        return expressions
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) >= 1:
                expressions.append(parts[0])
    return expressions


def golden_suggest(lang, text):
    """Run golden-suggest tool and parse output."""
    result = subprocess.run(
        ["swift", "run", "golden-suggest", "--lang", lang, "--text", text],
        capture_output=True,
        text=True,
        cwd="/Users/fernando/code/SentimentKit",
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except:
        return None


def process_zh():
    print(f"\n{'=' * 60}")
    print(f"Processing ZH")
    print(f"{'=' * 60}")

    # Load dictionaries
    positive = load_expressions(DICT_DIR / "zh-positive.tsv")
    frustration = load_expressions(DICT_DIR / "zh-frustration.tsv")
    profanity = load_expressions(DICT_DIR / "zh-profanity.tsv")

    print(
        f"Dictionaries: {len(positive)} positive, {len(frustration)} frustration, {len(profanity)} profanity"
    )

    # Download dataset
    print(f"Downloading dataset...")
    train_path = hf_hub_download(
        repo_id="sepidmnorozy/Chinese_sentiment",
        filename="train.csv",
        repo_type="dataset",
    )

    import pandas as pd

    df = pd.read_csv(train_path)
    print(f"Loaded {len(df)} rows")

    # Find candidates
    candidates = {"positive": [], "frustration": [], "profanity": [], "mixed": []}

    for i, row in df.iterrows():
        text = str(row["text"])
        label = row.get("label", None)

        # Skip long texts
        if len(text) > 200:
            continue

        pos = []
        fru = []
        pro = []

        for expr in positive:
            if expr in text:
                pos.append(expr)
        for expr in frustration:
            if expr in text:
                fru.append(expr)
        for expr in profanity:
            if expr in text:
                pro.append(expr)

        has_pos = len(pos) > 0
        has_fru = len(fru) > 0
        has_pro = len(pro) > 0

        # Skip if no matches
        if not has_pos and not has_fru and not has_pro:
            continue

        # Skip if too many matches
        total_matches = len(pos) + len(fru) + len(pro)
        if total_matches > 3:
            continue

        item = {
            "idx": i,
            "text": text,
            "label": label,
            "expressions": {"positive": pos, "frustration": fru, "profanity": pro},
        }

        if has_pro and not has_pos and not has_fru:
            candidates["profanity"].append(item)
        elif has_pos and not has_fru and not has_pro:
            candidates["positive"].append(item)
        elif has_fru and not has_pos and not has_pro:
            candidates["frustration"].append(item)
        elif (has_pos and has_fru) or (has_pos and has_pro) or (has_fru and has_pro):
            candidates["mixed"].append(item)

    print(f"\nCandidates found:")
    for cat, items in candidates.items():
        print(f"  {cat}: {len(items)}")

    # Select best candidates for each category
    fixtures = []
    used_texts = set()
    targets = {"positive": 5, "frustration": 5, "profanity": 5}

    for category in ["positive", "frustration", "profanity"]:
        target = targets[category]
        selected = 0

        for item in candidates[category]:
            if selected >= target:
                break

            # Skip duplicates
            if item["text"] in used_texts:
                continue

            # Run golden-suggest
            fixture = golden_suggest("zh", item["text"])
            if not fixture:
                continue

            # Verify it matches the expected category
            if category == "positive" and not fixture["expected_positive"]:
                continue
            if category == "frustration" and not fixture["expected_frustration"]:
                continue
            if category == "profanity" and not fixture["expected_profanity"]:
                continue

            # Add source info
            fixture["source"] = {
                "dataset": "sepidmnorozy/Chinese_sentiment",
                "split": "train",
                "row": int(item["idx"]),
                "license": "Unknown",
            }
            fixture["note"] = (
                f"ZH {category} from sepidmnorozy/Chinese_sentiment train row {item['idx']}"
            )

            fixtures.append(fixture)
            used_texts.add(item["text"])
            selected += 1

            print(f"  [{selected}/{target}] {category}: {item['text'][:60]}...")

    return fixtures


def main():
    fixtures = process_zh()

    print(f"\n{'=' * 60}")
    print(f"TOTAL: {len(fixtures)} fixtures")
    print(f"{'=' * 60}")

    # Output as JSON
    with open("/tmp/new_zh_fixtures.json", "w") as f:
        json.dump(fixtures, f, indent=2, ensure_ascii=False)

    print(f"\nSaved to /tmp/new_zh_fixtures.json")


if __name__ == "__main__":
    main()
