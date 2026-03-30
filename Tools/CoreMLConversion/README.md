# CoreML Conversion

This directory contains the reproducible tooling for converting the multilingual sentiment model used by SentimentKit into a CoreML asset.

Current target model from the PRD:

- `lxyuan/distilbert-base-multilingual-cased-sentiments-student`

Workflow:

1. `./convert.sh`
2. Optionally: `./convert.sh --compile`
3. Review the generated artifact under `artifacts/`

The Swift package is designed to work without the model present. This tooling exists so model conversion is reproducible and reviewable, but v1 does not ship the CoreML artifact in the repo.

Current integration contract:

- SentimentKit works normally when the CoreML artifact is absent.
- The package does not have a hosted download URL yet.
- For now, CoreML integration is a maintainer/integrator workflow: generate the model locally, keep `SentimentKitSentiment.mlpackage` together with the sibling directory `SentimentKitSentiment.tokenizer/`, and pass the model path through `SentimentConfig.coreMLModelURL` or bundle both assets in the consuming app.
- If the model or tokenizer assets are missing, SentimentKit falls back to the deterministic pipeline instead of failing analysis.

Current status:

- conversion script runs successfully on macOS with Python 3.11 and Torch 2.5.x
- generated artifact name: `SentimentKitSentiment.mlpackage`
- the final saved package is INT8 weight-quantized via `coremltools.optimize.coreml.linear_quantize_weights`
- an intermediate unquantized package is kept as `SentimentKitSentiment.raw.mlpackage` for inspection only
- compiled CoreML artifact size observed locally: ~258 MB

Artifacts are intentionally ignored in git. The current decision is:

- keep the conversion pipeline in-repo
- do not commit the `.mlpackage`
- do not ship the model as part of the SPM package
- define any hosted distribution URL separately from this conversion workflow
