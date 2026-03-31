SWIFT ?= swift
TOOLS_DIR := Tools/CoreMLConversion

.PHONY: build test coverage lint check golden-suggest
.PHONY: coreml-convert coreml-upload coreml-validate coreml-validate-local coreml-checksum

build:
	$(SWIFT) build

test:
	$(SWIFT) test

coverage:
	$(SWIFT) test --filter DictionaryCoverageTests

lint:
	@command -v swift-format >/dev/null 2>&1 || { echo "swift-format is required. Install it with: brew install swift-format"; exit 1; }
	swift-format lint -r --strict Sources Tests

check: build test coverage lint

golden-suggest: build
	@$(SWIFT) run golden-suggest --lang "$(LANG)" --text "$(TEXT)"

# CoreML model lifecycle targets

coreml-convert: ## Convert PyTorch model to CoreML (requires macOS)
	cd $(TOOLS_DIR) && ./convert.sh

coreml-validate-local: ## Validate local CoreML model before upload (score tests)
	@echo "Validating local CoreML artifacts..."
	@if [ ! -f $(TOOLS_DIR)/artifacts/SentimentKitSentiment.mlpackage/Manifest.json ]; then \
		echo "Error: Model not converted. Run 'make coreml-convert' first."; \
		exit 1; \
	fi
	@if [ ! -f $(TOOLS_DIR)/artifacts/SentimentKitSentiment.tokenizer/vocab.txt ]; then \
		echo "Error: Tokenizer artifacts missing. Run 'make coreml-convert' first."; \
		exit 1; \
	fi
	@echo "Running CoreMLScorerTests against local model..."
	$(SWIFT) test --filter CoreMLScorerTests

coreml-upload: ## Upload CoreML artifacts to HuggingFace (requires HF_TOKEN)
	@if [ -z "$$HF_TOKEN" ]; then \
		echo "Error: HF_TOKEN environment variable is required"; \
		echo "Example: export HF_TOKEN=\$$(op read 'op://FRR DEV/HuggingFace API token/credential')"; \
		exit 1; \
	fi
	@if [ ! -f $(TOOLS_DIR)/artifacts/SentimentKitSentiment.mlpackage/Manifest.json ]; then \
		echo "Error: Model not converted. Run 'make coreml-convert' first."; \
		exit 1; \
	fi
	cd $(TOOLS_DIR) && uv sync && uv run python upload_to_hf.py

coreml-validate: ## Validate CoreML model from HuggingFace (requires network + ~100MB download)
	ENABLE_COREML_DOWNLOAD_TESTS=1 $(SWIFT) test --filter CoreMLDownloadTests

coreml-checksum: ## Compare local checksum vs HuggingFace
	@cd $(TOOLS_DIR) && \
	if [ ! -f artifacts/SentimentKitSentiment.mlpackage/Manifest.json ]; then \
		echo "Error: Model not converted. Run 'make coreml-convert' first."; \
		exit 1; \
	fi && \
	echo "Fetching remote checksum..." && \
	REMOTE_CHECKSUM=$$(curl -sL "https://huggingface.co/frr149/SentimentKit/resolve/main/checksum.sha256" | cut -d' ' -f1) && \
	echo "Remote checksum: $$REMOTE_CHECKSUM" && \
	if [ -f artifacts/checksum.sha256 ]; then \
		LOCAL_CHECKSUM=$$(cat artifacts/checksum.sha256 | cut -d' ' -f1) && \
		echo "Local checksum:  $$LOCAL_CHECKSUM" && \
		if [ "$$REMOTE_CHECKSUM" = "$$LOCAL_CHECKSUM" ]; then \
			echo "Checksums match."; \
		else \
			echo "Warning: Checksums differ. Local may be out of date."; \
			exit 1; \
		fi; \
	else \
		echo "No local checksum found. Run 'make coreml-upload' to generate."; \
	fi