# CoreML Conversion

This directory contains the reproducible tooling for converting the multilingual sentiment model used by SentimentKit into a CoreML asset.

Current target model from the PRD:

- `lxyuan/distilbert-base-multilingual-cased-sentiments-student`

Workflow:

1. `uv sync`
2. `uv run python convert_model.py`
3. Compile the produced `.mlpackage` or `.mlmodel` if needed with `coremlcompiler`
4. Move the compiled model into the SwiftPM resources once the artifact is validated

The Swift package is designed to work without the model present. This tooling exists so model conversion is reproducible and reviewable.

Current status:

- conversion script runs successfully on macOS with Python 3.11 and Torch 2.5.x
- generated artifact name: `SentimentKitSentiment.mlpackage`
- compiled CoreML artifact size observed locally: ~258 MB

Artifacts are intentionally ignored in git for now until distribution strategy is decided.
