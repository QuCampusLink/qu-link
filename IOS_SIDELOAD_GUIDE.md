# iOS Tracker — Free Sideload Guide

Step-by-step instructions to build the student app on GitHub Actions and install it on your iPhone with Sideloadly (no paid Apple Developer account).

Sideloadly is a **Windows desktop app** — not on the iPhone App Store. You install the bus app onto the phone from your PC over USB.

## Step-by-step

### 1. Push the repo to GitHub

Public repo = unlimited free Action minutes. Private repo also works (limited minutes).

### 2. Run the build

1. GitHub → your repo → **Actions**
2. **iOS Tracker (unsigned, free sideload)** → **Run workflow**
3. Wait ~10–15 minutes
4. Open the finished run → **Artifacts** → download **qu-bus-tracker-ios** (`.ipa`)

### 3. Install Sideloadly on Windows

- Download: [sideloadly.io](https://sideloadly.io)
- Install [Apple Devices](https://apps.microsoft.com/detail/9np83d1rwd6d) (or iTunes) so your PC sees the iPhone

### 4. Install on iPhone

1. Connect iPhone via USB → Trust the computer
2. Open Sideloadly
3. Drag `qu-bus-tracker.ipa` in
4. Sign in with your free Apple ID (iCloud account)
5. If asked for 2FA, use an [app-specific password](https://appleid.apple.com)
6. Click **Start** → app appears on your home screen
7. **Unplug the phone** — you can use the app normally after install

### 5. Before recording

- On iPhone: **Settings → General → VPN & Device Management** → trust the developer profile
- Allow location when the app asks
- Run `npx convex deploy` so the app works without your laptop’s `convex dev`

### 6. Refresh weekly

When the app stops opening (~7 days), plug in the phone and sideload the same `.ipa` again in Sideloadly.
