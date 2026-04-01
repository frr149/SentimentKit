#!/usr/bin/env python3
"""
Search for Chinese (ZH) sentiment datasets on HuggingFace.
"""

from huggingface_hub import list_datasets
import json

print("Searching for Chinese sentiment datasets on HuggingFace...")

# Search for Chinese sentiment datasets
try:
    datasets = list_datasets(search="chinese sentiment", limit=20)
    print("\nFound datasets:")
    for i, ds in enumerate(datasets, 1):
        print(f"{i}. {ds.id}")
        if hasattr(ds, "tags") and ds.tags:
            print(f"   Tags: {', '.join(ds.tags[:5])}")
except Exception as e:
    print(f"Error searching: {e}")

# Try specific known datasets
known_datasets = [
    "lxyuan/distilbert-base-multilingual-cased-sentiments-student",
    "cardiffnlp/tweet_sentiment_multilingual",
    "rotten_tomatoes",
]

print("\n" + "=" * 60)
print("Known multilingual/multilingual sentiment datasets:")
print("=" * 60)

for ds_name in known_datasets:
    print(f"\n{ds_name}")
