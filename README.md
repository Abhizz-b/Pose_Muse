# pose_muse

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
## Tech Stack

### Framework
- **Flutter** (Dart) — cross-platform framework, single codebase for Android & iOS
- SDK constraint: `^3.8.1`

### Camera & Capture
- **camera** `^0.10.5+9` — live camera preview, photo capture, flash control, zoom, front/back camera switching

### AI / Computer Vision (On-Device, No Cloud)
- **google_mlkit_pose_detection** `^0.12.0` — detects body landmarks (shoulders, hips, knees, ankles) in real-time to classify full-body vs selfie framing
- **google_mlkit_image_labeling** `^0.11.0` — general image content analysis
- Both run **entirely on-device** via Google ML Kit — no internet/API call needed, faster + privacy-friendly

### Local Storage (No Backend)
- **shared_preferences** `^2.3.2` — stores favourites/saved poses as local key-value data
- **path_provider** `^2.1.4` — resolves local file system paths for storing captured photos
- App is fully offline-first — zero server, zero database, zero deployment cost

### Media Handling
- **image_picker** `^1.1.2` — pick images from device gallery
- **share_plus** `^10.1.2` — native share sheet integration (WhatsApp, Drive, Telegram, etc.)

### Networking
- **http** `^1.6.0` — reserved for future use; no active backend calls currently

### UI / Design
- Custom-built Flutter widgets (no UI kit/library)
- Dark theme — primary background `#0D0D0D`, surface `#1A1A1A`
- Purple accent color `#9C6FFF` — used in glow effects, buttons, active states, gradients
- **cupertino_icons** `^1.0.8` — iOS-style icon set
- Custom font: **DancingScript** (variable weight)
- Custom app icon + adaptive icon via **flutter_launcher_icons** `^0.13.1`
- Custom native splash screen via **flutter_native_splash** `^2.4.1`

### Dev Tools
- **flutter_lints** `^5.0.0` — static analysis & code quality rules
- **flutter_test** — widget/unit testing (Flutter SDK default)

### Architecture
- Standalone offline-first mobile app
- No backend server, no cloud database, no deployment infra (AWS/Render/Firebase) required
- All AI inference + data persistence happens locally on-device
