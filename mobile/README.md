# FuelIQ for iOS

The first development milestone includes the Cupertino app shell, five tabs, and shared light and dark design tokens. Home links to Garage, Fuel Log, and Stations. Those tabs show empty or unavailable states until their features ship. Settings follows the system appearance by default. Manual overrides last until the app exits.

## Getting started

Run from `mobile/` with Flutter 3.41.7 / Dart 3.11.5, Xcode, and a booted iPhone simulator. The deployment target is iOS 15.0, the minimum supported by the local Xcode 27.1 simulator SDK. The development bundle identifier is `com.fueliq.fueliq`. Configure distribution signing before building for release.

```sh
flutter pub get
flutter devices
flutter run -d <simulator-id>
```

`lib/app/` owns navigation and appearance state. Each tab has its own Cupertino navigator. `lib/design_system/` holds color, typography, spacing, and shared page components. `lib/features/` holds feature screens. The app runs offline and needs no environment variables, API keys, or database setup. Cupertino Icons supplies the iOS-style glyphs.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run --no-resident -d <simulator-id>
```

With Flutter 3.41.7 and Xcode 27.1, `flutter build ios --simulator` can fail when targeting both simulator architectures. Use the device-specific command above to build and launch on a booted simulator.

Launch into Home, open all five tabs and the Home shortcuts, then select System, Light, and Dark in Settings. On a small iPhone layout, increase text size and scroll through Home. Use VoiceOver to check tab and appearance selection announcements.
