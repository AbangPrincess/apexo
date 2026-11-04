# Apexo - development notes
Activity tracking + live circles + theft guard for bikes, motorbikes and cars. Flutter (Dart). Full scope is in SPEC.md. Read only the sections you need: `grep -n '^## ' SPEC.md`.

## Working rules
- Read only files you will edit. Batch edits. Max 250 lines per file; split big widgets into their own files. Comment only non-obvious logic.
- Add packages with `flutter pub add <pkg>` (never hand-edit versions), and only in the phase that first uses them. No code generators (build_runner, freezed, json_serializable, riverpod_generator): hand-write models with fromMap/toMap.
- Verify with `flutter analyze` and `flutter test` (piped to `| tail -n 25`).
- Format only the files you touched, at 100 columns: `dart format -l 100 <files>`. The default 80 columns reflows the whole codebase.
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
[x] P3 Weather
[x] P4 Circles
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
- P3: weather comes from Open-Meteo through `OpenMeteoSource` (injectable `http.Client`; tests pass a fake `WeatherSource`). `current` and `hourly` also ask for `is_day`, so night hours rank lower and riders get a lights reminder after dark.
- P3: hourly times are parsed as UTC instants using `utc_offset_seconds`; labels use the forecast location's clock, not the device's.
- P3: `rideVerdict` uses the spec thresholds for cycling and motorcycling, plus thunderstorms (avoid) and rain falling now (caution). Driving is capped at Caution, and heat is ignored for driving. The worst factor sets the verdict and its reason.
- P3: "Best time to ride" ranks the next 12 h by verdict, then a discomfort score (rain, wind, heat, night), then earliest.
- P3: the 15-minute cache is in memory only; nothing about weather or location reaches shared_preferences or localStorage. Offline keeps the last result ("Offline · Updated X min ago"); a cold start offline shows a Retry card.
- P3: weather uses the device position only when location access is already granted (it never asks for it) and sends it rounded to 0.01 deg; demo mode and denied access use Koronadal City (6.50, 124.85).
- P3: each new activity stores a `WeatherSnapshot` for its start: current values when fetched within 30 min of the start, else that hour's forecast. Starting a recording refreshes a stale cache.
- P3: on Record, the weather call replaces the all-zero stats card before a ride (live stats still appear once recording starts), so START stays within thumb reach. Screens under 900 px tall fold the hourly strip behind an "Hourly" toggle.
- Rename: the app was renamed from PedalTrack to Apexo (2026-11-03). Dart package `apexo`, Android `applicationId`/namespace and iOS bundle ID `io.github.abangprincess.apexo` (a namespace the owner controls; it is permanent once published to a store, so change it before the first release if a domain is bought). Demo email is `demo@example.com` (reserved domain).
- Colors: the six Apexo brand colors are in `Palette`; screens only use the roles in `AppColors` (see SPEC G3 and README "Design"). Red is reserved for brand, START and alerts; primary buttons are ink; input focus is ink so it never looks like an error. `AppColors.on(color)` picks ink or white text for solid fills.
- P4: circle operations live in `FakeCircles` (lib/data/fake/fake_circles.dart), written like the P6 Firestore client: a user writes only their own uid and member doc; the owner may also remove members. Limit: `maxCirclesPerUser` = 3, enforced in the backend and checked in the UI.
- P4: invite codes use `inviteAlphabet` (no 0/O/1/I/L) from `Random.secure()` and are retried until unique. P6 needs an `inviteCodes/{code}` lookup doc readable by signed-in users, because circle docs are readable only by members. P6 should also rate-limit lookups.
- P4: joining and creating always pass the consent screen. Both choices complete the action; only "share" turns sharing on. If location access is refused, the circle is still joined, with sharing paused.
- P4: one sharing switch per circle (the member doc's `sharing` field, synced). The device location stream runs while any circle is shared. While recording, the recording's fixes are reused, so only one GPS stream runs. Demo (simulated GPS) shares a parked spot until a recording starts.
- P4: `ShareGate` enforces the G4 write budget: at most one write per 5 s, only after 10 m, plus a 60 s heartbeat when still. A status change skips the distance check but not the 5 s floor.
- P4: pausing writes position 0,0 so members cannot read where you paused. `Member.onMap` (sharing and a real position) decides who gets a pin. A new member has no pin until their first fix.
- P4: a persistent "Sharing live" bar shows on every tab while sharing; Android also shows the geolocator "Sharing location" foreground notification. The sharing state is not persisted on the device; it comes back from the member docs at sign-in.
- P4: the owner leaving passes ownership to the next member; the last member leaving deletes the circle and its members, alerts and feed.
- P4: "Circles" activities are copied to `circles/{cid}/feed/{aid}` in every circle of the owner (client fan-out, no Cloud Functions). The copy drops the vehicle link and thins the path to 25 m. Joining backfills your 20 latest; leaving or removal deletes your entries. Others' activities open read-only (no delete).
- P4: packages share_plus (invite sharing; copies to the clipboard where sharing fails) and battery_plus (member battery; null where unsupported).
- P4: create/join flows clear any open snackbar so it never covers their buttons; consent buttons are pinned at the bottom (thumb reach on small phones).
