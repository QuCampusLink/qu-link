# Convex — Setup Guide

How to set up and deploy the Convex backend for the QU bus apps (live GPS + stop schedules).

Both Flutter apps talk to Convex over HTTP. The deployment URL is passed at **build time** with `--dart-define=CONVEX_URL=...`.

**Shared team deployment (default in code):** `https://perfect-curlew-934.convex.cloud`

---

## What you need

- **Node.js 18+** and **npm** — [nodejs.org](https://nodejs.org)
- A **Convex account** — free at [convex.dev](https://convex.dev)
- This repo cloned locally

---

## Part 1 — Install backend dependencies

Open PowerShell or Terminal in the repo root:

`c:\Users\jaiaa\OneDrive\Desktop\stuff\bus\sexy-bus-app-for-qu`

```powershell
npm install
```

This installs the `convex` CLI and TypeScript tooling used by the `convex/` folder.

---

## Part 2 — Log in to Convex

```powershell
npx convex login
```

Follow the browser prompt to authenticate. You only need to do this once per machine.

---

## Part 3 — Link a deployment

Pick **one** path below.

### Option A — Use the existing team deployment (easiest)

If you already have access to the shared project, link your checkout to it:

```powershell
npx convex dev --once
```

When prompted, select the existing deployment (e.g. `perfect-curlew-934`).

Convex writes a local `.env.local` file (gitignored) with:

- `CONVEX_DEPLOYMENT` — internal deployment name
- `CONVEX_URL` — public URL the apps use

> **Note:** `.env.local` is not committed. Each developer creates their own when running `convex dev`.

### Option B — Create your own deployment

If you are starting fresh:

```powershell
npx convex dev
```

1. Choose **Create a new project** when prompted.
2. Leave this terminal running while you develop (watches `convex/` for changes).
3. Copy the `CONVEX_URL` from `.env.local` — you will need it for Flutter builds.

To push once without a watcher:

```powershell
npx convex dev --once
```

---

## Part 4 — Deploy backend code

### Development (your personal dev deployment)

While `npx convex dev` is running, saving files under `convex/` auto-deploys to your linked dev deployment.

Or push once:

```powershell
npx convex dev --once
```

### Production

Deploy to the production deployment linked to this repo:

```powershell
npm run deploy
```

Equivalent to:

```powershell
npx convex deploy
```

Use this before building release APKs/IPAs if backend code changed, so phones do not depend on your laptop running `convex dev`.

---

## Part 5 — Seed stop schedules (first time only)

Schedules live in the `stops` table. Import them from the bundled seed data:

```powershell
npx convex run stops:importAllFromFirestore
```

For production:

```powershell
npx convex run stops:importAllFromFirestore --prod
```

**Verify schedules loaded:**

```powershell
npx convex run stops:listStopIds
```

You should see a sorted list of stop IDs (e.g. `C07`, `H12`, `male_hostel`, …).

---

## Part 6 — Point the Flutter apps at your deployment

Both apps read `CONVEX_URL` from `--dart-define` at build time. Default fallback in code is `https://perfect-curlew-934.convex.cloud`.

### Android APK

```powershell
cd qu_bus_tracker
flutter build apk --release --dart-define=CONVEX_URL=https://YOUR-DEPLOYMENT.convex.cloud
```

```powershell
cd qu_bus_driver
flutter build apk --release --dart-define=CONVEX_URL=https://YOUR-DEPLOYMENT.convex.cloud
```

See [ANDROID_APK_GUIDE.md](./ANDROID_APK_GUIDE.md) for install steps.

### iOS IPA (GitHub Actions)

The workflow in `.github/workflows/ios-tracker-free.yml` already sets:

`CONVEX_URL=https://perfect-curlew-934.convex.cloud`

Change that value if you use a different deployment. See [IOS_SIDELOAD_GUIDE.md](./IOS_SIDELOAD_GUIDE.md).

### Local Flutter run

```powershell
cd qu_bus_tracker
flutter run --dart-define=CONVEX_URL=https://YOUR-DEPLOYMENT.convex.cloud
```

---

## Part 7 — Verify everything works

### 1. Health check

```powershell
curl -X POST https://perfect-curlew-934.convex.cloud/api/query `
  -H "Content-Type: application/json" `
  -d '{"path":"health:ping","args":{},"format":"json"}'
```

Expected response includes `"value":"ok"`.

### 2. Live buses

1. Install **qu_bus_driver** on a phone with real GPS.
2. Start tracking (driver name, bus ID, route).
3. Open **qu_bus_tracker** — a 🚌 marker should appear within a few seconds.

Stale bus positions are removed automatically after ~3 minutes (`buses:pruneStale` / `buses:listActive`).

---

## Backend layout

| Path | Purpose |
|------|---------|
| `convex/schema.ts` | `buses` and `stops` tables |
| `convex/buses.ts` | Live GPS upsert, list active buses, remove stale |
| `convex/stops.ts` | Schedule queries + seed import |
| `convex/stopsSeedData.ts` | Campus stop schedule data |
| `convex/health.ts` | `health:ping` connectivity check |

### Key functions used by the apps

| Function | App | Purpose |
|----------|-----|---------|
| `health:ping` | Tracker / Driver | Connection test |
| `buses:listActive` | Tracker | Poll live bus positions |
| `buses:upsertLocation` | Driver | Publish GPS |
| `buses:updateStatus` | Driver | Running / stopped status |
| `buses:remove` | Driver | Stop tracking cleanup |
| `stops:getSchedule` | Tracker | Stop departure times |

---

## npm scripts (repo root)

| Command | What it does |
|---------|----------------|
| `npm run dev` | Start `convex dev` watcher |
| `npm run deploy` | Deploy to production (`convex deploy`) |

---

## Troubleshooting

| Problem | Fix |
|--------|-----|
| `convex dev` asks to create a project | Run `npx convex login` first, or pick the existing team deployment |
| Apps show no schedules | Run `npx convex run stops:importAllFromFirestore` |
| Apps show no live buses | Deploy backend; confirm driver app uses the same `CONVEX_URL`; check driver is tracking |
| `CONVEX_URL` mismatch | Rebuild APK/IPA with the correct `--dart-define=CONVEX_URL=...` |
| Backend changes not on phones | Run `npx convex deploy` (production), not only local `convex dev` |
| Type errors in `convex/` | Run `npx convex dev --once` to regenerate `convex/_generated/` |

---

## Useful links

- [Convex docs](https://docs.convex.dev)
- [Convex dashboard](https://dashboard.convex.dev) — view data, logs, deployments
- [ANDROID_APK_GUIDE.md](./ANDROID_APK_GUIDE.md) — build and install Android apps
- [IOS_SIDELOAD_GUIDE.md](./IOS_SIDELOAD_GUIDE.md) — build and sideload iOS tracker
