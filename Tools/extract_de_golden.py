#!/usr/bin/env python3
"""
Extract German golden messages from cardiffnlp/tweet_sentiment_multilingual.
"""

import json
from pathlib import Path
from huggingface_hub import hf_hub_download

# Load DE dictionary expressions
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
                expressions.append(parts[0].lower())
    return expressions


de_positive = load_expressions(DICT_DIR / "de-positive.tsv")
de_frustration = load_expressions(DICT_DIR / "de-frustration.tsv")
de_profanity = load_expressions(DICT_DIR / "de-profanity.tsv")

# Remove ambiguous
AMBIGUOUS = set()
de_positive_filtered = [e for e in de_positive if e not in AMBIGUOUS]

print(f"Loaded DE expressions:")
print(f"  positive: {len(de_positive_filtered)}")
print(f"  frustration: {len(de_frustration)}")
print(f"  profanity: {len(de_profanity)}")


def find_matches(text, expressions):
    text_lower = text.lower()
    matches = []
    for expr in expressions:
        if expr in text_lower:
            matches.append(expr)
    return matches


def categorize(text):
    pos = find_matches(text, de_positive_filtered)
    fru = find_matches(text, de_frustration)
    pro = find_matches(text, de_profanity)
    return pos, fru, pro


# Download dataset
print("\nDownloading German split...")
train_path = hf_hub_download(
    repo_id="cardiffnlp/tweet_sentiment_multilingual",
    filename="data/german/train.jsonl",
    repo_type="dataset",
)

tweets = []
with open(train_path) as f:
    for line in f:
        if line.strip():
            tweets.append(json.loads(line))

print(f"Loaded {len(tweets)} German training tweets")

# Process
candidates = {"positive": [], "frustration": [], "profanity": [], "mixed": []}

for i, tweet in enumerate(tweets):
    text = tweet["text"]
    label = tweet.get("label", None)

    # Skip long tweets
    if len(text) > 200:
        continue

    pos, fru, pro = categorize(text)

    has_pos = len(pos) > 0
    has_fru = len(fru) > 0
    has_pro = len(pro) > 0

    item = {
        "idx": i,
        "text": text,
        "label": label,
        "label_name": {0: "negative", 1: "neutral", 2: "positive"}.get(label, label),
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

print(f"\nFiltered candidates (max 200 chars):")
for cat, items in candidates.items():
    print(f"  {cat}: {len(items)}")


# Print top examples
def print_examples(category, n=10):
    print(f"\n{'=' * 60}")
    print(f"=== {category.upper()} (top {n}) ===")
    print(f"{'=' * 60}")
    for item in candidates[category][:n]:
        print(f"\n[{item['idx']}] label={item['label_name']}")
        print(f"Text: {item['text']}")
        print(f"Matches: {item['expressions']}")


print_examples("positive", 10)
print_examples("frustration", 10)
print_examples("profanity", 10)
print_examples("mixed", 5)
