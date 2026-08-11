# CafeFlow — PWA Deployment Guide (iPhone / iOS)

Deploy CafeFlow as a **private Progressive Web App** on Firebase Hosting. Employees install from Safari without the App Store.

---

## Prerequisites

- Flutter SDK 3.16+ with web enabled
- Firebase CLI: `npm install -g firebase-tools`
- Logged in: `firebase login`
- Project: `cafeflow-5tg` (see `.firebaserc`)

---

## 1. One-time setup

```bash
# Enable web (if needed)
flutter config --enable-web

# Install dependencies
flutter pub get

# Link Firebase project (already configured)
firebase use cafeflow-5tg
```

**Authorized domains** (Firebase Console → Authentication → Settings):

- `cafeflow-5tg.web.app`
- `cafeflow-5tg.firebaseapp.com`
- Any custom domain you add

**Google Sign-In (web):** ensure the OAuth client ID in `web/index.html` matches your Firebase web app.

---

## 2. Production web build

```bash
flutter build web --release --base-href "/"
```

Offline-first PWA caching is enabled by default in current Flutter versions (`flutter_service_worker.js` is generated automatically).

Output: `build/web/`

This generates:

- `flutter_service_worker.js` — app shell + asset cache (offline-first)
- Compiled Flutter app (CanvasKit or skwasm depending on flags)

Optional (smaller download, faster text):

```bash
flutter build web --release --web-renderer html --pwa-strategy offline-first
```

---

## 3. Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

Default URL: **https://cafeflow-5tg.web.app**

After first deploy, confirm `lib/core/pwa/pwa_config.dart` → `PwaConfig.hostingUrl` matches your live URL (custom domain if used).

---

## 4. Private iPhone install flow (QR)

1. Admin opens **Admin Panel → Distribute App → iPhone (PWA)**.
2. Print or display the QR code (links to `https://cafeflow-5tg.web.app/?install=1`).
3. Employee scans with **Camera** → opens **Safari**.
4. Install tutorial appears automatically.
5. **Share → Add to Home Screen** → open from Home Screen (standalone, no browser UI).

---

## 5. What is configured

| Item | Location |
|------|----------|
| Web manifest | `web/manifest.json` |
| iOS meta tags & splash | `web/index.html` |
| PWA CSS (safe area, no zoom) | `web/pwa-styles.css` |
| Pre-Flutter splash / FCM SW register | `web/pwa-init.js` |
| Offline HTML fallback | `web/offline.html` |
| FCM background worker | `web/firebase-messaging-sw.js` |
| Install tutorial UI | `lib/core/pwa/widgets/pwa_install_tutorial.dart` |
| Firestore offline persistence | `lib/main.dart` |
| Schedule JSON cache | `lib/core/pwa/schedule_offline_cache.dart` |
| Hosting config | `firebase.json` |

---

## 6. iOS PWA limitations (expected)

| Feature | iOS installed PWA |
|---------|-------------------|
| Add to Home Screen | ✅ Supported |
| Standalone / fullscreen | ✅ Supported |
| Firestore offline cache | ✅ IndexedDB persistence |
| Push notifications | ⚠️ Very limited; in-app refresh recommended |
| Background sync | ❌ App updates when opened |
| Local notifications | ❌ Use native app or email for critical alerts |

The app shows an **iPhone app notes** banner on web with details.

---

## 7. Updating the live PWA

```bash
flutter build web --release
firebase deploy --only hosting
```

Users get the new version on next launch (service worker updates). For urgent fixes, bump `version` in `pubspec.yaml` before building.

---

## 8. Custom domain (optional)

Firebase Console → Hosting → Add custom domain → follow DNS steps.

Update `PwaConfig.hostingUrl` and redeploy.

---

## 9. Troubleshooting

**Install tutorial does not appear**

- Open URL with `?install=1`
- Reset: Distribution screen → “Reset install tutorial”
- Must use **Safari** on iPhone (not Chrome iOS for first install)

**Google Sign-In fails on web**

- Add hosting domain to Firebase Auth authorized domains
- Verify `google-signin-client_id` meta tag

**Stale app after deploy**

- Close PWA from app switcher and reopen
- Safari: Settings → Advanced → Website Data → remove site (last resort)

**Offline schedule empty**

- Sign in once while online so Firestore + JSON cache populate
- Reopen app when back online to refresh

---

## 10. Full deploy checklist

- [ ] `flutter build web --release --pwa-strategy offline-first`
- [ ] `firebase deploy --only hosting`
- [ ] Test on physical iPhone in Safari
- [ ] Add to Home Screen and verify standalone mode
- [ ] Test login (Google + email)
- [ ] Test schedule view offline (airplane mode after loading)
- [ ] Print QR from Admin → Distribute App

---

## Related docs

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) — Android APK & Codemagic iOS
- [SETUP_GUIDE.md](SETUP_GUIDE.md) — local development
