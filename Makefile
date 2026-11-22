.PHONY: build dev test clean

build:
	./scripts/build.sh

dev:
	./scripts/dev.sh

test:
	xcodebuild test -project Stayman.xcodeproj -scheme Stayman

clean:
	rm -rf build
