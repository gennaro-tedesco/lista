.PHONY: android ios all

android:
	flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config.json

ios:
	flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --dart-define-from-file=config.json

all: android ios
