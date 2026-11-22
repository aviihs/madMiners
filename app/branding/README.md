# Branding sources

Generated from `assets/images/mad_miners_icon.png` and `assets/images/splash sc.jpeg`.

| File | Used for |
|---|---|
| `icon_framed.png` | Android launcher icon on old phones (Android 7 and below) |
| `icon_adaptive_foreground.png` | Android 8+ adaptive icon (the launcher crops it to a circle or squircle) |
| `icon_full_bleed.png` | iOS app icon (iOS rounds the corners itself) |
| `splash_logo.png` | OS launch splash, Android 11 and below + iOS |
| `splash_android12.png` | OS launch splash, Android 12+ (logo fits inside the system's circle) |

The in-game loading screen art lives in `assets/images/loading/`.

After changing any of these (config is in `pubspec.yaml`):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
