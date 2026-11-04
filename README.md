# Apexo

Ride tracking, live circles and theft alerts for bikes, motorbikes and cars. Built with Flutter for Android, iPhone and the web.

- **Record** rides, commutes and drives and review them later.
- **Circle**: see the people you chose on a live map. Sharing only starts after you agree to it.
- **Guard**: if a parked vehicle leaves its boundary, everyone in the circle gets an alert.
- **Weather**: a quick go/no-go call before you head out.

## Run it (no setup needed)

1. Install Flutter and the VS Code "Flutter" extension, then run `flutter doctor`.
2. Open this folder in VS Code and press **F5** with **Apexo demo (Chrome)** selected. The app opens in Chrome on the built-in demo backend.
3. Tap **Continue with demo account**.

For the real thing, plug in an Android phone with USB debugging on and run **Apexo (phone over USB)**. It uses Firebase once you have done the steps under "Needs you" (until then it runs the demo too). **Apexo (Chrome)** does the same in the browser.

The public demo is published to GitHub Pages on every push to `main` (`.github/workflows/pages.yml`). It always runs the demo backend.

What the demo shows:
- **Home**: a weather card (temperature, feels-like, wind and its direction, the next 6 hours with rain chance), a Great / OK / Caution / Avoid ride call with the reason, and the best time to ride in the next 12 hours. Below it are this week's totals and 6 sample activities around Koronadal City, each with its route drawn. Pull down to refresh. Tap an activity to see it on a map with all its stats, or delete it.
- **Record**: pick Cycling, Motorcycling or Driving, check the ride call for that activity, and press START. In the demo, simulated GPS rides a loop so you can try it at your desk (switch it off to use real GPS). The time, distance and speed update live. The ride auto-pauses when you stop. Finish to name it, choose who sees it, and save. The weather at the start is saved with it.
- **Circle**: "Trail Buddies" (invite code `TRAIL7`) with Jero and Shane riding on the map. Drag the member sheet up or down and tap a member to focus them. The locate button finds you. Turn on **Share my location** to show yourself to the circle. A "Sharing live" bar then stays on every tab until you pause. About 20 s after you sign in, Jero's bike leaves its 50 m boundary. A dialog pops up ("Jero's Blue MTB is on the move", how far it moved and the limit) with **View on map**, **Navigate** and **It's me**. His ring turns red, a red pin marks the bike's last spot (it follows the bike) and the Alerts tab gets a badge.
- **Guard mode**: the shield icon in Circle (or Vehicles on Me) opens it. Pick the alert distance (20-500 m), optionally turn on movement detection, and press **ARM GUARD**. The boundary is set where the phone is and drawn on the map. A "Guard mode on" bar stays on every tab. In the demo, **Test the alarm** carries the bike out of its boundary, so you can see the whole flow, then **Mark recovered**.
- **Alerts**: everything from all your circles, newest first. Filter by All / Mine / This circle, by type and by date. Tap a theft alert to see it on the map. "Get alerts as notifications" turns on system notifications with sound.
- **Vehicles**: add or edit your bike, motorbike or car and choose the active one. It shows on your pin and is the one guard mode protects.
- **Circles**: tap the circle name to switch circles, create one (you get a 6-character code to share) or join with a code. Joining always shows a consent screen first, where you choose to share or start paused. The people icon opens Members, where you can pause sharing, leave, or (as owner) remove someone. You can be in up to 3 circles. To try joining, create a new account and enter `TRAIL7`.
- **Shared rides**: activities saved as "Circles" appear on members' Home feeds with the rider's name. Jero's and Shane's rides already show on yours.
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

- **Firebase** (real accounts, emails and syncing). The code is ready; it needs your Google account:
  1. In the [Firebase console](https://console.firebase.google.com), create a project (the free Spark plan is enough; Google Analytics is optional).
  2. **Authentication > Sign-in method**: turn on **Email/Password**.
  3. **Firestore Database > Create database**: pick a location near your users and start in **production mode**.
  4. **Firestore Database > Rules**: replace everything with the contents of [`firestore.rules`](firestore.rules) and press **Publish**. (Or run `firebase deploy --only firestore:rules --project YOUR_PROJECT_ID`.)
  5. In this folder, run these one at a time:
     ```bash
     dart pub global activate flutterfire_cli
     firebase login
     flutterfire configure --platforms=android,ios,web --no-apply-gradle-plugins
     ```
     Pick the project you made. It rewrites `lib/firebase_options.dart`. (If your FlutterFire version doesn't know `--no-apply-gradle-plugins`, run it without that flag.)
  6. Keep the real options out of Git (the values are not passwords, but a public repo doesn't need them):
     ```bash
     git update-index --skip-worktree lib/firebase_options.dart
     ```
  7. Run **Apexo (phone over USB)** and create an account. The verification email comes from Firebase (check spam the first time).
- **GitHub Pages**: on GitHub, open **Settings > Pages** and set **Source** to **GitHub Actions**. The next push publishes the demo at `https://abangprincess.github.io/apexo/`. (Pages on a private repository needs a paid GitHub plan.)
- **iPhone**: building needs a Mac with Xcode. The location and photo permission texts are already in place. Push notifications on iPhone also need an Apple Developer account.

## Known limits

- The web version can't track in the background. Keep the tab open while recording.
- Push notifications while the app is fully closed need the paid Firebase plan. Alerts reach you while Apexo is open or running in the background (for example while sharing or guarding).
- Guard mode watches the vehicle only while Apexo runs on the phone left with it. If the phone or app is closed, guard mode stays "on" but nothing watches, and the Guard screen says so. On the web it stops when the tab closes.
- Movement detection needs a phone accelerometer. Desktop browsers don't have one.
- Web notifications need browser permission and are not available in every browser.
- The public OpenStreetMap tiles are fine for development and demos. Production needs a tile provider.
- GPS is weaker under tree cover.
- Android 14 foreground-service rules apply. Android shows a "Recording ride" notification while recording and a "Sharing location" notification while sharing.
- Live sharing runs while the app is open (or recording). On the web it stops when the tab closes. Members see your last update with its age.
- Battery level comes from the device. Some browsers can't report it, so your circle sees the last known value.
- Demo mode keeps everything in memory, so it resets when you reload.
- On the web, the real backend keeps nothing on disk: no offline copy of the data, and you are signed out when the tab closes. The phone apps keep an offline copy and stay signed in.
- The free Firebase plan allows 20,000 writes and 50,000 reads a day. Live sharing is limited to one write every 5 s while moving, so a few friends are fine. Many daily users would need the Blaze plan.
- Weather needs an internet connection. It refreshes every 15 minutes. Offline, it keeps showing the last result with its age until the app restarts.

## Assumptions

- Units and default activity are saved to your profile. These two values are the only things cached on the device. Email, password, photos and location are never stored in browser storage.
- Profile photos are stored as small images on the profile itself, so they work on the free Firebase plan.
- Packages are added in the phase that first uses them.
- Tabs load the first time you open them, so map tiles download only when you open Circle.
- Live location goes only to circles you joined through the consent screen, at most every 5 s while moving (after 10 m) and once a minute when still. Pausing also hides your last position. Nothing about your location is stored on the device.
- Weather is for your location only if you have already allowed location access, sent rounded to about 1 km. Otherwise (and in the demo) it is for Koronadal City. Weather is kept in memory only.

The full decision log is in [DEVELOPMENT.md](DEVELOPMENT.md). The product spec is in [SPEC.md](SPEC.md).
