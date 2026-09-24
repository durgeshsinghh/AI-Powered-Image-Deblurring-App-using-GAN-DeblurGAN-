/// Backend base URL configuration.
///
/// `10.0.2.2` is the special alias the Android emulator uses to reach the
/// host machine's `localhost`. Since the Spring Boot backend
/// (`backend/`, see `../../docs/API_CONTRACT.md`) runs on the host machine
/// at `localhost:8080`, the Android emulator must use `10.0.2.2:8080`
/// instead of `localhost:8080` to reach it.
///
/// Change this value depending on where you're running the app:
/// - Android emulator (default here): `http://10.0.2.2:8080`
/// - Web or desktop (Windows/macOS/Linux) run: `http://localhost:8080`
/// - Physical device on the same Wi-Fi/LAN as your dev machine: your
///   machine's LAN IP, e.g. `http://192.168.1.42:8080`
/// - iOS simulator: `http://localhost:8080` also works (iOS simulator
///   shares the host's network namespace).
/// - Backend deployed on Render (or any host): its public HTTPS URL, e.g.
///   `https://deblurgan-backend.onrender.com` -- works from any device,
///   emulator or not, with no network setup needed. Swap to this once the
///   backend is deployed so the app works off your dev machine entirely.
class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:8080";
}
