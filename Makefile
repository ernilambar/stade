.PHONY: build test clean

build:
	./scripts/build.sh

test:
	xcodebuild test -project Stayman.xcodeproj -scheme Stayman

clean:
	rm -rf build
