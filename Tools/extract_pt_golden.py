#!/usr/bin/env python3
"""
Extract Portuguese golden messages from cardiffnlp/tweet_sentiment_multilingual.
Filter for high-quality candidates and output golden fixture JSON.
"""

import json
from pathlib import Path
from huggingface_hub import hf_hub_download

# Load PT dictionary expressions
DICT_DIR = Path("Sources/SentimentKit/Resources/dictionaries")


def load_expressions(filepath):
    """Load expressions from a TSV dictionary file."""
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


pt_positive = load_expressions(DICT_DIR / "pt-positive.tsv")
pt_frustration = load_expressions(DICT_DIR / "pt-frustration.tsv")
pt_profanity = load_expressions(DICT_DIR / "pt-profanity.tsv")

# Remove ambiguous expressions from positive
AMBIGUOUS_POSITIVE = {"show"}  # "show" is too ambiguous in PT
pt_positive_filtered = [e for e in pt_positive if e not in AMBIGUOUS_POSITIVE]

print(f"Loaded PT expressions (filtered):")
print(
    f"  positive: {len(pt_positive_filtered)} (removed ambiguous: {AMBIGUOUS_POSITIVE})"
)
print(f"  frustration: {len(pt_frustration)}")
print(f"  profanity: {len(pt_profanity)}")


def normalize(text):
    """Normalize text for matching."""
    return text.lower()


def find_matches(text, expressions):
    """Find which expressions match in text."""
    text_lower = normalize(text)
    matches = []
    for expr in expressions:
        if expr in text_lower:
            matches.append(expr)
    return matches


def categorize(text):
    """Categorize text by sentiment expressions found."""
    pos = find_matches(text, pt_positive_filtered)
    fru = find_matches(text, pt_frustration)
    pro = find_matches(text, pt_profanity)
    return pos, fru, pro


# Download JSONL files directly
print("\nDownloading JSONL files from HuggingFace...")

train_path = hf_hub_download(
    repo_id="cardiffnlp/tweet_sentiment_multilingual",
    filename="data/portuguese/train.jsonl",
    repo_type="dataset",
)

# Read JSONL
tweets = []
with open(train_path) as f:
    for line in f:
        if line.strip():
            tweets.append(json.loads(line))

print(f"Loaded {len(tweets)} Portuguese training tweets")

# Process tweets and collect high-quality candidates
# Prioritize shorter, clearer messages
candidates_by_type = {"positive": [], "frustration": [], "profanity": [], "mixed": []}

for i, tweet in enumerate(tweets):
    text = tweet["text"]
    label = tweet.get("label", None)  # 0=negative, 1=neutral, 2=positive

    # Skip very long tweets (>200 chars)
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
        candidates_by_type["profanity"].append(item)
    elif has_pos and not has_fru and not has_pro:
        candidates_by_type["positive"].append(item)
    elif has_fru and not has_pos and not has_pro:
        candidates_by_type["frustration"].append(item)
    elif (has_pos and has_fru) or (has_pos and has_pro) or (has_fru and has_pro):
        candidates_by_type["mixed"].append(item)

# Print summary
print(f"\nFiltered candidates (max 200 chars):")
for cat, items in candidates_by_type.items():
    print(f"  {cat}: {len(items)}")


# Print top examples per category with better formatting
def print_examples(category, n=5):
    print(f"\n{'=' * 60}")
    print(f"=== {category.upper()} (top {n}) ===")
    print(f"{'=' * 60}")
    for item in candidates_by_type[category][:n]:
        print(f"\n[{item['idx']}] label={item['label_name']}")
        print(f"Text: {item['text']}")
        print(f"Matches: {item['expressions']}")


print_examples("positive", 5)
print_examples("frustration", 5)
print_examples("profanity", 5)
print_examples("mixed", 3)

# Output selected candidates for manual review
print(f"\n{'=' * 60}")
print("=== SELECTED GOLDEN CANDIDATES (for manual review) ===")
print(f"{'=' * 60}\n")

# Select best candidates for golden fixtures
# We want: 3 positive, 3 frustration, 2 profanity, 2 neutral if possible

output = {
    "positive": [],
    "frustration": [],
    "profanity": [],
    "mixed": [],
    "source": {
        "dataset": "cardiffnlp/tweet_sentiment_multilingual",
        "split": "train",
        "language": "portuguese",
        "license": "CC BY-SA 3.0",
    },
}

# Take top candidates
for cat in ["positive", "frustration", "profanity", "mixed"]:
    output[cat] = candidates_by_type[cat][:10]

print(json.dumps(output, indent=2, ensure_ascii=False))
