SWIFT ?= swift

.PHONY: build test coverage lint check

build:
	$(SWIFT) build

test:
	$(SWIFT) test

coverage:
	$(SWIFT) test --filter DictionaryCoverageTests

lint:
	@command -v swift-format >/dev/null 2>&1 && swift-format lint -r Sources Tests || echo "swift-format not installed; skipping lint"

check: build test coverage lint
