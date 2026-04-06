.PHONY: android ios all

android:
	flutter build apk --release --target-platform android-arm64

ios:
	flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

all: android ios
