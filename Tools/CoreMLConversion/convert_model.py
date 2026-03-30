from __future__ import annotations

from pathlib import Path


MODEL_ID = "lxyuan/distilbert-base-multilingual-cased-sentiments-student"
OUTPUT_DIR = Path(__file__).resolve().parent / "artifacts"
RAW_OUTPUT_PATH = OUTPUT_DIR / "SentimentKitSentiment.raw.mlpackage"
QUANTIZED_OUTPUT_PATH = OUTPUT_DIR / "SentimentKitSentiment.mlpackage"
MODEL_AUTHOR = "SentimentKit"
MODEL_VERSION = "1"
SHORT_DESCRIPTION = "Quantized multilingual sentiment classifier for SentimentKit."
CLASS_LABELS = ["positive", "neutral", "negative"]


class LogitsOnlyModel(__import__("torch").nn.Module):
    def __init__(self, base_model):
        super().__init__()
        self.base_model = base_model

    def forward(self, input_ids, attention_mask):
        outputs = self.base_model(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.logits


def main() -> None:
    try:
        import coremltools as ct
        import coremltools.optimize as cto
        from transformers import AutoModelForSequenceClassification, AutoTokenizer
    except ImportError as error:  # pragma: no cover - runtime environment check
        raise SystemExit(
            "Missing conversion dependencies. Run `uv sync` inside Tools/CoreMLConversion first."
        ) from error

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading tokenizer and model: {MODEL_ID}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    base_model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID)
    model = LogitsOnlyModel(base_model)
    model.eval()

    example = tokenizer(
        "This answer is disappointing and confusing.",
        return_tensors="pt",
        truncation=True,
        padding="max_length",
        max_length=128,
    )

    torch = __import__("torch")

    traced = torch.jit.trace(
        model,
        (
            example["input_ids"],
            example["attention_mask"],
        ),
        strict=False,
    )

    print("Converting traced model to CoreML")
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[
            ct.TensorType(name="input_ids", shape=example["input_ids"].shape, dtype=example["input_ids"].numpy().dtype),
            ct.TensorType(
                name="attention_mask",
                shape=example["attention_mask"].shape,
                dtype=example["attention_mask"].numpy().dtype,
            ),
        ],
        compute_units=ct.ComputeUnit.ALL,
    )

    mlmodel.author = MODEL_AUTHOR
    mlmodel.version = MODEL_VERSION
    mlmodel.short_description = SHORT_DESCRIPTION
    mlmodel.license = "Apache-2.0 (upstream model)"
    mlmodel.user_defined_metadata.update({
        "source_model_id": MODEL_ID,
        "class_labels": ",".join(CLASS_LABELS),
        "tokenizer_model": "bert-wordpiece",
        "sentimentkit_pipeline_role": "optional-coreml-layer",
    })

    print("Saving temporary unquantized CoreML package")
    if RAW_OUTPUT_PATH.exists():
        if RAW_OUTPUT_PATH.is_dir():
            import shutil

            shutil.rmtree(RAW_OUTPUT_PATH)
        else:
            RAW_OUTPUT_PATH.unlink()
    mlmodel.save(str(RAW_OUTPUT_PATH))

    print("Applying INT8 weight quantization")
    quantized_model = cto.coreml.linear_quantize_weights(mlmodel, mode="linear_symmetric")
    quantized_model.author = MODEL_AUTHOR
    quantized_model.version = MODEL_VERSION
    quantized_model.short_description = SHORT_DESCRIPTION
    quantized_model.license = "Apache-2.0 (upstream model)"
    quantized_model.user_defined_metadata.update({
        "source_model_id": MODEL_ID,
        "class_labels": ",".join(CLASS_LABELS),
        "tokenizer_model": "bert-wordpiece",
        "quantization": "int8-linear-symmetric",
        "sentimentkit_pipeline_role": "optional-coreml-layer",
    })

    if QUANTIZED_OUTPUT_PATH.exists():
        if QUANTIZED_OUTPUT_PATH.is_dir():
            import shutil

            shutil.rmtree(QUANTIZED_OUTPUT_PATH)
        else:
            QUANTIZED_OUTPUT_PATH.unlink()
    quantized_model.save(str(QUANTIZED_OUTPUT_PATH))
    print(f"Saved quantized CoreML package to {QUANTIZED_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
