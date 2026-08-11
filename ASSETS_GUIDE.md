# CafeFlow - App Icons and Assets Guide

## App Icon Requirements

### Android
- **Sizes:** 48x48, 72x72, 96x96, 144x144, 192x192, 512x512
- **Format:** PNG with transparency
- **Location:** `android/app/src/main/res/mipmap-*/ic_launcher.png`

### iOS
- **Sizes:** 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024
- **Format:** PNG without transparency
- **Location:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Creating App Icons

### Option 1: Using flutter_launcher_icons

**Configure in `pubspec.yaml`:**
```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
```

**Generate icons:**
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

### Option 2: Manual Creation

**Recommended Tools:**
- Canva (https://www.canva.com/)
- Figma (https://www.figma.com/)
- Adobe Illustrator

**Design Guidelines:**
- Use CafeFlow brand colors (AppColors)
- Include coffee cup or coffee bean icon
- Clean, modern design
- High contrast for visibility

## Launch Screen

### Android
**Location:** `android/app/src/main/res/drawable/launch_background.xml`

**Example:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
```

### iOS
**Location:** `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

**Configure in `ios/Runner/Info.plist`:**
```xml
<key>UILaunchStoryboardName</key>
<string>LaunchScreen</string>
```

## Additional Assets

### Placeholder Images
Create placeholder images for:
- Coffee cup icon
- Calendar icon
- User avatar
- Location markers

**Location:** `assets/images/`

**Add to `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - assets/images/
```

## Testing Icons

### Android
```bash
flutter clean
flutter build apk
# Install on device and verify
```

### iOS
```bash
flutter clean
flutter build ios
# Test in simulator or device
```

## Current Configuration

The project currently has:
- `flutter_launcher_icons` configured in pubspec.yaml
- Placeholder icon path: `assets/icon/app_icon.jpg`
- Android min SDK: 21 (required for Google Sign-In)

## Next Steps

1. Create or obtain a professional app icon
2. Place it at `assets/icon/app_icon.png`
3. Run `flutter pub run flutter_launcher_icons`
4. Test the generated icons on both platforms
5. Create launch screen if needed
