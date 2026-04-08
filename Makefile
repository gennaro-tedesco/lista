.PHONY: run android ios install_ios install_android all

run:
	flutter run --dart-define-from-file=config.json

android:
	flutter build apk --release --target-platform android-arm64 --dart-define-from-file=config.json

ios:
	flutter build ipa --release --export-options-plist=ios/ExportOptions.plist --dart-define-from-file=config.json

install_android:
	adb install build/app/outputs/flutter-apk/app-release.apk

install_ios:
	ideviceinstaller -i build/ios/ipa/*.ipa

all: android ios
