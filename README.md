# FuelIQ

**Premium fuel intelligence, station research, and personal vehicle analytics.**

**Primary product:** Flutter mobile application, launching on **iOS first**. Android may follow later using the same Flutter codebase. This is not a React/web frontend project.

> Status: Flutter iOS foundation, offline Garage, and manual Fuel Log implemented. Station discovery and advanced analytics are upcoming milestones. Claims about external data availability, licensing, and API pricing must be verified before implementation.

## Vision

FuelIQ is an automotive research platform that helps drivers understand **what fuel they are buying, what can be verified about it, where it is sold, and what it costs them over time**. It combines trustworthy fuel science, station-level information, and a beautiful personal Garage. It is **not** primarily a cheap-gas locator or map application.

The product should feel like an established, meticulously refined premium automotive platform from its first release. Deliver elegance through consistency, speed, clarity, excellent data provenance, and thoughtful interactions rather than visual clutter.

## Core principles

1. **Evidence before claims.** Never fabricate fuel chemistry, detergent concentrations, contamination results, fuel deliveries, inspection outcomes, prices, or station amenities.
2. **Official integrations only.** Use documented APIs, explicitly authorized data feeds, and official bulk downloads. Respect provider terms, access controls, and rate limits.
3. **Station-specific vs. general data.** Clearly distinguish a brand's published claims, a region's sampled chemistry, a specific station's inspection, and a tested sample from a particular pump/date.
4. **Low recurring cost.** Favor free or low-cost legal sources and reusable local assets. Do not assume a commercial API or laboratory testing budget.
5. **No embedded map required.** Search and list stations using addresses, postal codes, coordinates, and cards. Mapping is a future option, not a launch dependency.
6. **Respect privacy.** EXIF coordinates, vehicle details, and receipts can be sensitive. Give users control and do not publish their location history.
7. **Premium quality throughout.** The UX, accessibility, tests, security, performance, and maintainability must match the visual polish.

## Platform and release priorities

- **Flutter + Dart** is the required client stack. Target iPhone/iOS for the initial release; design for future Android support without requiring Android implementation now.
- Follow Apple Human Interface Guidelines while establishing FuelIQ’s distinctive premium design system. Use native-feeling navigation, gestures, safe areas, accessibility, Dynamic Type, light/dark appearance, and refined motion.
- Photo import should use supported iOS photo picker/camera APIs through maintained Flutter packages, with least-privilege permissions. Users can select images without granting broad photo-library access when supported.
- Read image EXIF locally when practical, handle missing/stripped GPS and timestamps, and obtain explicit permission before accessing current device location. Do not require location access to log fuel.
- Secure sensitive tokens using platform secure storage (Keychain-backed on iOS), use HTTPS, and protect personal vehicle/location data.
- Build and validate on iOS simulator and, where available, a real iPhone. Document Xcode, CocoaPods/Swift Package Manager requirements as applicable, signing, and App Store privacy declarations.
- Backend remains independent of the client and exposes versioned APIs. Avoid platform-specific assumptions in domain models so Android can be added later.

## Primary experiences

### 1. Station search and intelligence

- Search by station name, fuel brand, address, ZIP/postal code, and proximity with user permission.
- Present premium station cards with reusable locally hosted brand logos, address, supported fuel grades when verified, and provenance/freshness indicators.
- Detail pages show station identity, known grades, available fuel research, inspection/compliance records where public, and links to official evidence.
- Resolve station identity from coordinates using spatial queries; when multiple nearby candidates exist, ask the user to confirm.
- Offer an external Apple Maps/Google Maps link if desired, without embedding a map.
- Station-specific photos via an appropriately licensed photo API or authorized uploads are optional later; do not permanently cache third-party photos unless license permits.

### 2. Fuel science and research

- Explain octane (AKI), ethanol blends, detergents, TOP TIER certification, sulfur, benzene, aromatics, olefins, vapor pressure, and other scientifically relevant measurements when supported by available evidence.
- Display manufacturer-reported fuel technologies separately from independently tested or government-reported measurements.
- Provide premium fuel intelligence reports for brands/products such as Shell V-Power, BP premium, Exxon Synergy, and Chevron Techron, with cited sources and dates.
- Show explicit labels such as **Verified measurement**, **Official inspection record**, **Manufacturer statement**, **Regional aggregate**, **Community report**, or **Unavailable**.
- Do not imply that TOP TIER certification proves the fuel from a specific station is uncontaminated, or that regional chemistry datasets prove a pump's composition.
- Optional future: verified fuel deliveries and tank turnover, operator-submitted data, and independently sampled contamination testing. No unsupported freshness or water-content estimates.

### 3. FuelIQ Garage

- A dedicated, visually rich **My Garage** area with multiple vehicle profiles, hero/thumbnail photos, make, model, year, trim, drivetrain, preferred/recommended fuel, and user-configurable details.
- Vehicle-specific dashboards and fuel histories, not mixed across vehicles.
- Optionally record odometer, lease mileage allowance, lease term, and personalized spending/usage forecasts.
- Handle vehicle photos securely, optimize uploads, and allow edits/deletion.

### 4. Smart Fill-Up Tracking

- Users upload a photo of a gas pump display, a receipt, or both.
- Extract EXIF capture time and GPS coordinates **if present**. EXIF generally contains coordinates, not a street address. Reverse-geocode coordinates only with an approved provider or locally maintained data, then match to nearby station records.
- OCR/vision extraction attempts: fuel grade (e.g., 93 AKI), price per gallon, total amount, gallons, date/time, and station/receipt address if printed.
- OCR values must be editable, carry confidence scores, and require user review before committing a record.
- Validate `gallons × price_per_gallon ≈ total` with appropriate rounding; flag inconsistencies rather than silently modifying them.
- Allow manual entry and location selection when photo metadata, OCR, or station lookup fails.
- Optionally record odometer, full/partial tank, payment notes, and fuel brand.
- Protect photo metadata, receipt details, and location data; define retention and deletion policies.

### 5. Personal analytics

- Year-to-date and all-time fuel spending, gallons, average price/gallon, fill-up count, trends, and month-by-month spending.
- Cost per mile and MPG when sufficient odometer and full-tank records exist; don't claim accurate MPG from arbitrary partial fill-ups.
- Spending by vehicle, station, brand, grade, and time period.
- Compare actual paid prices across brands and stations; annotate changes in MPG with caveats about driving, weather, traffic, and seasonal blends.
- Optional mileage/lease budget projections, downloadable CSV, and later PDF reporting.
- Show friendly empty states and demo data only when explicitly labeled as demo.

## Experience and design direction

The exact visual theme is undecided. Build a tokenized design system so dark futuristic and clean premium themes can be explored without rewriting screens. Aim for excellent typography, restrained motion, refined spacing, responsive layouts, accessible contrast, keyboard support, smooth loading states, helpful validation, and cohesive visual hierarchy. Avoid overly complex custom map pins or decorative code-driven marker drawing.

## Suggested initial architecture (subject to repo inspection)

- **Backend:** Python FastAPI, typed schemas, service layer, API versioning, OpenAPI documentation.
- **Database:** PostgreSQL with PostGIS for station proximity and spatial indexing; migrations via Alembic.
- **Mobile client:** Flutter + Dart, iOS-first, reusable widgets/design tokens, accessible native-feeling navigation, typed API client, state management chosen after repository inspection, and performant charting. No React frontend.
- **Jobs:** Scheduled official-source ingestion with provenance, caching, retries, and per-provider rate limits.
- **Files:** Secure image storage, size/type checks, EXIF parsing, image optimization, configurable retention.
- **Extraction:** Modular OCR/vision interface; favor local or cost-conscious extraction and human confirmation. Evaluate tools and accuracy before choosing.
- **Auth:** Secure sessions/identity, per-user authorization, private Garage and fill-up records.
- **Operations:** Environment-based configuration, structured logs, health checks, observability, backups, CI, tests, and deployment documentation.

Do not install expensive third-party services or add paid API dependencies without explicit approval. If an existing repository already uses a different sound stack, assess and preserve it where practical.

## Station discovery architecture

- Maintain FuelIQ's own station database and documented search and detail APIs. Use PostGIS for proximity. Support text, brand, and fuel filters where the licensed data allows.
- Use station cards, location search, and optional external directions.
- Source station locations and certification separately. Verify terms, coverage, and update methods before ingestion. A brand match alone cannot verify a station or fuel grade.
- Use brand assets and station photos only when the license permits the intended use. Require official evidence with explicit scope before publishing station-level chemistry, contamination, deliveries, or inspections.

## Source strategy

Research and document candidate official sources before integration:

- U.S. EPA public fuel datasets, publications, and fuel regulations (check granularity, format, availability, licensing, and update cadence).
- State environmental and underground storage tank program data, beginning with Pennsylvania DEP where relevant (verify whether datasets are downloadable, queryable, and actually station-specific).
- TOP TIER program public certification listings and licensing/usage conditions.
- OpenStreetMap-derived station data **only through permitted APIs, extracts, or licensed feeds**, with ODbL attribution and obligations evaluated.
- Official manufacturer fuel information and authorized brand asset sources.

For each source, maintain a registry of provider, endpoint/download URL, access method, terms, cost, quota, cadence, schema, coverage, source timestamp, retrieval timestamp, and allowed storage/reuse. **Do not claim a public real-time station-level water-contamination API exists unless independently verified.**

## Data model sketch

- `users`, `vehicles`, `vehicle_photos`
- `station_brands`, `stations`, `station_identifiers`, `station_fuel_grades`
- `fuel_products`, `fuel_specifications`, `fuel_claims`, `fuel_measurements`
- `data_sources`, `source_records`, `ingestion_runs`, `inspection_records`
- `fill_ups`, `fill_up_photos`, `extraction_attempts`

All evidence-backed entities should preserve source references, measurement scope, timestamps, confidence/quality labels, and update history. Store money and volumes using appropriate decimal precision, not floating-point currency math.

## Development phases

1. **Foundation:** inspect repository, choose stack, create design system, database schema, authentication strategy, migrations, CI, and architecture documentation.
2. **Garage + manual tracking:** vehicle profiles/photos, manual fill-ups, history, and initial spending dashboard.
3. **Smart photo logging:** EXIF, OCR, candidate station matching, validation, review flow, and privacy controls.
4. **Station intelligence:** official/authorized station datasets, text-first search, station cards and profiles, source registry and ingestion.
5. **Fuel science:** carefully sourced product reports, technical explanations, public inspection/chemistry datasets with proper scope labels.
6. **Advanced insights:** brand comparisons, MPG and cost/mile, exports, lease forecasts, optional operator data and future station imagery.

This sequence is a proposal, not a commitment to build everything at once. Prioritize vertical slices that work end-to-end.

## MVP acceptance criteria

- A user can add a vehicle with an optional photo and see it in My Garage.
- A user can manually record a fill-up and view accurate per-vehicle totals and history.
- A user can upload a pump/receipt photo, review extracted values, correct errors, and save it; failure paths are usable.
- Station search works without any map UI.
- Every external data claim is traceable to a source with an appropriate scope and freshness label.
- Production integrations use authorized sources. Scientific figures require evidence, and the MVP needs no paid services.
- The iOS Flutter app has accessible core workflows, and includes tests for calculations, authorization, extraction, and data provenance.

## Non-goals for initial release

Embedded maps, guaranteed live fuel prices, station-by-station proprietary detergent formulas, real-time underground tank delivery records, real-time water contamination readings, paid lab testing, or unlicensed photo caching.

## Initial station-data implementation direction

Start by verifying one permitted, reasonably complete source of station locations and one permitted certification source. Document actual licensing, download/API access, attribution, freshness, and limitations in the source registry before implementing ingestion. Then build the internal station schema, a small test fixture **explicitly labeled synthetic**, proximity search, and station card/detail screens. Do not represent test fixtures as real station listings. Keep the data-source adapters replaceable.

## Getting started

The iOS app lives in [`mobile/`](mobile/). See its [development guide](mobile/README.md) for toolchain, run, and verification steps. See [`AGENTS.md`](AGENTS.md) for project-wide instructions.

## MVP Functional Requirements and Acceptance Criteria

### Local Data Persistence
- Vehicle profiles, photos, and fill-up records must survive app restarts.
- Support complete CRUD operations for vehicles and fill-up records.
- Support multiple vehicles with one designated primary vehicle.
- The initial MVP must work without authentication or backend connectivity.
- Structure locally stored records for future backend synchronization.

### Fuel Logging and Calculations
- Associate every fill-up with a specific vehicle.
- Support full and partial tank entries.
- Validate price-per-gallon, gallons purchased, and total cost.
- Flag calculation discrepancies without silently changing user input.
- Calculate vehicle-specific and combined fuel statistics.
- Calculate cost per mile when sufficient odometer data exists.
- Calculate MPG only when sufficient valid full-tank records exist.
- Exclude incomplete or invalid records from affected calculations.
- Never substitute estimated values for missing measurements.

### Initial Navigation
The first runnable application must provide five destinations:
1. Home
2. Stations
3. Fuel Log
4. Garage
5. Settings

Navigation must work even when a feature has not yet been implemented.

### First Milestone Acceptance Criteria
The initial functional MVP is complete when:

1. The Flutter application launches successfully in an iOS simulator.
2. All five navigation destinations are accessible.
3. Users can create, edit, and delete vehicle profiles.
4. Vehicle photographs persist after restarting the application.
5. Users can create, edit, and delete fuel records.
6. Fuel history persists after restarting the application.
7. Spending analytics reflect actual saved records.
8. Input validation prevents invalid records from being saved.
9. Light and dark themes render without layout issues.
10. Flutter analysis and automated tests pass.
11. Core Garage and Fuel Log functionality works offline.

### Development Milestones
Implement and verify each milestone independently:

1. Flutter iOS foundation, navigation, and design system.
2. Functional Garage with persistent vehicle profiles.
3. Manual Fuel Log with persistent records.
4. Fuel analytics and dashboard integration.
5. Station discovery and fuel intelligence interfaces.
6. Authorized external data integrations.
7. Photo OCR, EXIF extraction, and station matching.
8. Advanced insights and release preparation.

Keep the application runnable between milestones.
Do not attempt all milestones in a single development pass.
