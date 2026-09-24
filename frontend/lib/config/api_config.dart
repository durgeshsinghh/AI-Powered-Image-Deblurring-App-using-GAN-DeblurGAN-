/// Backend base URL configuration.
///
/// Points at the backend deployed on Render -- works from any device
/// (emulator, physical phone, web) with no local network setup needed.
/// That service calls the deployed DeblurGAN API in turn; both are on
/// Render's free tier, so the very first request after a period of
/// inactivity can take up to a couple of minutes while both wake up (see
/// the loading message in `screens/home_screen.dart`).
///
/// Swap this for local development instead:
/// - Android emulator: `http://10.0.2.2:8080` (`10.0.2.2` is the emulator's
///   alias for the host machine's `localhost`, where a locally-run backend
///   listens on port 8080).
/// - Web or desktop (Windows/macOS/Linux) run: `http://localhost:8080`
/// - Physical device on the same Wi-Fi/LAN as your dev machine: your
///   machine's LAN IP, e.g. `http://192.168.1.42:8080`
/// - iOS simulator: `http://localhost:8080` also works (iOS simulator
///   shares the host's network namespace).
class ApiConfig {
  static const String baseUrl = "https://deblurgan-backend.onrender.com";
}
