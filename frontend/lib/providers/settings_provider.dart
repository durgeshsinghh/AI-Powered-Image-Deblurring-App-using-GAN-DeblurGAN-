import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/process_mode.dart';

/// User preferences, persisted with [SharedPreferences].
class SettingsProvider extends ChangeNotifier {
  static const _kOnboarding = 'onboarding_done_v1';
  static const _kMode = 'process_mode';
  static const _kWifiOnly = 'server_wifi_only';
  static const _kCache = 'cache_results';

  bool loaded = false;
  bool onboardingDone = false;
  ProcessMode mode = ProcessMode.auto;
  bool wifiOnly = false;
  bool cacheResults = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    onboardingDone = p.getBool(_kOnboarding) ?? false;
    mode = ProcessMode.fromName(p.getString(_kMode));
    wifiOnly = p.getBool(_kWifiOnly) ?? false;
    cacheResults = p.getBool(_kCache) ?? true;
    loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboardingDone = true;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kOnboarding, true);
  }

  Future<void> setMode(ProcessMode m) async {
    mode = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_kMode, m.name);
  }

  Future<void> setWifiOnly(bool v) async {
    wifiOnly = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kWifiOnly, v);
  }

  Future<void> setCacheResults(bool v) async {
    cacheResults = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kCache, v);
  }
}
