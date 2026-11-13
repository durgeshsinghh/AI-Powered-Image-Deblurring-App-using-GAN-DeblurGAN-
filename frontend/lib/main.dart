import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_keys.dart';
import 'providers/deblur_provider.dart';
import 'providers/history_provider.dart';
import 'providers/server_status_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  /// Tests skip the launch animation.
  final bool showSplash;

  const MyApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => ServerStatusProvider()),
        ChangeNotifierProvider(create: (_) => DeblurProvider()),
      ],
      child: MaterialApp(
        title: 'Deblur',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => AnnotatedRegion(
          value: AppTheme.overlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
        home: showSplash ? const SplashScreen(next: AppGate()) : const AppGate(),
      ),
    );
  }
}

/// Shows onboarding on first launch, otherwise goes straight to the app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.loaded) {
      return const Scaffold(backgroundColor: AppColors.bg);
    }
    return settings.onboardingDone ? const MainShell() : const OnboardingScreen();
  }
}
