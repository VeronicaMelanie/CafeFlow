# CafeFlow - Deployment Guide

## Android APK Signing and Distribution

### 1. Generate Keystore

**Generate a signing key:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important:** Store the keystore file securely. Never commit it to version control.

### 2. Configure Android Signing

**Create `android/key.properties` file:**
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

**Add to `.gitignore`:**
```
android/key.properties
*.jks
```

**Update `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 3. Build Release APK

**Build APK:**
```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### 4. Distribute APK

**Direct Distribution:**
1. Upload APK to a file hosting service (Google Drive, Dropbox, etc.)
2. Share download link with employees
3. Update the download link in the Distribution Screen

**Alternative Distribution:**
- Firebase App Distribution
- TestFlight (for iOS)
- Internal App Distribution

---

## iOS Distribution via Codemagic

### 1. Apple Developer Account Setup

**Required:**
- Apple Developer Program membership ($99/year)
- Team ID
- Bundle Identifier (e.g., com.cafeflow.app)

### 2. Configure Codemagic

**Add Code Signing:**
1. Go to Codemagic project settings
2. Navigate to "Code signing"
3. Add Apple Developer credentials
4. Upload provisioning profiles

**Update `codemagic.yaml`:**
```yaml
workflows:
  ios-workflow:
    name: iOS Release Build
    environment:
      vars:
        XCODE_WORKSPACE: Runner.xcworkspace
        XCODE_SCHEME: Runner
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Build iOS
        script: flutter build ios --release
    artifacts:
      - build/ios/ipa/*.ipa
```

### 3. Build and Distribute

**Build via Codemagic:**
1. Push to GitHub
2. Codemagic automatically triggers build
3. Download IPA file

**Distribute Options:**
- TestFlight (for beta testing)
- Ad-Hoc (for internal testing)
- App Store (for public distribution)

---

## Firebase Configuration for Production

### 1. Update Firebase Project

**Switch to Production Mode:**
1. Go to Firebase Console
2. Project Settings → General
3. Change from Test Mode to Production Mode
3. Update security rules if needed

### 2. Generate Production firebase_options.dart

```bash
flutterfire configure --project=cafeflow-production
```

### 3. Update App Configuration

**Android:**
- Replace `google-services.json` with production version
- Update package name if needed

**iOS:**
- Replace `GoogleService-Info.plist` with production version
- Update bundle identifier

---

## Version Management

### Update Version Number

**Android (`android/app/build.gradle`):**
```gradle
defaultConfig {
    versionCode 2
    versionName "1.0.1"
}
```

**iOS (`ios/Runner/Info.plist`):**
```xml
<key>CFBundleShortVersionString</key>
<string>1.0.1</string>
<key>CFBundleVersion</key>
<string>2</string>
```

**Flutter (`pubspec.yaml`):**
```yaml
version: 1.0.1+2
```

---

## Testing Before Deployment

### Pre-Deployment Checklist

- [ ] Test all features on physical devices
- [ ] Verify Firebase authentication works
- [ ] Test scheduling engine with real data
- [ ] Verify notifications work
- [ ] Test vacation request/approval flow
- [ ] Check consumption logging
- [ ] Verify admin screens functionality
- [ ] Test on both Android and iOS (if applicable)

### Beta Testing

**Android:**
- Distribute APK to small group
- Collect feedback
- Fix issues before full rollout

**iOS:**
- Upload to TestFlight
- Invite beta testers
- Monitor crash reports

---

## Troubleshooting

### Android Build Issues

**Signature Verification Failed:**
- Check keystore credentials in key.properties
- Verify keystore file path is correct

**Install Blocked:**
- Enable "Install from Unknown Sources" on device
- Sign APK with release keystore

### iOS Build Issues

**Code Signing Errors:**
- Verify Apple Developer account is active
- Check provisioning profiles are valid
- Ensure bundle identifier matches

**Codemagic Build Failures:**
- Check workflow configuration
- Verify dependencies are compatible
- Review build logs for specific errors

---

## Maintenance

### Regular Updates

1. **Monthly:** Review Firebase usage and costs
2. **Quarterly:** Update dependencies (`flutter pub upgrade`)
3. **Annually:** Renew Apple Developer membership

### Monitoring

- Firebase Crashlytics for crash reports
- Firebase Analytics for usage metrics
- Firestore usage for database performance

---

## Progressive Web App (iPhone)

For **private iPhone distribution without the App Store**, use the PWA on Firebase Hosting.

See **[PWA_DEPLOYMENT_GUIDE.md](PWA_DEPLOYMENT_GUIDE.md)** for:

- `flutter build web` + `firebase deploy --only hosting`
- QR-based employee install flow
- iOS Safari / Add to Home Screen setup

---

## Support

For deployment issues:
- **Flutter:** https://docs.flutter.dev/deployment
- **Firebase:** https://firebase.google.com/docs
- **Codemagic:** https://docs.codemagic.io/
