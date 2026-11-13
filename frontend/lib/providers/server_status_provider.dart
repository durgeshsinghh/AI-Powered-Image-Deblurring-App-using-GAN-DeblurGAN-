import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

enum ServerStatus { checking, online, offline }

/// Pings the backend's health endpoint. Render's free tier sleeps when idle,
/// so the first check can take a while — that's shown as "checking".
class ServerStatusProvider extends ChangeNotifier {
  final ApiService _api;

  ServerStatusProvider({ApiService? api}) : _api = api ?? ApiService();

  ServerStatus status = ServerStatus.checking;
  bool _inFlight = false;

  Future<void> check() async {
    if (_inFlight) return;
    _inFlight = true;
    status = ServerStatus.checking;
    notifyListeners();
    final ok = await _api.checkBackendHealth();
    if (_disposed) return;
    status = ok ? ServerStatus.online : ServerStatus.offline;
    _inFlight = false;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void markOnline() {
    if (status != ServerStatus.online) {
      status = ServerStatus.online;
      notifyListeners();
    }
  }
}
