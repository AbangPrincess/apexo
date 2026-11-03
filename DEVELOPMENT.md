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
[x] P2 Record + feed + activity detail (+ owner requests: email verification, sign-in lockout, password reset, profile photos and achievements)
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
- P2: new passwords need 8+ characters with a letter and a number (live checklist on sign-up).
- P2: sign-up uses verify-after-create (the Firebase model): the account is created, a link is emailed, and the app stays on "Check your email" until it is verified. P6 Firestore rules must also require `request.auth.token.email_verified`. A code-by-email flow would need Cloud Functions (paid plan).
- P2: demo mode cannot send real email, so the demo backend keeps an outbox shown in a clearly labelled "Demo inbox". Links work once, a resend expires older links, and resends have a 60 s cooldown.
- P2: sign-in lockout lives in the backend (FakeAuth in demo; Firebase's own limits in P6, plus the same LoginThrottle client-side). 5 failures lock that email for 30 s, doubling up to 15 min. Unknown emails fail and lock the same way, and reset requests never reveal whether an email has an account.
- P2: profile photos are resized on the device (avatar 512 px, cover 1600 px), checked by their bytes (JPEG/PNG/WebP only, size caps), stripped of GPS EXIF tags, and stored as small data URIs on the profile. This works on the free Firebase plan, where Cloud Storage now needs the paid plan.
- P2: settings moved from the Me tab to a Settings screen (gear icon); Me is now a social-style profile with cover, photo, details, achievements, weekly chart and totals.
- P2: recording uses `package:clock` time so tests can fake it. The demo backend defaults to simulated GPS (switchable) so recording can be tried at a desk.
- P2: Android permissions for location, foreground service, wake lock and notifications are declared now (recording needs them); a short explanation dialog appears before the system permission request. Full rationale screens and the notification permission request remain in P6.
