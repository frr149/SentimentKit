#!/usr/bin/env python3
"""
Extract ES and EN golden messages from cardiffnlp/tweet_sentiment_multilingual.
"""

import json
import subprocess
from pathlib import Path
from huggingface_hub import hf_hub_download

# Languages to process
LANGUAGES = {
    "es": {"file": "spanish", "positive": 10, "frustration": 10, "profanity": 10},
    "en": {"file": "english", "positive": 10, "frustration": 10, "profanity": 10},
}

DICT_DIR = Path("Sources/SentimentKit/Resources/dictionaries")


def load_expressions(lang_code, type_):
    filepath = DICT_DIR / f"{lang_code}-{type_}.tsv"
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
                expressions.append(parts[0].lower())
    return expressions


def find_matches(text, expressions):
    text_lower = text.lower()
    matches = []
    for expr in expressions:
        if expr in text_lower:
            matches.append(expr)
    return matches


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


def process_language(lang_code, info):
    lang_file = info["file"]
    targets = {
        "positive": info["positive"],
        "frustration": info["frustration"],
        "profanity": info["profanity"],
    }

    print(f"\n{'=' * 60}")
    print(f"Processing {lang_code.upper()}")
    print(f"{'=' * 60}")

    # Load dictionaries
    positive = load_expressions(lang_code, "positive")
    frustration = load_expressions(lang_code, "frustration")
    profanity = load_expressions(lang_code, "profanity")

    print(
        f"Dictionaries: {len(positive)} positive, {len(frustration)} frustration, {len(profanity)} profanity"
    )

    # Download dataset
    print(f"Downloading dataset...")
    train_path = hf_hub_download(
        repo_id="cardiffnlp/tweet_sentiment_multilingual",
        filename=f"data/{lang_file}/train.jsonl",
        repo_type="dataset",
    )

    tweets = []
    with open(train_path) as f:
        for line in f:
            if line.strip():
                tweets.append(json.loads(line))

    print(f"Loaded {len(tweets)} tweets")

    # Find candidates
    candidates = {"positive": [], "frustration": [], "profanity": [], "mixed": []}

    for i, tweet in enumerate(tweets):
        text = tweet["text"]
        label = tweet.get("label", None)

        # Skip long tweets
        if len(text) > 200:
            continue

        pos = find_matches(text, positive)
        fru = find_matches(text, frustration)
        pro = find_matches(text, profanity)

        has_pos = len(pos) > 0
        has_fru = len(fru) > 0
        has_pro = len(pro) > 0

        if not has_pos and not has_fru and not has_pro:
            continue

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

    # Select best candidates
    fixtures = []
    used_texts = set()

    # Load existing texts
    with open("Fixtures/golden/messages.json") as f:
        existing = json.load(f)
    existing_texts = {m["text"] for m in existing if m["language"] == lang_code}

    for category in ["positive", "frustration", "profanity"]:
        target = targets[category]
        selected = 0

        for item in candidates[category]:
            if selected >= target:
                break

            if item["text"] in used_texts or item["text"] in existing_texts:
                continue

            fixture = golden_suggest(lang_code, item["text"])
            if not fixture:
                continue

            if category == "positive" and not fixture["expected_positive"]:
                continue
            if category == "frustration" and not fixture["expected_frustration"]:
                continue
            if category == "profanity" and not fixture["expected_profanity"]:
                continue

            fixture["source"] = {
                "dataset": "cardiffnlp/tweet_sentiment_multilingual",
                "split": "train",
                "row": item["idx"],
                "license": "CC BY-SA 3.0",
            }
            fixture["note"] = (
                f"{lang_code.upper()} {category} from cardiffnlp/tweet_sentiment_multilingual train row {item['idx']}"
            )

            fixtures.append(fixture)
            used_texts.add(item["text"])
            selected += 1

            print(f"  [{selected}/{target}] {category}: {item['text'][:60]}...")

    return fixtures


def main():
    all_fixtures = []

    for lang_code, info in LANGUAGES.items():
        fixtures = process_language(lang_code, info)
        all_fixtures.extend(fixtures)
        print(f"\n  Total for {lang_code.upper()}: {len(fixtures)} fixtures")

    print(f"\n{'=' * 60}")
    print(f"TOTAL: {len(all_fixtures)} fixtures")
    print(f"{'=' * 60}")

    with open("/tmp/new_es_en_fixtures.json", "w") as f:
        json.dump(all_fixtures, f, indent=2, ensure_ascii=False)

    print(f"\nSaved to /tmp/new_es_en_fixtures.json")


if __name__ == "__main__":
    main()
