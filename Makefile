.PHONY: run android ios all

run:
	flutter run --dart-define-from-file=config.json

android:
	flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config.json

ios:
	flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --dart-define-from-file=config.json

all: android ios
