# PedalTrack

Ride tracking, live circles and theft alerts for bikes, motorbikes and cars. Built with Flutter for Android, iPhone and the web.

- **Record** rides, commutes and drives and review them later.
- **Circle**: see the people you chose on a live map. Sharing only starts after you agree to it.
- **Guard**: if a parked vehicle leaves its boundary, everyone in the circle gets an alert.
- **Weather**: a quick go/no-go call before you head out.

## Run it (no setup needed)

1. Install Flutter and the VS Code "Flutter" extension, then run `flutter doctor`.
2. Open this folder in VS Code and press **F5**. The "PedalTrack (Chrome)" launch option opens the app in Chrome.
3. Tap **Continue with demo account**.

What the demo shows:
- **Home**: 6 sample activities (cycling, motorcycling, driving) around Koronadal City.
- **Circle**: "Trail Buddies" (invite code `TRAIL7`) with Jero and Shane on the map. Jero starts riding a loop.
- About 20 s after you sign in, Jero's bike leaves its 50 m boundary. An alert appears, his ring turns red and the Alerts tab gets a badge.
- **Me**: switch between km and miles and choose your default activity.
- **Create account** shows what a new user sees: friendly empty states on every tab.

The phone layout uses a bottom bar with a center Record button. Tablets and desktop browsers get a side rail with content capped at a readable width. On iPhone, the app follows safe areas and uses native-style dialogs and page transitions.

To check the code:

```bash
flutter analyze
```

```bash
flutter test
```

## Needs you

Nothing yet. The app runs on a built-in demo backend. Firebase setup steps will be added here in phase 6.

## Known limits

- The web version can't track in the background.
- Push notifications while the app is fully closed need the paid Firebase plan.
- The public OpenStreetMap tiles are fine for development and demos. Production needs a tile provider.
- GPS is weaker under tree cover.
- Android 14 foreground-service rules apply.
- iPhone builds need a Mac with Xcode. The iOS project is included, and every screen is designed for iPhone.
- Demo mode keeps everything in memory, so it resets when you reload.

## Assumptions

- Units and default activity are saved to your profile. These two values are the only things cached on the device. Email, password and location are never stored in browser storage.
- Passwords need at least 8 characters.
- Packages are added in the phase that first uses them.
- Tabs load the first time you open them, so map tiles download only when you open Circle.

The full decision log is in [DEVELOPMENT.md](DEVELOPMENT.md). The product spec is in [SPEC.md](SPEC.md).
