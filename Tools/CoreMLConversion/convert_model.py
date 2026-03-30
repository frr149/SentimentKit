from __future__ import annotations

from pathlib import Path


MODEL_ID = "lxyuan/distilbert-base-multilingual-cased-sentiments-student"
OUTPUT_DIR = Path(__file__).resolve().parent / "artifacts"


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

    output_path = OUTPUT_DIR / "SentimentKitSentiment.mlpackage"
    mlmodel.save(str(output_path))
    print(f"Saved CoreML package to {output_path}")


if __name__ == "__main__":
    main()
