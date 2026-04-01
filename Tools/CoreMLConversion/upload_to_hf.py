#!/usr/bin/env python3
"""Upload CoreML model artifacts to HuggingFace.

This script packages the quantized CoreML model and tokenizer into a single
tarball, calculates the SHA256 checksum, uploads to HuggingFace, and saves
the checksum locally.

Usage:
    HF_TOKEN=$(op read "op://FRR DEV/HuggingFace/token") uv run python upload_to_hf.py

Requirements:
    - HF_TOKEN environment variable with write access to the target repo
    - Converted model artifacts present in artifacts/
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path


HF_REPO_ID = "frr149/SentimentKit"
ARTIFACTS_DIR = Path(__file__).resolve().parent / "artifacts"
MODEL_PACKAGE = ARTIFACTS_DIR / "SentimentKitSentiment.mlpackage"
TOKENIZER_DIR = ARTIFACTS_DIR / "SentimentKitSentiment.tokenizer"
TARBALL_NAME = "sentimentkit-sentiment-coreml.tar.gz"
TARBALL_PATH = ARTIFACTS_DIR / TARBALL_NAME
CHECKSUM_FILE = ARTIFACTS_DIR / "checksum.sha256"


def calculate_sha256(filepath: Path) -> str:
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def create_tarball() -> str:
    if not MODEL_PACKAGE.exists():
        raise FileNotFoundError(f"Model package not found: {MODEL_PACKAGE}")
    if not TOKENIZER_DIR.exists():
        raise FileNotFoundError(f"Tokenizer directory not found: {TOKENIZER_DIR}")

    if TARBALL_PATH.exists():
        TARBALL_PATH.unlink()

    print(f"Creating tarball: {TARBALL_PATH}")
    with tarfile.open(TARBALL_PATH, "w:gz") as tar:
        tar.add(MODEL_PACKAGE, arcname=MODEL_PACKAGE.name)
        tar.add(TOKENIZER_DIR, arcname=TOKENIZER_DIR.name)

    checksum = calculate_sha256(TARBALL_PATH)
    print(f"SHA256: {checksum}")

    with open(CHECKSUM_FILE, "w") as f:
        f.write(f"{checksum}  {TARBALL_NAME}\n")
    print(f"Checksum saved to: {CHECKSUM_FILE}")

    return checksum


def upload_to_huggingface() -> None:
    hf_token = os.environ.get("HF_TOKEN")
    if not hf_token:
        raise SystemExit("HF_TOKEN environment variable is required")

    try:
        from huggingface_hub import HfApi
    except ImportError as e:
        raise SystemExit("huggingface-hub not installed. Run: uv sync") from e

    api = HfApi(token=hf_token)

    print(f"Uploading model package to {HF_REPO_ID}...")
    api.upload_folder(
        folder_path=MODEL_PACKAGE,
        repo_id=HF_REPO_ID,
        repo_type="model",
        path_in_repo="SentimentKitSentiment.mlpackage",
    )
    print("Model package uploaded.")

    print(f"Uploading tokenizer to {HF_REPO_ID}...")
    api.upload_folder(
        folder_path=TOKENIZER_DIR,
        repo_id=HF_REPO_ID,
        repo_type="model",
        path_in_repo="SentimentKitSentiment.tokenizer",
    )
    print("Tokenizer uploaded.")

    print(f"Uploading checksum file to {HF_REPO_ID}...")
    api.upload_file(
        path_or_fileobj=str(CHECKSUM_FILE),
        repo_id=HF_REPO_ID,
        repo_type="model",
        path_in_repo="checksum.sha256",
    )
    print("Checksum uploaded.")

    print(f"Uploading tarball to {HF_REPO_ID}...")
    api.upload_file(
        path_or_fileobj=str(TARBALL_PATH),
        repo_id=HF_REPO_ID,
        repo_type="model",
        path_in_repo=TARBALL_NAME,
    )
    print("Tarball uploaded.")

    print(f"\nUpload complete!")
    print(f"Model URL: https://huggingface.co/{HF_REPO_ID}")
    print(
        f"Download URL: https://huggingface.co/{HF_REPO_ID}/resolve/main/{TARBALL_NAME}"
    )


def verify_local_artifacts() -> bool:
    missing = []
    if not MODEL_PACKAGE.exists():
        missing.append(str(MODEL_PACKAGE))
    if not TOKENIZER_DIR.exists():
        missing.append(str(TOKENIZER_DIR))

    if missing:
        print("Missing artifacts:")
        for p in missing:
            print(f"  {p}")
        print("\nRun ./convert.sh first to generate model artifacts.")
        return False
    return True


def main() -> None:
    print("=== SentimentKit CoreML Upload ===\n")

    if not verify_local_artifacts():
        sys.exit(1)

    checksum = create_tarball()

    print("\nUploading to HuggingFace...")
    upload_to_huggingface()

    print(f"\nLocal checksum file: {CHECKSUM_FILE}")
    print(f"SHA256: {checksum}")


if __name__ == "__main__":
    main()
