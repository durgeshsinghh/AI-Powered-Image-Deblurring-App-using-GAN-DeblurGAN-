# frontend/ — AI Image Deblurring (Flutter app)

Mobile client for the DeblurGAN final-year project. Lets a user pick a
blurred photo (gallery or camera), sends it to the Spring Boot backend
(`../backend/`), and shows a before/after comparison of the original vs. the
AI-deblurred result.

This app never talks to the Python ML service directly — it only calls the
backend's `/api/v1/*` routes. See [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md)
for the full contract between all three parts of the system.

## What it does

1. Pick a blurred JPG/PNG photo from the gallery, or take one with the
   camera.
2. Tap "Deblur Image" to upload it to the backend
   (`POST /api/v1/deblur`, multipart field `image`).
3. While the backend (and, behind it, the ML inference engine) processes the
   image, a loading indicator is shown.
4. On success, the original and deblurred images are shown side by side,
   along with how long processing took.
5. On failure (network error, backend error, ML engine unavailable), an
   error message is shown with a retry option.

## Project structure

```
lib/
  config/api_config.dart       # backend base URL
  models/deblur_result.dart    # DeblurResult, parses the backend's JSON response
  services/api_service.dart    # Dio-based HTTP client for /api/v1/*
  providers/deblur_provider.dart # ChangeNotifier state (pick -> submit -> result)
  screens/home_screen.dart     # main (only) screen
  widgets/before_after_view.dart # side-by-side before/after image widget
  main.dart                    # app entry point
test/
  widget_test.dart             # widget test for HomeScreen
```

## Running it

```sh
flutter pub get
flutter run                # with an emulator/device connected
flutter run -d chrome      # quick web check (no camera picker support on web)
```

The backend (`../backend/`) should be running first — it talks to the
already-deployed ML API by default, so no separate local ML setup is
needed. See the root [`README.md`](../README.md) for the full run order.

## Backend URL configuration

The backend base URL is set in [`lib/config/api_config.dart`](lib/config/api_config.dart):

```dart
class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:8080";
}
```

`10.0.2.2` is the Android emulator's special alias for the host machine's
`localhost`, which is where the Spring Boot backend runs by default
(`:8080`). Change this constant depending on how you're running the app:

- **Android emulator** (default): `http://10.0.2.2:8080`
- **Web or desktop run** (`flutter run -d chrome`, Windows, etc.):
  `http://localhost:8080`
- **Physical device** on the same Wi-Fi/LAN as your dev machine: your
  machine's LAN IP, e.g. `http://192.168.1.42:8080`
- **iOS simulator**: `http://localhost:8080` also works.

## Verifying the app

```sh
flutter analyze     # static analysis — should report "No issues found!"
flutter test        # widget test — should pass
```

Both commands work without a connected device/emulator.

## Contract

See [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md) for the exact
request/response shapes this app is built against (field names must match
exactly: `success`, `originalFilename`, `processingTimeMs`,
`deblurredImageBase64`, `error`, and multipart field `image`).
