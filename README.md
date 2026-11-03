# Apexo

Ride tracking, live circles and theft alerts for bikes, motorbikes and cars. Built with Flutter for Android, iPhone and the web.

- **Record** rides, commutes and drives and review them later.
- **Circle**: see the people you chose on a live map. Sharing only starts after you agree to it.
- **Guard**: if a parked vehicle leaves its boundary, everyone in the circle gets an alert.
- **Weather**: a quick go/no-go call before you head out.

## Run it (no setup needed)

1. Install Flutter and the VS Code "Flutter" extension, then run `flutter doctor`.
2. Open this folder in VS Code and press **F5**. The "Apexo (Chrome)" launch option opens the app in Chrome.
3. Tap **Continue with demo account**.

What the demo shows:
- **Home**: a weather card (temperature, feels-like, wind and its direction, the next 6 hours with rain chance), a Great / OK / Caution / Avoid ride call with the reason, and the best time to ride in the next 12 hours. Below it are this week's totals and 6 sample activities around Koronadal City, each with its route drawn. Pull down to refresh. Tap an activity to see it on a map with all its stats, or delete it.
- **Record**: pick Cycling, Motorcycling or Driving, check the ride call for that activity, and press START. In the demo, simulated GPS rides a loop so you can try it at your desk (switch it off to use real GPS). The time, distance and speed update live. The ride auto-pauses when you stop. Finish to name it, choose who sees it, and save. The weather at the start is saved with it.
- **Circle**: "Trail Buddies" (invite code `TRAIL7`) with Jero and Shane on the map. About 20 s after you sign in, Jero's bike leaves its 50 m boundary. An alert appears, his ring turns red and the Alerts tab gets a badge.
- **Me**: a profile with a cover photo, profile photo, bio and hometown, achievements for distance milestones and more, a weekly chart, and totals per activity type. The gear icon opens Settings (units, default activity, sign out).
- **Create account**: you get a verification email before the account opens. In demo mode, emails appear in a "Demo inbox" because nothing is really sent.

The phone layout uses a bottom bar with a center Record button that turns green while recording. Tablets and desktop browsers get a side rail with content capped at a readable width. On iPhone, the app follows safe areas and uses native-style dialogs and page transitions.

## Account security

- New accounts must verify their email before they can use the app.
- Five wrong passwords lock that email for 30 seconds. Each further lock doubles, up to 15 minutes. Unknown emails are treated the same way, so the form never reveals who has an account.
- Forgot password sends a reset link. Opening it also lifts any lock.
- Verification and reset emails can be re-sent once a minute, and a new link replaces the old one.
- New passwords need at least 8 characters, with a letter and a number.
- Location data (GPS tags) is removed from photos before they are saved.

To check the code:

```bash
flutter analyze
```

```bash
flutter test
```

## Design

| Color | Role |
|---|---|
| Apex Red `#E10600` | Brand: logo, START, selected tab, links. Also alerts and stop actions |
| Asphalt Black `#121316` | Text, primary buttons, selected chips, dark hero cards |
| Stealth Charcoal `#2A2D33` | Raised dark panels, snackbars, the default profile cover |
| Carbon Fiber Gray `#6B7079` | Secondary text, inactive icons, parked or paused |
| Hyper Orange `#FF6A13` | Your data (routes, charts, progress) and caution |
| Volt Yellow `#D4FF00` | Live and go: moving members, recording, Resume, "Great" ride call, earned badges |

Each color keeps one meaning on every screen. Volt and orange always sit on dark surfaces or next to black text, so they stay readable. While you record, the Record tab switches to a dark cockpit, which is easier to read in sunlight and uses less battery on OLED phones.

## Needs you

- **Real emails** (verification and password reset) need the Firebase backend, which comes in phase 6. Until then, demo emails show in the in-app Demo inbox.
- **iPhone**: building needs a Mac with Xcode. The location and photo permission texts are already in place.

## Known limits

- The web version can't track in the background. Keep the tab open while recording.
- Push notifications while the app is fully closed need the paid Firebase plan.
- The public OpenStreetMap tiles are fine for development and demos. Production needs a tile provider.
- GPS is weaker under tree cover.
- Android 14 foreground-service rules apply. Android shows a "Recording ride" notification while recording.
- Demo mode keeps everything in memory, so it resets when you reload.
- Weather needs an internet connection. It refreshes every 15 minutes. Offline, it keeps showing the last result with its age until the app restarts.

## Assumptions

- Units and default activity are saved to your profile. These two values are the only things cached on the device. Email, password, photos and location are never stored in browser storage.
- Profile photos are stored as small images on the profile itself, so they work on the free Firebase plan.
- Packages are added in the phase that first uses them.
- Tabs load the first time you open them, so map tiles download only when you open Circle.
- Weather is for your location only if you have already allowed location access, sent rounded to about 1 km. Otherwise (and in the demo) it is for Koronadal City. Weather is kept in memory only.

The full decision log is in [DEVELOPMENT.md](DEVELOPMENT.md). The product spec is in [SPEC.md](SPEC.md).
