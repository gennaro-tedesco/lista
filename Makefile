.PHONY: run android ios install_ios install_android all

APP_VERSION := $(shell tag=$$(git describe --tags --exact-match 2>/dev/null || true); if [ -n "$$tag" ]; then printf '%s' "$$tag"; else git rev-parse --short HEAD; fi)
BUILD_NUMBER := $(shell git rev-list --count HEAD)

run:
	flutter run --dart-define-from-file=config.json

android:
	flutter build apk --release --target-platform android-arm64 --build-number=$(BUILD_NUMBER) --dart-define=APP_VERSION=$(APP_VERSION) --dart-define-from-file=config.json

ios:
	flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --build-number=$(BUILD_NUMBER) --dart-define=APP_VERSION=$(APP_VERSION) --dart-define-from-file=config.json

install_android:
	adb install build/app/outputs/flutter-apk/app-release.apk

install_ios:
	ideviceinstaller -i build/ios/ipa/*.ipa

all: android ios
