# FuelIQ for iOS

The iOS app uses a true black background with blue accents in Dark mode, which is the default. Settings saves the selected appearance. Garage supports multiple vehicles, one primary vehicle, and optional photos. Fuel Log supports manual entry, editing, and deletion for full and partial tanks. Home shows all-time spending from saved fill-ups. Stations shows an unavailable state pending an authorized source.

## Getting started

Run from `mobile/` with Flutter 3.41.7 / Dart 3.11.5, Xcode, CocoaPods, and a booted iPhone simulator. The deployment target is iOS 15.0, the minimum supported by the local Xcode 27.1 simulator SDK. The development bundle identifier is `com.fueliq.fueliq`. Configure distribution signing before building for release.

```sh
flutter pub get
flutter devices
flutter run -d <simulator-id>
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode and select your development team for the Runner target. Stop any active `flutter run` before building from Xcode. Flutter can temporarily redirect Runner's build output during a device run, which can leave Xcode looking for CocoaPods frameworks in a different directory.

The app runs offline and needs no environment variables, account, API keys, or backend. `path_provider` locates the iOS Application Support directory. A versioned JSON snapshot stores vehicle and fill-up IDs, primary vehicle, and appearance. Writes replace the snapshot atomically. Amounts use integer cents and thousandths for US gallons and price per gallon. A difference over two cents prompts for confirmation and preserves the entered total.

`image_picker` uses the system photo library picker without requesting full metadata. FuelIQ keeps a resized copy without EXIF in its local snapshot. Replacing, removing, or deleting a saved vehicle photo removes that copy from the next snapshot. A vehicle with saved fill-ups can be deleted once its entries are removed.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run --no-resident -d <simulator-id>
```

With Flutter 3.41.7 and Xcode 27.1, `flutter build ios --simulator` can fail when targeting both simulator architectures. Use the device-specific command above to build and launch on a booted simulator.

Add a vehicle with a photo, log a partial fill-up, and compare Home spending with the receipt. Relaunch and verify the vehicle, photo, entry, and appearance persist. Edit the entry and verify the updated total, then delete it and verify the total clears. Try the photo picker with a PNG or JPEG in the simulator and with a real photo on an iPhone. Check VoiceOver and large text on both editors.
