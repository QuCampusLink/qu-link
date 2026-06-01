# Android APK — Build & Install Guide

Step-by-step instructions to build `.apk` files for the QU bus apps and install them on a real Android phone.

Both apps connect to Convex at `https://perfect-curlew-934.convex.cloud` (baked in at build time).

## What you need

- **Windows PC** with Flutter installed (`flutter doctor` should show no critical errors)
- **Android phone** (Android 6.0 / API 23 or newer)
- **USB cable** (recommended) or a way to copy the APK file to the phone (Google Drive, email, etc.)

---

## Part 1 — Prepare the phone

1. On the phone, open **Settings → About phone**.
2. Tap **Build number** 7 times to enable **Developer options**.
3. Go to **Settings → System → Developer options** (location may vary by brand).
4. Turn on **USB debugging**.
5. Connect the phone to your PC with USB.
6. On the phone, tap **Allow** when asked to trust the computer.

Optional: run `flutter devices` on your PC — your phone should appear in the list.

---

## Part 2 — Build the APK on your PC

Open PowerShell or Terminal in the repo folder:

`c:\Users\jaiaa\OneDrive\Desktop\stuff\bus\sexy-bus-app-for-qu`

### Student app (QU Bus Tracker)

```powershell
cd qu_bus_tracker
flutter pub get
flutter build apk --release --dart-define=CONVEX_URL=https://perfect-curlew-934.convex.cloud
```

**Output file:**

`qu_bus_tracker\build\app\outputs\flutter-apk\app-release.apk`

### Driver app (QU Bus Driver)

```powershell
cd qu_bus_driver
flutter pub get
flutter build apk --release --dart-define=CONVEX_URL=https://perfect-curlew-934.convex.cloud
```

**Output file:**

`qu_bus_driver\build\app\outputs\flutter-apk\app-release.apk`

> **Tip:** For quick testing only, you can use `--debug` instead of `--release` (faster build, larger file).

---

## Part 3 — Install the APK on the phone

Pick **one** method below.

### Method A — Install over USB (easiest if phone is plugged in)

Replace the path with the app you built.

**Tracker:**

```powershell
adb install -r "qu_bus_tracker\build\app\outputs\flutter-apk\app-release.apk"
```

**Driver:**

```powershell
adb install -r "qu_bus_driver\build\app\outputs\flutter-apk\app-release.apk"
```

The `-r` flag reinstalls if the app is already on the phone.

### Method B — Copy APK to the phone and open it

1. Copy `app-release.apk` to the phone (USB file transfer, Google Drive, WhatsApp, etc.).
2. On the phone, open **Files** / **Downloads** and tap the APK.
3. If Android blocks the install, go to **Settings → Security** (or **Install unknown apps**) and allow your file browser to install apps.
4. Tap **Install**.

---

## Part 4 — First launch

### Student app (Tracker)

1. Open **qu_bus_tracker** on the phone.
2. Allow **location** when prompted (needed for the map).
3. Pick gender, use the map, tap stops for schedules and live buses.

### Driver app (Driver)

1. Open **qu_bus_driver** on the phone.
2. Allow **location** — choose **While using the app** or **Allow all the time** for tracking.
3. Enter **driver name** and **bus ID**, pick a **route**, tap **Start Tracking**.
4. Confirm **GPS fix** and **Sent to students** show the same coordinates on the status card.

---

## Recommended setup for live bus testing

| Phone        | App    | Purpose                          |
|-------------|--------|----------------------------------|
| Android     | Driver | Broadcasts real GPS to Convex    |
| Android/iOS | Tracker | Shows 🚌 live bus on the map   |

Use a **real phone for the driver app** — emulators use fake GPS that often stays fixed at one campus point (e.g. Metro).

---

## Troubleshooting

| Problem | Fix |
|--------|-----|
| `flutter` not found | Install Flutter and add it to PATH: https://docs.flutter.dev/get-started/install |
| Phone not listed in `flutter devices` | Enable USB debugging; try another cable; install phone USB drivers |
| `adb` not found | Install [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) or use Android Studio |
| Install blocked | Enable “Install unknown apps” for your file manager or browser |
| App opens but no buses/schedules | Ensure Convex is deployed: `npx convex dev --once` from repo root |
| Driver location stuck in one place | Use a physical phone with GPS; move outdoors or wait for a GPS fix |

---

## Rebuild after code changes

After pulling new code from GitHub, rebuild the APK with the same `flutter build apk` commands above, then reinstall (Method A or B).
