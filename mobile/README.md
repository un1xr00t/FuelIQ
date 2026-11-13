# FuelIQ for iOS

Dark mode is the default. FuelIQ uses silver headers, graphite panels, and green primary actions. Settings saves the selected appearance. Garage supports multiple vehicles, one primary vehicle, and optional photos. Fuel Log supports manual entry, editing, and deletion for full and partial tanks. Home shows all-time spending from saved fill-ups. Stations shows an unavailable state pending an authorized source.

## Getting started

Run from `mobile/` with Flutter 3.41.7 / Dart 3.11.5, Xcode, CocoaPods, and a booted iPhone simulator. The deployment target is iOS 15.0, the minimum supported by the local Xcode 27.1 simulator SDK. The development bundle identifier is `com.fueliq.fueliq`. Configure distribution signing before building for release.

```sh
flutter pub get
flutter devices
flutter run -d <simulator-id>
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode and select your development team for the Runner target. Stop any active `flutter run` before building from Xcode. Flutter can temporarily redirect Runner's build output during a device run, which can leave Xcode looking for CocoaPods frameworks in a different directory.

On Flutter 3.41, FuelIQ pins the CocoaPods implementation of `path_provider_foundation` to avoid the [native framework install failure](https://github.com/flutter/flutter/issues/185667). After updating dependencies, run `flutter pub get` from `mobile/`, then `pod install` from `mobile/ios/`. If Xcode still embeds `objective_c.framework`, use **Product > Clean Build Folder** and run again.

The app runs offline and needs no environment variables, account, API keys, or backend. `path_provider` locates the iOS Application Support directory. A versioned JSON snapshot stores vehicle and fill-up IDs, primary vehicle, and appearance. Writes replace the snapshot atomically. Amounts use integer cents and thousandths for US gallons and price per gallon. A difference over two cents prompts for confirmation and preserves the entered total.

Garage and Fuel Log use Journal Intelligence V2’s inline photo picker on iOS 17 and later. The sheet opens to the system Photos grid and its camera button switches to a live viewfinder in the same sheet. FuelIQ imports one photo at a time. Photos selection uses the system picker without broad library access, and captures stay in FuelIQ’s temporary directory. On iOS 15–16, the sheet offers the system camera and library through `image_picker`. Garage keeps a resized copy without EXIF in its local snapshot and attempts to remove the temporary original after processing. Replacing, removing, or deleting a saved vehicle photo removes the resized copy from the next snapshot. A vehicle with saved fill-ups can be deleted once its entries are removed.

## Scan a fill-up

Add a vehicle, open Fuel Log, and tap **Scan a fill-up**. Take a photo or select one from Photos. Use a completed pump display or fuel receipt with the labels visible. You can scan another photo to fill remaining blanks. Check the editable values, enter any missing fields, and tap **Save fill-up**.

[Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images) reads text locally. FuelIQ proposes US gallons, total paid, price per gallon, and explicitly identified octane (85–99 AKI). A row matched by position or read with lower OCR confidence is labeled uncertain. Check that a receipt total covers fuel only. If the price is missing, you can calculate it from the entered gallons and total. A row of octane buttons does not identify the selected grade. Scan a receipt with the grade printed or enter it manually.

The scanner accepts JPEG, PNG, and HEIC/HEIF photos up to 30 MB and 60 megapixels. It uses image orientation to read rotated photos. FuelIQ requests no full photo metadata, stores no scan image or raw OCR text with a fill-up, and attempts to delete the app's temporary picker copy when scanning ends. No Gemini key, Apple Intelligence setting, or upload is required. EXIF-based dates, station matching, and OCR of addresses or dates are future work.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run --no-resident -d <simulator-id>
```

With Flutter 3.41.7 and Xcode 27.1, `flutter build ios --simulator` can fail when targeting both simulator architectures. Use the device-specific command above to build and launch on a booted simulator.

Add a vehicle with a photo, log a partial fill-up, and compare Home spending with the receipt. Relaunch and verify the vehicle, photo, entry, and appearance persist. Edit the entry and verify the updated total, then delete it and verify the total clears. Try the photo picker with a PNG or JPEG in the simulator and with a real photo on an iPhone. Check VoiceOver and large text on both editors.

On an iPhone, take a vehicle photo in Garage and verify it persists after saving and relaunching. Try replacing it from Photos, canceling the replacement, and denying camera access. Scan a receipt and a completed pump display in Airplane Mode. Check the proposals against the images, including a receipt with non-fuel purchases and a pump with several octane buttons. Try scanning an unreadable photo and verify that manual entry and saving still work.
