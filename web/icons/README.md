# CafeFlow PWA icons — same source as Android

All icons are generated from **`assets/icon/app_icon.jpg`** (same as `ic_launcher` on Android).

```bash
dart run flutter_launcher_icons
```

This updates `android/.../ic_launcher.png`, iOS AppIcon, and `web/icons/Icon-*.png` + `favicon.png`.

iOS Home Screen sizes (`apple-touch-icon-*.png`) are resized from the same JPG (run after `flutter_launcher_icons` if you change the master icon):

```powershell
# From project root (PowerShell)
$src = "assets/icon/app_icon.jpg"
$out = "web/icons"
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($src)
foreach ($s in @(180,152,167)) {
  $bmp = New-Object System.Drawing.Bitmap $s, $s
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $s, $s)
  $g.Dispose()
  $bmp.Save("$out/apple-touch-icon-$s.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
$img.Dispose()
```

## Files

| File | Size | Purpose |
|------|------|---------|
| `apple-touch-icon-180.png` | 180×180 | iOS Home Screen (primary) |
| `apple-touch-icon-152.png` | 152×152 | iPad |
| `apple-touch-icon-167.png` | 167×167 | iPad Pro |
| `Icon-192.png` | 192×192 | Android / manifest |
| `Icon-512.png` | 512×512 | Android install UI |
| `Icon-maskable-192.png` | 192×192 | Android adaptive |
| `Icon-maskable-512.png` | 512×512 | Android adaptive large |
