# iOS launch images (splash screens)

iOS **does not** use `manifest.json` for splash screens. You must provide `apple-touch-startup-image` `<link>` tags in `index.html` (already listed there).

Generate portrait PNGs named as in `index.html`, e.g.:

| File | Pixel size | Device (logical) |
|------|------------|------------------|
| `iphone-15-pro-max-portrait.png` | 1290×2796 | 430×932 @3x |
| `iphone-15-pro-portrait.png` | 1179×2556 | 393×852 @3x |
| `iphone-14-portrait.png` | 1170×2532 | 390×844 @3x |
| `iphone-x-portrait.png` | 1125×2436 | 375×812 @3x |
| `iphone-8-plus-portrait.png` | 1242×2208 | 414×736 @3x |
| `iphone-se-portrait.png` | 750×1334 | 375×667 @2x |
| `ipad-pro-12-portrait.png` | 2048×2732 | 1024×1366 @2x |

**Formula:** `width_px = device-width × pixel-ratio`, same for height.

Design: full-bleed background `#FDFBF7` or brand gradient, centered logo (no text smaller than 24pt at 1x).

Until custom splashes exist, `index.html` falls back to `icons/Icon-512.png` for some breakpoints — replace `href` with `splash/...` paths after export.

Tools: [appsco.pe/developer/splash-screens](https://appsco.pe/developer/splash-screens), Figma, or `pwa-asset-generator` with `--splash-only`.
