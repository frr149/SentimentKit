# SentimentKit CoreML Model

Multilingual sentiment analysis model for developer/technical text, converted to CoreML with INT8 quantization.

## Model Details

- **Base Model**: [lxyuan/distilbert-base-multilingual-cased-sentiments-student](https://huggingface.co/lxyuan/distilbert-base-multilingual-cased-sentiments-student)
- **Languages**: 12 languages including English, Spanish, Portuguese, German, French, Chinese, Japanese, Arabic, Hindi, and more
- **Quantization**: INT8 weight quantization via coremltools
- **Framework**: CoreML (mlprogram format)
- **Usage**: Optional CoreML layer for [SentimentKit](https://github.com/frr149/SentimentKit)

## Downloads

| File | Size | Description |
|------|------|-------------|
| `sentimentkit-sentiment-coreml.tar.gz` | ~100 MB | Combined model + tokenizer |
| `SentimentKitSentiment.mlpackage/` | ~100 MB | CoreML model only |
| `SentimentKitSentiment.tokenizer/` | ~500 KB | BERT WordPiece tokenizer |
| `checksum.sha256` | - | SHA256 checksum of tarball |

Download URL format:
```
https://huggingface.co/frr149/SentimentKit/resolve/main/sentimentkit-sentiment-coreml.tar.gz
```

## Checksum Verification

After downloading, verify thechecksum:

```bash
sha256sum sentimentkit-sentiment-coreml.tar.gz
# Compare with checksum.sha256
```

## Usage with SentimentKit

### Option 1: Bundle with app

Include these directories in your app bundle:
- `SentimentKitSentiment.mlpackage/`
- `SentimentKitSentiment.tokenizer/`

### Option 2: Download on demand

```swift
let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
let modelURL = cacheDir.appending(path: "SentimentKitSentiment.mlpackage")

var config = SentimentConfig()
config.enableCoreML = true
config.coreMLModelURL = modelURL

let analyzer = SentimentAnalyzer(config: config)
let result = analyzer.analyze("This isexcellent work!")
```

### Option 3: Use bundle resources

If you include the model in your app's resources:

```swift
var config = SentimentConfig()
config.enableCoreML = true
// model loads from Bundle.module or main bundle
let analyzer = SentimentAnalyzer(config: config)
```

## Model Output

- **Output**: Logits for 3 classes: `[positive, neutral, negative]`
- **Score range**: -2.0 to+2.0 (SentimentKit normalizes logits to this range)
- **Sequence length**: Max 128 tokens

## License

The base model is licensed under Apache 2.0 (from HuggingFace).
This CoreML conversion is provided under the same license.

## Citation

If you use this model, please cite the original:

```bibtex
@article{lxyuan2023distilbert,
  title={DistilBERT-base-multilingual-cased-sentiment-student},
  author={Lxyuan},
  year={2023},
  url={https://huggingface.co/lxyuan/distilbert-base-multilingual-cased-sentiments-student}
}
```

## Related

- [SentimentKit GitHub](https://github.com/frr149/SentimentKit) - Swift package for multilingual sentiment analysis
- [Original Model](https://huggingface.co/lxyuan/distilbert-base-multilingual-cased-sentiments-student) - HuggingFace source