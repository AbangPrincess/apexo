# PedalTrack - development notes
Activity tracking + live circles + theft guard for bikes, motorbikes and cars. Flutter (Dart). Full scope is in SPEC.md. Read only the sections you need: `grep -n '^## ' SPEC.md`.

## Working rules
- Read only files you will edit. Batch edits. Max 250 lines per file; split big widgets into their own files. Comment only non-obvious logic.
- Add packages with `flutter pub add <pkg>` (never hand-edit versions), and only in the phase that first uses them. No code generators (build_runner, freezed, json_serializable, riverpod_generator): hand-write models with fromMap/toMap.
- Verify with `flutter analyze` and `flutter test` (piped to `| tail -n 25`).
- Blocked on something only the owner can do (Firebase project, keys)? Use the demo backend, keep going, and list it under "Needs you" in README.md.
- Never commit passwords, keys, keystores or .env files. Never log or persist anything sensitive on the client (web localStorage and the console are visible in the browser's Inspect tools).
- Commits: short messages ("first commit", "second commit", ...), and only when the owner asks. Never push unasked.

## Conventions
- Material 3, provider + ChangeNotifier. Repository interfaces in lib/data with FakeRepository (demo, in-memory) and FirebaseRepository; pick by `DefaultFirebaseOptions.isConfigured` (placeholder lib/firebase_options.dart until `flutterfire configure`). Never add the google-services Gradle plugin by hand.
- Layout: lib/core (theme, geo, units, weather logic), lib/data, lib/features/{auth,feed,record,circle,guard,alerts,me}, lib/widgets. Pure logic in lib/core with tests in test/.
- Responsive and adaptive: phones (Android + iPhone) get the bottom bar; >= 600 px (tablets, web) get a side rail and width-capped content. Respect safe areas; use adaptive widgets (Switch.adaptive, showAdaptiveDialog) so iPhone feels native.
- Original UI and copy only. Do not copy other apps' names, logos or assets.

## Progress
[x] P1 Foundation + demo backend + app shell
[ ] P2 Record + feed + activity detail
[ ] P3 Weather
[ ] P4 Circles
[ ] P5 Vehicle guard + alerts
[ ] P6 Firebase + polish + GitHub deploy
[ ] P7 Optional extras (ONLY if the owner asks)

## Decisions
- iOS is scaffolded (`--platforms android,ios,web`) and every screen is designed for iPhone too; building and signing it needs a Mac with Xcode. This overrides "iOS is not configured" in SPEC G1/G6.
- Packages are added in the phase that first uses them (P1: provider, shared_preferences, flutter_map, latlong2) so Android builds never break on unused native plugins.
- lib/core uses its own `GeoPoint` (pure Dart); conversion to latlong2 happens only inside `MapView`.
- Tabs are built lazily (first visit), so the map and its tiles load only when Circle is opened.
- Units and default activity live on the user profile (synced) and are cached in shared_preferences so the UI starts with them. Only these two settings are stored locally; no email, password or location is persisted on the device.
- Demo mode is in-memory: new accounts and changes reset on reload. The demo password check never logs or persists anything.
- Demo alert: Jero's 50 m boundary is evaluated with `insideBoundary`; the alert fires after 2 consecutive outside fixes (~20 s after sign-in), once per session. Full re-arm logic arrives in P5.
- Demo invite code TRAIL7 is kept as specified even though it contains I and L; generated codes (P4) exclude look-alikes and joining normalizes case and spaces.
- Password minimum is 8 characters (Firebase only enforces 6).
