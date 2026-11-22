.PHONY: build bundle dev test clean

build:
	./scripts/build.sh

bundle:
	./scripts/bundle.sh

dev:
	./scripts/dev.sh

test:
	swift test

clean:
	rm -rf build .build
