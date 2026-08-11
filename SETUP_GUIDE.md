# CafeFlow - Complete Environment Setup Guide

## Prerequisites

Before starting, ensure you have:
- Windows PC with administrator access
- Stable internet connection
- Google account (for Firebase and Google Sign-In)

---

## 1. Software Installation

### 1.1 Visual Studio Code (VS Code)

**Download:** https://code.visualstudio.com/

**Installation:**
1. Run the installer
2. Select "Add to PATH" during installation
3. Complete the installation

**Required Extensions:**
1. Flutter
2. Dart
3. Error Lens
4. GitLens
5. Firebase Explorer
6. Awesome Flutter Snippets

**Install Extensions:**
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for each extension and click "Install"

---

### 1.2 Flutter SDK

**Download:** https://docs.flutter.dev/get-started/install/windows

**Installation:**
1. Download Flutter SDK zip file
2. Extract to `C:\src\flutter` (recommended location)
3. Add Flutter to PATH:
   - Right-click "This PC" → Properties → Advanced system settings
   - Environment Variables → System variables → Path → Edit
   - Add: `C:\src\flutter\bin`

**Verify Installation:**
```bash
flutter doctor
```

**Accept Android Licenses:**
```bash
flutter doctor --android-licenses
```
Type 'y' and accept all licenses.

---

### 1.3 Android Studio

**Download:** https://developer.android.com/studio

**Installation:**
1. Run the installer
2. Choose "Standard" installation
3. Complete the installation

**Configure Android SDK:**
1. Open Android Studio
2. Tools → SDK Manager
3. Install:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android 13.0 (API 33) or later
   - Android SDK Command-line Tools

**Configure Android Emulator:**
1. Tools → Device Manager
2. Click "Create Device"
3. Choose Pixel 6 or similar device
4. Select system image (API 33 or later)
5. Finish and start the emulator

**Enable USB Debugging (for physical devices):**
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect device via USB
4. Verify: `flutter devices`

---

### 1.4 Node.js

**Download:** https://nodejs.org/

**Installation:**
1. Download LTS version
2. Run the installer
3. Complete the installation

**Verify:**
```bash
node --version
npm --version
```

---

### 1.5 Git

**Download:** https://git-scm.com/download/win

**Installation:**
1. Run the installer
2. Select "Git from the command line"
3. Complete the installation

**Configure Git:**
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

### 1.6 Firebase CLI

**Installation:**
```bash
npm install -g firebase-tools
```

**Verify:**
```bash
firebase --version
```

**Login to Firebase:**
```bash
firebase login
```
This will open a browser window. Login with your Google account.

---

### 1.7 FlutterFire CLI

**Installation:**
```bash
dart pub global activate flutterfire_cli
```

**Add to PATH:**
Add `C:\Users\YourUsername\AppData\Local\Pub\Cache\bin` to system PATH

**Verify:**
```bash
flutterfire --version
```

---

## 2. Firebase Project Setup

### 2.1 Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: "CafeFlow"
4. Enable Google Analytics (optional)
5. Create project

---

### 2.2 Configure Authentication

1. In Firebase Console, go to Authentication
2. Click "Get Started"
3. Enable "Google" sign-in provider
4. Download the configuration file (will be done later with FlutterFire CLI)

---

### 2.3 Configure Firestore

1. In Firebase Console, go to Firestore Database
2. Click "Create database"
3. Choose location (e.g., europe-west3)
4. Start in "Test mode" (we'll add security rules later)
5. Deploy the provided `firestore.rules` file

**Deploy Security Rules:**
```bash
firebase firestore:rules:deploy firestore.rules
```

**Deploy Indexes:**
```bash
firebase firestore:indexes deploy firestore.indexes.json
```

---

### 2.4 Configure Cloud Messaging (FCM)

1. In Firebase Console, go to Cloud Messaging
2. Click "Get Started"
3. Note down your Server Key and Sender ID

---

## 3. Project Configuration

### 3.1 Clone/Setup Project

```bash
cd "d:\Proiectepersonale\My projects\5ToGo-App"
flutter pub get
```

---

### 3.2 Generate Firebase Options

**Run FlutterFire CLI:**
```bash
flutterfire configure
```

This will:
1. List your Firebase projects
2. Let you select "CafeFlow"
3. Configure Android and iOS platforms
4. Generate `firebase_options.dart`

---

### 3.3 Configure Google Sign-In (Android)

1. In Firebase Console, go to Project Settings
2. Scroll to "Your apps" → Android
3. Download `google-services.json`
4. Place in `android/app/`

**Add SHA-1 Fingerprint:**
```bash
cd android
./gradlew signingReport
```
Copy the SHA-1 fingerprint and add it to Firebase Console under Android app settings.

---

### 3.4 Configure Google Sign-In (iOS)

1. In Firebase Console, add iOS app
2. Download `GoogleService-Info.plist`
3. Place in `ios/Runner/`

**Note:** For iOS builds, you'll need an Apple Developer account or use Codemagic.

---

## 4. GitHub Setup

### 4.1 Initialize Git Repository (if not already)

```bash
git init
git add .
git commit -m "Initial commit"
```

### 4.2 Create GitHub Repository

1. Go to https://github.com/
2. Create new repository "CafeFlow"
3. Make it private
4. Copy the repository URL

### 4.3 Push to GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/CafeFlow.git
git branch -M main
git push -u origin main
```

---

## 5. Codemagic Setup (iOS Cloud Builds)

### 5.1 Create Codemagic Account

1. Go to https://codemagic.io/
2. Sign up with GitHub
3. Authorize Codemagic to access your repository

### 5.2 Configure Application

1. Click "Add application"
2. Select "CafeFlow" repository
3. Choose workflow type: "Flutter workflow"

### 5.3 Update codemagic.yaml

The provided `codemagic.yaml` includes basic iOS build configuration. For production:

1. Add code signing in Codemagic
2. Configure TestFlight or Ad-Hoc distribution
3. Set up automatic builds on push to main

---

## 6. Verification

### 6.1 Run Flutter Doctor

```bash
flutter doctor
```

Ensure all items show checkmarks (except iOS if you don't have a Mac).

### 6.2 Run the App

**Android Emulator:**
```bash
flutter run
```

**Physical Android Device:**
```bash
flutter devices
flutter run -d <device_id>
```

### 6.3 Test Authentication

1. Open the app
2. Try Google Sign-In
3. Verify user is created in Firestore

### 6.4 Test Scheduling

1. Submit availability
2. Book a shift
3. Verify capacity checks work

---

## 7. Troubleshooting

### Flutter Doctor Issues

**Android licenses not accepted:**
```bash
flutter doctor --android-licenses
```

**Android SDK not found:**
- Check ANDROID_HOME environment variable
- Reinstall Android Studio

### Firebase Issues

**Firebase not initialized:**
- Verify `firebase_options.dart` exists
- Run `flutterfire configure` again

**Firestore permission denied:**
- Deploy security rules: `firebase firestore:rules:deploy firestore.rules`

### Build Issues

**Gradle sync failed:**
- Delete `android/.gradle` folder
- Run `flutter clean`
- Run `flutter pub get`

---

## 8. Next Steps

After completing setup:

1. Test all features thoroughly
2. Configure production Firebase project
3. Set up Codemagic for iOS builds
4. Test on physical devices
5. Prepare for deployment

---

## Support

For issues with:
- **Flutter:** https://docs.flutter.dev/
- **Firebase:** https://firebase.google.com/support
- **Codemagic:** https://docs.codemagic.io/
