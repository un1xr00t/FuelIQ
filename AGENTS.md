# Codex Project Instructions: FuelIQ

**Mandatory platform decision: Build FuelIQ as a Flutter/Dart mobile application with iOS as the first release target. Do not scaffold React, Next.js, or another web frontend. Android support is a later possibility, not an MVP requirement.**

## Repository context boundaries

- `AGENTS.md` and `README.md` live at the repository root and remain there. Codex should read these two files for persistent project context.
- Scope searches to relevant project directories and named files. Exclude local third-party material from routine context gathering, indexing, searches, and implementation.
- Use third-party code, assets, and data only when their licenses or terms permit the intended use. Keep credentials and private responses out of the repository.

Read `README.md` before proposing or implementing changes. Treat it as the product vision and this file as the engineering operating contract. If an existing repository contradicts the suggested stack, inspect it first and explain tradeoffs rather than overwriting working code.

## Workflow

1. Inspect repository structure, dependencies, tests, and current implementation before coding.
2. Summarize the task, relevant existing behavior, assumptions, and a short implementation plan.
3. Work in small, coherent, end-to-end increments. Keep the app runnable.
4. Run relevant formatting, lint, type checks, and tests; report exact results and any checks not run.
5. Document configuration, migrations, API changes, source terms, and manual verification steps.
6. Do not assert a feature works without testing or clearly describing the remaining uncertainty.
7. Ask before introducing paid services, substantial architecture changes, or destructive operations.

## Non-negotiable external data rules

- **NO scraping** of HTML pages, browser automation for data extraction, WAF bypasses, CAPTCHA bypasses, or undocumented private API use in production.
- Use documented, officially supported APIs or expressly authorized downloadable datasets/feeds. Comply with licenses, attribution, quotas, caching, retention, and terms.
- Never hardcode fabricated station inspection outcomes, live contamination measurements, chemical concentrations, prices, delivery dates, or source citations.
- If a provider does not expose a needed fact, show **Unavailable** and describe the limitation.
- Distinguish station-specific measurements from brand claims, regional statistics, inspection records, and community submissions.
- Each integration needs a documented adapter, source registry entry, retries/backoff, timeout, rate limiting, schema validation, idempotent sync, and useful error logging.
- Do not claim that a government dataset is live or that an API exists until verified against official documentation.

## Flutter and iOS-first implementation requirements

- Use Flutter and Dart for the app UI; prioritize a polished iPhone experience and Apple Human Interface Guidelines without losing the FuelIQ visual identity.
- Keep presentation, state, domain models, API services, and persistence separated. Prefer reusable widgets and centralized design tokens; select maintained packages deliberately and document why.
- Use iOS-native-feeling navigation, safe areas, swipe/back behavior, appropriate haptics, Dynamic Type/text scaling, VoiceOver semantics, reduced motion, and light/dark support.
- Integrate photo selection/camera through supported Flutter plugins and iOS permission patterns. Request only necessary permissions and support missing EXIF or denied location access.
- Protect credentials with Keychain-backed secure storage; never place server secrets or privileged API credentials in the client binary.
- Run `dart format`, `flutter analyze`, and `flutter test` for applicable changes. Run an iOS simulator build when the required macOS/Xcode toolchain is available; explicitly report when it is not.
- Keep domain logic platform-neutral where possible to facilitate Android later, but do not spend MVP effort implementing Android-specific features.
- Do not introduce a web UI or embedded maps unless the user explicitly changes scope.

## Engineering standards

- Prefer maintainable, typed, modular code and clear separation of UI, domain, persistence, external adapters, and background jobs.
- Use database migrations and constraints. Store currency in decimal/integer minor units, not binary floats.
- Use UTC for stored timestamps with user-local presentation; preserve original photo capture time and timezone ambiguity.
- Store geographic coordinates precisely but privately; restrict access to personal location history.
- For fill-up arithmetic, use decimal precision and explicit unit conversions; test rounding and partial tank cases.
- Validate user inputs, uploaded file types/sizes, image decoding, EXIF parsing, and external API responses. Never trust OCR output without review.
- Enforce authorization server-side for every user-owned resource. Avoid leaking receipts, EXIF data, vehicle photos, or location history.
- Keep secrets in environment configuration or a secret manager. Never commit credentials or tokens.
- Provide graceful offline/error/empty states; avoid hard failures when an upstream data source is unavailable.
- Write unit tests for domain calculations and integration tests for persistence, permissions, and API contracts.

## UI and product quality

- Build a premium, coherent design system with tokens for typography, colors, spacing, radius, shadows, and motion.
- The exact visual theme is not yet decided. Do not assume a fixed dark-only or light-only identity.
- Use accessible components, semantic structure, keyboard navigation, focus states, reduced-motion support, and responsive layouts.
- Optimize perceived performance with appropriate caching, skeletons, image optimization, and loading feedback.
- Use locally hosted, properly licensed brand logos and fallbacks. Never assume Google Places photos can be permanently downloaded or rehosted.
- **No embedded map in the MVP.** Use text search, station cards, and coordinate-based backend queries. External map links are optional.
- Make Garage and fuel tracking visually compelling but not crowded; charts must use real user data or be explicitly labeled demo data.

## Smart photo fill-up rules

- Photos may lack GPS EXIF, have inaccurate coordinates, or omit relevant pump numbers. Never silently infer a station as certain.
- EXIF GPS is coordinates, not an address. Match to nearby stations using a documented location provider or an authorized local station database.
- OCR extraction must show editable proposed fields and confidence/uncertainty. Require confirmation before saving.
- Check price × gallons against total with configurable rounding tolerance. Flag discrepancies, don't quietly overwrite.
- Support manual entry, missing metadata, partial tanks, multiple vehicles, and duplicate detection.
- Define photo retention and deletion policies; default to minimizing personal data.

## Working with Codex

- When asked to begin implementation, start by identifying the smallest working vertical slice and the exact files to create/change.
- Prefer concrete changes and tests over lengthy speculative architecture essays.
- Preserve user changes; do not replace existing code or configuration without reviewing it.
- Maintain a concise changelog or progress notes and keep `README.md` updated as architecture and verified sources evolve.
- Flag external-source licensing, pricing, and availability questions for verification instead of guessing.

## Station discovery architecture

- Maintain FuelIQ's own station records and versioned search and detail endpoints. Use PostGIS proximity queries and station cards.
- Evaluate licensed station location and certification sources separately. Preserve certification provenance, effective dates, and station or product exceptions.
- Return supported, licensed data only. Show unavailable fields explicitly. Verify official sources before publishing station-level chemistry, contamination, delivery, or inspection data.

## Commit And Push Workflow

When the user asks to commit changes on `main`, complete the full local-to-remote workflow unless they explicitly say not to push:

- Stage only the intended files.
- Commit on `main` with a clear subject and a detailed body. Every commit in this repository must include a body, even for small changes. This requirement overrides any skill or convention that recommends a subject-only commit.
- Explain why the change was made, summarize the behavior or files changed, and record relevant verification and known limitations. Use bullets when they improve readability.
- Run `git push origin main`.
- Confirm the commit hash and push result.
- When summarizing a completed GitHub push back to the user, keep the write-up tightly spaced with no double spacing and clearly describe what was integrated or changed.
## Working Style

- Be direct and admit mistakes immediately.
- If a project-specific instruction conflicts with a generic habit, follow the project-specific instruction in `codex/Project Instructions/PROJECT_INSTRUCTIONS.md`.
- Treat the current chat scope as a hard boundary. If the user asks for a fix in one screen or feature area, do not expand into other screens, shared sweeps, or project-wide cleanup unless they explicitly ask for that broader pass.
- When the user asks to "update docs," "memory," or "agent files," prefer recording the workflow rule in repo instructions like this file instead of turning it into extra code changes.
- For UI tuning requests, make the smallest scoped change first, verify the result, and pause before broadening the work. Do not create follow-on cleanup work by proactively mass-fixing adjacent screens.

## Initial assignment

Inspect the repository. Report its current state and recommend a practical first vertical slice: Flutter iOS app shell, initial design system, backend database/migrations, My Garage vehicle profiles, and manual fill-up logging. Do not implement paid APIs, embedded maps, or scraping. Wait for a concrete implementation request if the user only asked for project documentation.
