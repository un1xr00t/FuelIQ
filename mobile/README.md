# FuelIQ for iOS

Dark mode is the default. FuelIQ uses adaptive headers, neutral black panels, and blue primary actions. Settings saves the selected appearance. Garage supports multiple vehicles, one primary vehicle, and optional photos. Fuel Log supports manual entry, editing, and deletion for full and partial tanks. Home shows all-time and year-to-date spending, monthly spending, gallons, fill-up count, and average price paid per gallon for all vehicles or a selected vehicle. Month and year boundaries follow device local time. Stations includes an offline Pennsylvania pilot.

## Getting started

Run from `mobile/` with Flutter 3.41.7 / Dart 3.11.5, Xcode, CocoaPods, and a booted iPhone simulator. The deployment target is iOS 15.5, required by Google ML Kit. The development bundle identifier is `com.fueliq.fueliq`. Configure distribution signing before building for release.

```sh
flutter pub get
flutter devices
flutter run -d <simulator-id>
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode and select your development team for the Runner target. Stop any active `flutter run` before building from Xcode. Flutter can temporarily redirect Runner's build output during a device run, which can leave Xcode looking for CocoaPods frameworks in a different directory.

If Xcode reports `Framework 'Pods_Runner' not found` after a Flutter device run, regenerate the settings from `mobile/` with `flutter build ios --config-only --no-codesign`, then build again from the workspace.

On Flutter 3.41, FuelIQ pins the CocoaPods implementation of `path_provider_foundation` to avoid the [native framework install failure](https://github.com/flutter/flutter/issues/185667). After updating dependencies, run `flutter pub get` from `mobile/`, then `pod install` from `mobile/ios/`. If Xcode still embeds `objective_c.framework`, use **Product > Clean Build Folder** and run again.

The app runs offline and needs no environment variables, account, API keys, or backend. `path_provider` locates the iOS Application Support directory. A versioned JSON snapshot stores vehicle and fill-up IDs, primary vehicle, and appearance. Writes replace the snapshot atomically. Amounts use integer cents and thousandths for US gallons and price per gallon. A difference over two cents prompts for confirmation and preserves the entered total.

Garage and Fuel Log use Journal Intelligence V2’s inline photo picker on iOS 17 and later. The sheet opens to the system Photos grid and its camera button switches to a live viewfinder in the same sheet. FuelIQ imports one photo at a time. Photos selection uses the system picker without broad library access, and captures stay in FuelIQ’s temporary directory. On iOS 15–16, the sheet offers the system camera and library through `image_picker`. Garage keeps a resized copy without EXIF in its local snapshot and attempts to remove the temporary original after processing. Replacing, removing, or deleting a saved vehicle photo removes the resized copy from the next snapshot. A vehicle with saved fill-ups can be deleted once its entries are removed.

## Scan a fill-up

In **Settings → Claude Vision API key**, save your personal Anthropic API key to enable Haiku 5.5 for Fuel Log scans. Settings shows when the key is saved in iOS Keychain. After relaunching FuelIQ on the same iPhone, open Settings again to verify the saved status. If a Keychain read fails, unlock the iPhone and retry. Selected images are resized and re-encoded before they are sent together to Anthropic. The original EXIF capture date is processed on the phone. Each request uses your Anthropic API account. Remove the key in Settings to make local OCR available by explicit choice when starting a scan. The review screen identifies which reader ran. The Mac benchmark reads its key separately from `~/.config/fueliq/anthropic_api_key`.

## Back up and restore

Use **Settings → Backup → Export backup** and choose a folder in iCloud Drive outside the app. Check that the file appears in Files. Each export is a manual snapshot of your fill-ups, Garage profiles and vehicle photos, and app preferences. Export again after changes you want to keep. The JSON file can contain station addresses and vehicle photos, so save it in a private folder. The Claude key stays in Keychain.

After reinstalling, select **Settings → Backup → Restore backup**, choose the JSON file in Files, and confirm. Restore replaces the current app records and preferences. Use a test installation to verify a backup and check the restored Garage and Fuel Log.

For local OCR diagnostics, run `python3 tool/pump_scan_capture.py <display-photo> <grade-photo>` from `mobile/` and redirect stdout to a temporary JSON file. Replay it with `FUELIQ_PUMP_SCAN_JSON=<json-file> flutter test test/pump_scan_diagnostic_test.dart`. Set `FUELIQ_PUMP_EXPECTED_JSON` to an object with expected `total` in cents, `gallons` and `price` in thousandths, and `octane` to assert the final fields. The macOS capture runs Apple Vision and the seven-segment reader. Replay also accepts ML Kit lines from an iPhone scan under `alternateText`. Output can contain private OCR text and capture dates. Keep it outside the repository.

For pump displays, frame the printed labels and the numbers together. FuelIQ can match a number above or below its label and recognizes labels such as `$ THIS SALE` and `$/GAL`. If two numbers are similarly close to a label, the field stays blank for manual review.

For an unlabeled, two-row seven-segment display, select the completed display and the price-per-gallon photo together. The on-device reader proposes the top row as the total and the bottom row as gallons when both readings agree to the cent with the scanned price and the match is clear. Review these uncertain readings before saving. Other display layouts may still require manual entry.

Add a vehicle, open Fuel Log, and tap **Scan a fill-up**. Select the grade photo and completed pump display or receipt together, or take a photo with the camera and use **Scan more photos** to add evidence. FuelIQ reads each selected photo and combines the fields into one draft. It flags conflicting fields and reports photos it could not read. Check the editable values, enter any missing fields, and tap **Save fill-up**.

[Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images) and [Google ML Kit Latin Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios) read text on-device. ML Kit can fill missing fields. If the readers propose different values for the same field, FuelIQ leaves that field blank for review. FuelIQ proposes US gallons, total paid, price per gallon, and explicitly identified octane (85–99 AKI). A row matched by position or read with lower OCR confidence is labeled uncertain. Check that a receipt total covers fuel only. If the price is missing, you can calculate it from the entered gallons and total. A row of octane buttons does not identify the selected grade. Scan a receipt with the grade printed or enter it manually.

The scanner accepts JPEG, PNG, and HEIC/HEIF photos up to 30 MB and 60 megapixels. It uses image orientation to read rotated photos. FuelIQ requests no full photo metadata, stores no scan image or raw OCR text with a fill-up, and attempts to delete the app's temporary picker copy when scanning ends. No Gemini key, Apple Intelligence setting, or upload is required. For new entries, FuelIQ suggests the original EXIF capture date when the selected photos agree. It uses the embedded offset when available and treats timestamps without one as local time. Check the date before saving. Fuel Log suggests stations within 150 meters of the photos’ EXIF GPS using the offline Pennsylvania catalog. Tap a suggestion or type a station name. Settings → Privacy hides Fuel Log station addresses by default. Turn the switch off to display saved catalog addresses. Open any saved entry to add or correct its station. Only the chosen station label is saved. Photo GPS stays on the phone and is not retained with the fill-up.

## Pennsylvania station pilot

Search by station name, brand, street address, or ZIP where available. **Use my location** asks for iOS When In Use permission and requests a single location fix. Results load 20 at a time near the bottom of the scroll, ordered by straight-line distance when location is available. Pagination ends at the last matching Pennsylvania record. Tapping a result opens offline station details with the catalog date. Use **Open in Apple Maps** for directions. The list requires a name and street address, so unnamed and unresolved records are omitted. Text search works offline and when location is denied.

### Source registry

- **Station locations:** [Geofabrik Pennsylvania OSM PBF](https://download.geofabrik.de/north-america/us/pennsylvania.html), [download endpoint](https://download.geofabrik.de/north-america/us/pennsylvania-latest.osm.pbf). Public bulk download, no API key or paid service. Geofabrik publishes updated extracts regularly. The app uses a bundled snapshot and makes no live requests. Refresh the asset to update the app.
- **Rights:** © OpenStreetMap contributors. [ODbL 1.0 and attribution](https://www.openstreetmap.org/copyright). The [derived database](assets/stations/pennsylvania.json) is available under ODbL 1.0. Include a public copy of that file under ODbL when distributing the app. The raw extract is not included in the repository.
- **Snapshot:** Source timestamp 2026-11-12 21:23:05 UTC, retrieved November 13, 2026. SHA-256 of input PBF is `28a1f47d47f2814ea545d99d72812a9a5048c0a79225841618b4848bc7e91bbf`. 3,871 records include source type and ID, name, brand, address, and coordinates. 1,615 have any mapped address component after filling or completing 19 addresses from the same extract. The importer accepts a unique address at the same mapped point (within 0.000003° on each axis) or inside a single-ring station footprint. Search shows 1,527 named records with a street address. Fuel POIs come from `amenity=fuel`, with explicitly private or prohibited access excluded. Areas use their outer ring bounding-box midpoint. Duplicate source IDs are rejected, but separate mapped objects may describe one physical site.
- **Certification:** Local records carry no TOP TIER status. The Stations header opens the [official Station Finder](https://stationfinder.toptiergas.com/) externally for address-level lookup. The link sends no search or location parameters. Per the [TOP TIER terms](https://www.toptiergas.com/terms-and-conditions/), obtain authorization for station data reuse and the pump decal before shipping badges. Match the exact site and fuel type against authorized records, with provenance and freshness. Prices and fuel grades are also unavailable.

To regenerate the catalog, download the extract from the source above, install `osmium==4.3.2` in a Python 3.13 environment, then run from `mobile/`:

```sh
python tool/build_station_catalog.py /path/to/pennsylvania-latest.osm.pbf assets/stations/pennsylvania.json
```

### PA DEP tank registration pilot

- Source: [PA DEP Active Storage Tanks GIS layer](https://gis.dep.pa.gov/depgisprd/rest/services/Assessments/AssessmentLayers/MapServer/21). The [PA DEP GIS portal](https://www.pa.gov/agencies/dep/data-and-tools/gis) provides public downloads and app reuse for published data. FuelIQ queried the public ArcGIS layer on November 13, 2026. This is a retrieval date.
- Sample: 25 searchable catalog locations across city, suburban, and small-town groups. Within each group, eligible stations were sorted by city and OSM ID, with a maximum of three per city. The match required one facility with the same normalized street address and city within 75 meters. Review found 6 of 9 urban, 4 of 8 suburban, and 3 of 8 small-town matches. The other 12 yielded no candidate meeting those rules. This convenience sample does not estimate statewide coverage.
- The [bundled pilot matches](assets/stations/pa_dep_pilot.json) store facility and site IDs by OSM ID. Details display the regulated facility name and link to the official GIS record. Tank registration describes the regulated facility. Inspection outcomes, fuel grades, and site-level TOP TIER status are unavailable in FuelIQ.
- The app reads the bundled snapshot offline. Only opening the source link requires connectivity. To verify on an iPhone, search for 3200 Airport Road in Allentown, open the result, and check that the official source shows facility 39-06707. Search for 1201 West Hamilton Street and check that tank registration shows **Unavailable**.

### Station logo sources

Local PNG thumbnails use the following Wikimedia Commons files, marked public domain for copyright on their source pages. Brand marks identify listed stations. Named stations without matching artwork use initials. Generic or unnamed listings use a fuel icon. BP uses the simplified text logo.

The local private build can load `bp-helios.png`, `getgo.png`, and `top-tier.png` from `assets/stations/logos/`. These files are git-ignored. The BP artwork comes from a [BP report](https://assets.publishing.service.gov.uk/media/5cecfc92ed915d247844b6e5/Schiehallion___Loyal_Phase_One_Close_Out_Report.pdf), GetGo from its [official site](https://www.getgocafe.com/), and the TOP TIER gasoline decal from the [official pump decal page](https://retailers.toptiergas.com/product/top-tier-pump-decals/). The decal identifies the official finder link. Amoco uses the [torch-and-oval artwork](https://seeklogo.com/vector-logo/429699/amoco) in a git-ignored private thumbnail.

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

Google ML Kit 8.0.0 excludes arm64 simulator builds. Use a physical iPhone to verify scanning with both readers. Build an unsigned device app with `flutter build ios --debug --no-codesign` or use Xcode with development signing to run on an iPhone.

Add a vehicle with a photo, log a partial fill-up, and compare Home spending with the receipt. Relaunch and verify the vehicle, photo, entry, and appearance persist. Edit the entry and verify the updated total, then delete it and verify the total clears. Try the photo picker with a PNG or JPEG in the simulator and with a real photo on an iPhone. Check VoiceOver and large text on both editors.

On an iPhone, take a vehicle photo in Garage and verify it persists after saving and relaunching. Try replacing it from Photos, canceling the replacement, and denying camera access. Scan a receipt and a completed pump display in Airplane Mode. Check the proposals against the images, including a receipt with non-fuel purchases and a pump with several octane buttons. Try scanning an unreadable photo and verify that manual entry and saving still work.


For Stations on iOS, set a simulated location in Pennsylvania. Open Stations, tap **Use my location**, grant permission, then check distance order and open a detail. Reset permission and repeat with denial. Verify text search still works, including in Airplane Mode. Try a location outside the pilot region.
