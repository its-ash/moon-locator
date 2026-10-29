.PHONY: run build deploy sync

APK := build/moon-locator.apk
TAG = $(shell git tag -l 'v*' --sort=-v:refname | head -n1)
BASE = $(shell sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
VER = $(if $(TAG),$(shell echo "$(TAG)" | awk -F. '{sub(/^v/, "", $$1); printf "%d.%d.%d", $$1, $$2, $$3 + 1}'),$(BASE))
NUM = $(shell echo $$(( $$(git tag -l 'v*' | wc -l) + 1 )))

run:
	flutter run

build:
	flutter build apk --release --build-name=$(VER) --build-number=$(NUM)
	cp build/app/outputs/flutter-apk/app-release.apk $(APK)

sync:
	git fetch -q --tags origin

deploy: sync build
	git checkout main
	git add -A
	git diff --cached --quiet || git commit -m "$$(copilot -sp 'Analyze the staged git changes and generate a concise commit message. Output ONLY the commit message. Do not execute any commands. Do not include quotes, markdown, explanation, or bullet points.')"
	git push origin main
	git tag -a v$(VER) -m "v$(VER)"
	git push origin v$(VER)
	gh release create v$(VER) $(APK) --title "Moon Locator v$(VER)" --generate-notes --latest
