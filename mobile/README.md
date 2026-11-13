# FuelIQ for iOS

Dark mode is the default. FuelIQ uses adaptive headers, neutral black panels, and blue primary actions. Settings saves the selected appearance. Garage supports multiple vehicles, one primary vehicle, and optional photos. Fuel Log supports manual entry, editing, and deletion for full and partial tanks. Home shows all-time and year-to-date spending, monthly spending, gallons, fill-up count, and average price paid per gallon for all vehicles or a selected vehicle. Month and year boundaries follow device local time. Stations includes an offline Pennsylvania pilot.

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

## Pennsylvania station pilot

Search by station name, brand, address, or ZIP where available. **Use my location** asks for iOS When In Use permission and requests a single location fix. Results show up to 30 stations within 25 straight-line miles. Text search works if location is denied or unavailable. Coordinates stay in memory on the device and are never sent to a server.

### Source registry

- **Station locations:** [Geofabrik Pennsylvania OSM PBF](https://download.geofabrik.de/north-america/us/pennsylvania.html), [download endpoint](https://download.geofabrik.de/north-america/us/pennsylvania-latest.osm.pbf). Public bulk download, no API key or paid service. Geofabrik publishes updated extracts regularly. The app uses a bundled snapshot and makes no live requests. Refresh the asset to update the app.
- **Rights:** © OpenStreetMap contributors. [ODbL 1.0 and attribution](https://www.openstreetmap.org/copyright). The [derived database](assets/stations/pennsylvania.json) is available under ODbL 1.0. Include a public copy of that file under ODbL when distributing the app. The raw extract is not included in the repository.
- **Snapshot:** Source timestamp 2026-11-12 21:23:05 UTC, retrieved November 13, 2026. SHA-256 of input PBF is `28a1f47d47f2814ea545d99d72812a9a5048c0a79225841618b4848bc7e91bbf`. 3,871 records include source type and ID, name, brand, address, and coordinates. 1,597 have any mapped address component. Fuel POIs come from `amenity=fuel`, with explicitly private or prohibited access excluded. Areas use their outer ring bounding-box midpoint. Duplicate source IDs are rejected, but separate mapped objects may describe one physical site.
- **Certification:** Local records carry no TOP TIER status. The Stations header and detail screen open the [official Station Finder](https://stationfinder.toptiergas.com/) externally for address-level lookup. The link sends no search or location parameters. Per the [TOP TIER terms](https://www.toptiergas.com/terms-and-conditions/), obtain authorization for station data reuse and the pump decal before shipping badges. Match the exact site and fuel type against authorized records, with provenance and freshness. Prices and fuel grades are also unavailable.

To regenerate the catalog, download the extract from the source above, install `osmium==4.3.2` in a Python 3.13 environment, then run from `mobile/`:

```sh
python tool/build_station_catalog.py /path/to/pennsylvania-latest.osm.pbf assets/stations/pennsylvania.json
```

### Station logo sources

Local PNG thumbnails use the following Wikimedia Commons files, marked public domain for copyright on their source pages. Brand marks identify listed stations. Named stations without matching artwork use initials. Generic or unnamed listings use a fuel icon. BP uses the simplified text logo.

In the bundled 3,871-record snapshot, 2,176 records match local logo assets, 1,179 use initials, and 516 use the generic icon. The largest gaps among named listings are Turkey Hill (181), Wawa (177), and GetGo (89). These counts describe catalog records, which may include duplicate sites.

- `7-eleven.png` · [Logo of 7-Eleven (transparent).svg](https://commons.wikimedia.org/wiki/File:Logo_of_7-Eleven_%28transparent%29.svg)
- `bp.png` · [Bp textlogo.svg](https://commons.wikimedia.org/wiki/File:Bp_textlogo.svg)
- `circle-k.png` · [Circle K logo 2015.svg](https://commons.wikimedia.org/wiki/File:Circle_K_logo_2015.svg)
- `citgo.png` · [Citgo logo.svg](https://commons.wikimedia.org/wiki/File:Citgo_logo.svg)
- `conoco.png` · [Conoco logo.svg](https://commons.wikimedia.org/wiki/File:Conoco_logo.svg)
- `costco.png` · [Costco Wholesale logo 2010-10-26.svg](https://commons.wikimedia.org/wiki/File:Costco_Wholesale_logo_2010-10-26.svg)
- `exxon.png` · [Exxon logo.svg](https://commons.wikimedia.org/wiki/File:Exxon_logo.svg)
- `giant.png` · [Giant-Carlisle logo.svg](https://commons.wikimedia.org/wiki/File:Giant-Carlisle_logo.svg)
- `gulf.png` · [Gulf Oil logo.svg](https://commons.wikimedia.org/wiki/File:Gulf_Oil_logo.svg)
- `kwik-fill.png` · [Kwik Fill logo.png](https://commons.wikimedia.org/wiki/File:Kwik_Fill_logo.png)
- `lukoil.png` · [Lukoil company logo.svg](https://commons.wikimedia.org/wiki/File:Lukoil_company_logo.svg)
- `marathon.png` · [Marathon Petroleum logo 2022.svg](https://commons.wikimedia.org/wiki/File:Marathon_Petroleum_logo_2022.svg)
- `mobil.png` · [MobilTextlogo.svg](https://commons.wikimedia.org/wiki/File:MobilTextlogo.svg)
- `pennzoil.png` · [Pennzoil textlogo.png](https://commons.wikimedia.org/wiki/File:Pennzoil_textlogo.png)
- `phillips-66.png` · [Phillips 66 logo.svg](https://commons.wikimedia.org/wiki/File:Phillips_66_logo.svg)
- `royal-farms.png` · [Royal Farms logo.svg](https://commons.wikimedia.org/wiki/File:Royal_Farms_logo.svg)
- `rutters.png` · [Rutter's Logo.png](https://commons.wikimedia.org/wiki/File:Rutter%27s_Logo.png)
- `sams-club.png` · [Sam's Club logo 2026.svg](https://commons.wikimedia.org/wiki/File:Sam%27s_Club_logo_2026.svg)
- `sheetz.png` · [Sheetz logo (2024).svg](https://commons.wikimedia.org/wiki/File:Sheetz_logo_%282024%29.svg)
- `shell.png` · [Shell 1971 wordmark.svg](https://commons.wikimedia.org/wiki/File:Shell_1971_wordmark.svg)
- `speedway.png` · [Speedway LLC logo.svg](https://commons.wikimedia.org/wiki/File:Speedway_LLC_logo.svg)
- `sunoco.png` · [Sunoco 1999 logo.svg](https://commons.wikimedia.org/wiki/File:Sunoco_1999_logo.svg)
- `ta.png` · [TravelCenters of America logo.svg](https://commons.wikimedia.org/wiki/File:TravelCenters_of_America_logo.svg)
- `valero.png` · [Valero Energy logo.svg](https://commons.wikimedia.org/wiki/File:Valero_Energy_logo.svg)
- `weis.png` · [Weis Markets logo.svg](https://commons.wikimedia.org/wiki/File:Weis_Markets_logo.svg)

### Measuring listing accuracy

Validate a stratified urban, suburban, rural, and border sample before broader release. Compare independent retailer listings and [Pennsylvania DEP tank records](https://www.pa.gov/agencies/dep/programs-and-services/land/storage-tanks/storage-tank-data), keeping regulatory facilities distinct from public retail stations. Confirm disputed locations with the operator or a field check. Track missing stations, closed or private listings, duplicate sites, wrong names and addresses, and coordinate error separately. Device accuracy affects ranking, while source accuracy determines whether a station is real and current.

For production, move ingestion and proximity search to FuelIQ’s versioned API and PostGIS database. Keep source IDs and timestamps, resolve duplicates conservatively, and publish coverage and freshness per region. Refresh on a schedule and preserve the last good snapshot when ingestion fails.

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


For Stations on iOS, set a simulated location in Pennsylvania. Open Stations, tap **Use my location**, grant permission, then check distance order and open a detail. Reset permission and repeat with denial. Verify text search still works, including in Airplane Mode. Try a location outside the pilot region.
