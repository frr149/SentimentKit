SWIFT ?= swift

.PHONY: build test coverage lint check

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
