# iOS PWA Setup — Production Reference (CafeFlow)

Complete Progressive Web App configuration for **Safari “Add to Home Screen”** on iPhone and iPad. No App Store, no native wrapper.

---

## 1. Project structure

```
web/
├── index.html              # iOS meta tags, splash links, app shell
├── manifest.json           # Android + spec-compliant manifest (iOS ignores most of it)
├── pwa-init.js             # Splash, offline hint, standalone detection, FCM SW
├── register-sw.js          # Registers sw.js (skipped when Flutter is present)
├── sw.js                   # Static shell offline cache (non-Flutter / reference)
├── pwa-styles.css          # Safe-area, splash, iOS scroll fixes
├── offline.html            # Navigation offline fallback
├── firebase-messaging-sw.js # Push (separate scope; optional)
├── favicon.png
├── icons/
│   ├── README.md
│   ├── apple-touch-icon-180.png   ← REQUIRED for iOS
│   ├── apple-touch-icon-152.png   ← optional iPad
│   ├── apple-touch-icon-167.png   ← optional iPad Pro
│   ├── Icon-192.png
│   ├── Icon-512.png
│   ├── Icon-maskable-192.png
│   └── Icon-maskable-512.png
└── splash/
    ├── README.md
    ├── iphone-15-pro-max-portrait.png
    ├── iphone-15-pro-portrait.png
    └── … (see splash/README.md)
```

After `flutter build web`, Flutter also emits:

```
build/web/
├── flutter_service_worker.js   ← production offline cache (scope /)
├── flutter_bootstrap.js
└── … compiled assets
```

---

## 2. iOS meta tags (in `index.html`)

These are **required** for standalone Home Screen behavior:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="CafeFlow">
<link rel="manifest" href="manifest.json">
```

| Meta | Value | Effect |
|------|-------|--------|
| `apple-mobile-web-app-capable` | `yes` | Opens without Safari UI when launched from Home Screen |
| `apple-mobile-web-app-status-bar-style` | `black-translucent` | Status bar overlays content; use `env(safe-area-inset-top)` in CSS |
| `apple-mobile-web-app-title` | Short name | Label under icon (≤12 chars ideal) |
| `viewport-fit=cover` | — | Extends into notch / Dynamic Island |

**Status bar styles:** `default` (light bar), `black` (dark bar), `black-translucent` (transparent overlay). CafeFlow uses `black-translucent` + safe-area padding in `pwa-styles.css`.

---

## 3. Apple Touch Icon setup

iOS **does not** read install icons from `manifest.json`. It uses `<link rel="apple-touch-icon">`.

```html
<link rel="apple-touch-icon" href="icons/apple-touch-icon-180.png">
<link rel="apple-touch-icon" sizes="180x180" href="icons/apple-touch-icon-180.png">
<link rel="apple-touch-icon" sizes="152x152" href="icons/apple-touch-icon-152.png">
<link rel="apple-touch-icon" sizes="167x167" href="icons/apple-touch-icon-167.png">
```

### Icon sizes to generate

| Asset | Size | Required |
|-------|------|----------|
| `apple-touch-icon-180.png` | 180×180 | **Yes** (all modern iPhones) |
| `apple-touch-icon-152.png` | 152×152 | iPad |
| `apple-touch-icon-167.png` | 167×167 | iPad Pro |
| `Icon-192.png` / `Icon-512.png` | 192 / 512 | Android + manifest |
| `Icon-maskable-*.png` | 192 / 512 | Android adaptive icon |

Export from a **1024×1024** master. See `web/icons/README.md` for ImageMagick / `pwa-asset-generator` commands.

---

## 4. Service worker & caching

### Flutter production (this project)

```bash
flutter build web --release --pwa-strategy offline-first
```

- **`flutter_service_worker.js`** — precaches all compiled assets; network-first or offline-first per strategy.
- **`register-sw.js`** detects `flutter_bootstrap.js` and **does not** register `sw.js` (one SW per scope).
- **`firebase-messaging-sw.js`** — separate scope `/firebase-cloud-messaging-push-scope` for FCM only.

### Static / reference worker (`sw.js`)

For vanilla HTML PWAs or local static preview without Flutter:

| Phase | Strategy |
|-------|----------|
| **install** | Precache shell: `/`, `index.html`, `offline.html`, `manifest.json`, CSS, JS, icons |
| **navigate** | Network-first → fallback to cache → `offline.html` |
| **static assets** | Cache-first → update cache on network success |
| **activate** | Delete old cache versions; `clients.claim()` |

Bump `CACHE_VERSION` in `sw.js` when shell assets change.

### Hosting headers (`firebase.json`)

- `flutter_service_worker.js`, `sw.js`, `manifest.json` → `Cache-Control: no-cache` (updates propagate).
- Hashed JS/CSS/WASM → `max-age=31536000, immutable`.

---

## 5. Service worker registration

**`register-sw.js`** (minimal):

```javascript
if ('serviceWorker' in navigator && !document.querySelector('script[src*="flutter_bootstrap"]')) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/sw.js', { scope: '/' });
  });
}
```

Included in `index.html` **before** `flutter_bootstrap.js`.

---

## 6. How to install on iOS (Safari)

There is **no install prompt** on iOS. Users must use Share → Add to Home Screen.

### Step-by-step (iPhone)

1. Open the app URL in **Safari** (not Chrome/Firefox on iOS for first install).
   - Example: `https://cafeflow-5tg.web.app/?install=1`
2. Wait for the page to load (login if needed).
3. Tap the **Share** button (square with arrow ↑) in the Safari toolbar.
4. Scroll the share sheet and tap **Add to Home Screen**.
5. Confirm the name (**CafeFlow**) and tap **Add**.
6. Launch from the new Home Screen icon — the app runs **standalone** (no URL bar).

### iPad

Same flow: Safari → Share → Add to Home Screen.

### Verify standalone mode

- No Safari address bar or bottom toolbar.
- `window.navigator.standalone === true` (iOS only).
- Or `display-mode: standalone` via `matchMedia`.

CafeFlow exposes this in `window.cafeFlowPwa.isStandalone()` (`pwa-init.js`) and shows an in-app install tutorial when `?install=1` is present.

### Important iOS constraints

- **HTTPS required** (Firebase Hosting provides this).
- **User gesture** — cannot programmatically trigger install.
- **Per-origin** — each domain is a separate install.
- **Updates** — new service worker activates on next cold start after deploy.

---

## 7. Splash screen behavior on iOS

iOS shows a launch image **before** your HTML/JS runs:

1. **`apple-touch-startup-image`** links in `index.html` (device-specific `media` queries).
2. If no matching image → solid **`background_color`** from manifest (unreliable on iOS) or white flash.
3. After load → CafeFlow **`#cafeflow-splash`** in HTML until `flutter-first-frame` (see `pwa-init.js`).

**Best practice:** generate exact-size PNGs in `web/splash/` (see `web/splash/README.md`). Until then, missing splash files may show a brief blank screen before the HTML splash.

**Tip:** Match splash background to `pwa-styles.css` / `#cafeflow-splash` gradient to avoid a visible flash.

---

## 8. `manifest.json` (iOS + Android)

iOS uses manifest lightly (name hints, theme on some versions). Android relies on it fully.

Key fields in `web/manifest.json`:

```json
{
  "id": "/",
  "name": "CafeFlow",
  "short_name": "CafeFlow",
  "start_url": "/?source=pwa",
  "scope": "/",
  "display": "standalone",
  "background_color": "#FDFBF7",
  "theme_color": "#FF6B9B",
  "icons": [ … ]
}
```

- **`start_url`** — append `?source=pwa` to detect launches from Home Screen in analytics.
- **`display: standalone`** — Android; iOS uses `apple-mobile-web-app-capable` instead.
- **`prefer_related_applications: false`** — do not suggest native store apps.

---

## 9. Deploy checklist

```bash
# 1. Add icons (at minimum apple-touch-icon-180.png + Icon-192/512)
# 2. Optional: generate splash PNGs into web/splash/

flutter build web --release --pwa-strategy offline-first
firebase deploy --only hosting
```

**On a physical iPhone:**

- [ ] Open in Safari over HTTPS
- [ ] Add to Home Screen
- [ ] Icon shows correctly (180×180 asset)
- [ ] Standalone mode (no browser chrome)
- [ ] Safe area / notch padding looks correct
- [ ] Airplane mode after first load → cached UI or `offline.html`
- [ ] Close from app switcher and reopen → picks up new version after deploy

---

## 10. Troubleshooting

| Issue | Fix |
|-------|-----|
| Wrong/missing icon | Add `icons/apple-touch-icon-180.png`; clear Safari website data |
| Opens in Safari tab, not standalone | Must launch from Home Screen icon, not bookmark |
| White flash on launch | Add `apple-touch-startup-image` PNGs for target device |
| Old version after deploy | Kill app from switcher; SW updates on next launch |
| Install tutorial missing | Use `?install=1`; must be Safari |
| Two service workers fighting | Do not register `sw.js` when Flutter is present (already handled) |

---

## Related files in this repo

| File | Role |
|------|------|
| `PWA_DEPLOYMENT_GUIDE.md` | Firebase deploy + QR distribution |
| `lib/core/pwa/` | Flutter install tutorial, offline cache, banners |
| `firebase.json` | Hosting, SW cache headers |
