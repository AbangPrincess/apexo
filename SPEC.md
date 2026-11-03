# Apexo - spec

## G1 Product
- Apexo = Strava-style activity tracking + Life360-style live circles + a theft guard for vehicles. Main users are cyclists (mountain, road, commute); motorcyclists and drivers can use it too. History: it started as an NDMU Android bike anti-theft GPS study; this is a new, more useful product, not a port of that app.
- Four pillars: (1) record and review activities, (2) live circles of people I chose, (3) vehicle guard with theft alerts to the circle, (4) weather for the ride.
- Android first (real background location). A Chrome web build is used for fast preview and a GitHub Pages demo (web cannot track in the background). iOS is not configured.
- Privacy non-negotiables: location is shared only inside circles the user joined after an explicit consent screen; a persistent indicator/notification shows while sharing; per-circle "Pause sharing"; leave a circle any time; no hidden tracking; the circle owner can remove a member; deleting the account deletes the data.

## G2 Stack
- Flutter stable, Dart null-safety, Material 3, provider.
- Map: flutter_map + OpenStreetMap tiles (no key, no billing). Wrap it in one `MapView` widget so Google Maps can replace it in P7 (needs the user's own key and a billing account).
- Location: geolocator (Android foreground-service notification for background updates). Notifications: flutter_local_notifications. Weather: Open-Meteo REST via http (no key). Share invite code: share_plus. Prefs: shared_preferences. "Navigate": url_launcher to https://www.google.com/maps/dir/?api=1&destination=LAT,LNG
- Backend (P6): Firebase Auth (email/password) + Cloud Firestore on the free Spark plan. NO Cloud Functions. The demo backend (FakeRepository) is the default until Firebase is configured.
- Geometry, units, stats and weather-verdict logic are pure Dart in lib/core and unit-tested.

## G3 Design (minimal but appealing)
White surfaces, #F4F4F5 secondary, 1 px #E4E5E8 hairline borders, no shadows or textures, 8-pt spacing grid, 16 px card radius. Brand palette (roles live in `lib/core/theme.dart`; screens use roles, never raw colors): Apex Red #E10600 = brand, START, selected tab, links, alerts/stop; Asphalt Black #121316 = text, primary buttons, selected chips, dark hero surfaces; Stealth Charcoal #2A2D33 = raised dark panels, snackbars, default cover; Carbon Fiber Gray #6B7079 = muted text, inactive, parked/paused; Hyper Orange #FF6A13 = the rider's data (routes, charts, progress) and caution; Volt Yellow #D4FF00 = live/go (moving, recording, Resume, Great verdict, earned badges), always paired with ink. Small text is never orange or volt on white. While recording, Record becomes a dark cockpit. Big numeric stats with tabular figures, one idea per screen, thumb-reachable actions, 48 px touch targets, subtle 150-200 ms transitions. Bottom nav, 5 items: Home, Circle, Record (center, prominent), Alerts, Me. Friendly, actionable empty states. Route thumbnails are painted with CustomPainter (no tile downloads). Light theme first, dark theme in P6.

## G4 Data model (Firestore; FakeRepository mirrors it exactly)
- users/{uid}: displayName, email, defaultActivity ('cycling'|'motorcycling'|'driving'), units ('km'|'mi'), createdAt
- users/{uid}/vehicles/{vid}: type ('bike'|'motorbike'|'car'), name, status ('ok'|'guarding'|'stolen'), boundary{lat,lng,radiusM}, armedAt
- users/{uid}/activities/{aid}: type, title, startedAt, endedAt, distanceM, movingSec, avgKmh, maxKmh, elevGainM?, path (encoded polyline, points >=10 m apart), weather{tempC,windKmh,code}, visibility ('private'|'circles'), vehicleId?
- circles/{cid}: name, inviteCode (6 chars, no look-alike characters), ownerUid, memberUids[], createdAt
- circles/{cid}/members/{uid}: displayName, lat, lng, speedKmh, heading, battery, status ('tracking'|'parked'|'alert'|'paused'), sharing, ts, vehicle{type,name,status}
- circles/{cid}/feed/{aid}: summary of an activity shared to the circle (owner, title, type, stats, simplified path, ts)
- circles/{cid}/alerts/{id}: type ('geofence'|'motion'|'lowbattery'|'sos'), ownerUid, vehicleName, message, lat, lng, distanceM, ts, ackBy[]
- Rules (P6): users/* only the owner; circle docs readable by memberUids; joining lets a signed-in user arrayUnion only their own uid; members/{uid} writable only by that uid; alerts creatable by any member and readable by members; validate field types.
- Write budget (Spark = 20k writes/day): while moving write at most every 5 s and only after >=10 m; stationary heartbeat every 60 s; at most 3 circles per user.

## P1 Foundation + demo backend + app shell
- Scaffold (`flutter create --org io.github.abangprincess --project-name apexo --platforms android,web .`), add packages, folder layout, theme, bottom-nav shell with 5 styled screens and friendly empty states, Me > settings (units, default activity).
- Repository interfaces + FakeRepository seeded with: demo user "You", circle "Trail Buddies" (code TRAIL7), member Jero (rides a scripted loop around Koronadal City, 6.50, 124.85, and leaves his 50 m boundary after ~20 s so an alert fires), member Shane (parked), and 6 sample activities across cycling/motorcycling/driving. Everything must run with zero setup.
- Auth screens: "Continue with demo account", plus email/password sign in and create account wired to the repository.
- Pure libs + tests: haversine, path length, insideBoundary(lat,lng,boundary,accuracy), polyline encode/decode, path simplification (>=10 m), km/mi conversion, avg/max speed with GPS-jump filter.
- Goal of this phase: I press F5 in VS Code, choose Chrome, and SEE the whole app moving with demo data.

## P2 Record + feed + activity detail
- Record screen: activity chips (Cycling, Motorcycling, Driving), big START, live big stats (time, distance, speed, avg speed), PAUSE/RESUME, FINISH. The finish sheet edits the title (auto "Morning Ride" style), visibility (Private/Circles) and Save/Discard. Auto-pause below 1 km/h (bike) or 3 km/h (motorbike/car) for 10 s.
- Location stream via geolocator: high accuracy, distanceFilter 5 m, drop fixes with accuracy >30 m or implied speed above the per-type cap (bike 20 m/s, motorbike 60 m/s, car 70 m/s). Android foreground notification "Recording ride" while active.
- Home feed (Strava-style): weekly totals header (distance, time, count), activity cards (type icon, title, relative date, painted route thumbnail, distance/time/avg speed), pull to refresh. Tap a card for Activity detail: flutter_map with the route polyline and start/end markers, stat grid, weather at start, delete.
- Me tab: profile, weekly bar chart (custom painted), totals per activity type.

## P3 Weather
- Open-Meteo: https://api.open-meteo.com/v1/forecast?latitude=LAT&longitude=LON&current=temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,precipitation_probability,wind_speed_10m,weather_code&forecast_days=2&timezone=auto (confirm the response shape with one truncated `curl`).
- Weather card on Home and Record: temperature, feels-like, wind speed with a direction arrow, an hourly strip for the next 6 h with rain chance, and a plain-language ride call from the pure function `rideVerdict(activityType, weather)` returning Great / OK / Caution / Avoid plus a reason (e.g. "Strong wind - expect a tough push", "Rain likely in 2 h"). Thresholds: wind >30 km/h caution, >45 avoid; rain probability >50 % caution, >75 % avoid; temperature <5 or >36 C caution. Add a "Best time to ride" hint (best hour in the next 12 h).
- Cache 15 minutes; offline shows the last result with "updated X min ago". Save a weather snapshot in each new activity. Unit-test rideVerdict.

## P4 Circles
- Circle tab: map with member pins = round initial avatar with a status ring (green tracking, red alert, gray parked/paused) and a small vehicle badge; draggable bottom sheet listing members (name, status, last update, battery, speed), tap to focus; locate-me button.
- Create circle (name, then a 6-character invite code with Share via share_plus), Join (enter code, then the consent screen, then joined), Members screen (pause sharing toggle, leave circle, owner can remove a member).
- Live sharing: while "Share my location" is on, publish my member doc within the write budget and show a persistent indicator. In demo mode, animate Jero and Shane.
- Activities saved with visibility "Circles" appear in members' Home feeds with the owner's name.

## P5 Vehicle guard + alerts
- Vehicles: add/edit (type, name) and choose the active one.
- Guard mode (meant for the phone left on the vehicle): ARM sets the boundary to the current location, default radius 50 m (slider 20-500 m), draws the circle on the map, shows the foreground notification "Guard mode on", sends a heartbeat every 60 s with battery. Evaluate the geofence on every fix: alert only after 2 consecutive fixes outside radius + accuracy, once per exit, re-arm after re-entry (prevents GPS-jitter false alarms). Optional accelerometer nudge detection (sensors_plus) with a sensitivity setting. Low-battery alert at 15 %.
- On alert: write circles/*/alerts, set the vehicle to 'stolen' and the member ring to red. Every other member's app shows a dialog plus a local notification and sound: "<Name>'s <vehicle> is on the move" with "Moved N m from its boundary (limit R m)", buttons View on map, Navigate, and "It's me" (acknowledge). The owner can "Mark recovered".
- Alerts tab: chronological list with filters (All/Mine/Circle, type, date); tap to open on the map.

## P6 Firebase + polish + GitHub deploy
- FirebaseRepository (Auth, Firestore with offline persistence), firestore.rules, firestore.indexes.json if needed. README "Needs you" steps: create the Firebase project, enable Email/Password, create Firestore, `dart pub global activate flutterfire_cli`, `flutterfire configure`, publish the rules.
- Android: manifest permissions (fine + coarse location, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS; background location only if truly needed), rationale screens that explain why before each permission request, app name and placeholder icon.
- Dark theme, accessibility (labels, contrast, text scaling), error and offline states, 3-slide onboarding.
- GitHub: .gitignore, MIT LICENSE, README (run in VS Code: F5 > Chrome for the demo, USB Android phone for the real thing), and .github/workflows/pages.yml that builds `flutter build web --base-href "/<repo>/"` and deploys to GitHub Pages in demo mode.

## P7 Optional extras (ONLY if I ask)
Google Maps swap behind MapView (my key + billing), FCM push while the app is closed (needs a Cloud Function and the paid Blaze plan), elevation gain via the Open-Meteo elevation API, kudos/comments, iOS.

## G5 Quality bar
Smooth lists and maps (const widgets, small rebuild scopes), battery-friendly location (distance filter, slower when stationary), no secrets in the repo, `flutter analyze` with 0 issues, tests green.

## G6 Known limits (list in README)
Web has no background tracking. Push while the app is fully closed needs the paid Firebase plan. OSM public tiles are fine for development and demos but need a tile provider for production. GPS is weaker under tree cover. Android 14 foreground-service rules apply. No iOS build.
