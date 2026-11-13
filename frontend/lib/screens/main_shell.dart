import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/server_status_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_nav.dart';
import '../widgets/ui.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'new_deblur_sheet.dart';
import 'settings_screen.dart';

/// App shell: Home / History / Settings tabs under a floating glass nav.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().ensureLoaded();
      final server = context.read<ServerStatusProvider>();
      if (server.status != ServerStatus.online) server.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(onSeeAll: () => setState(() => _index = 1)),
                const HistoryScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomFade(height: 140, endOpacity: 0.95),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: bottom + 18,
            child: FloatingNav(
              index: _index,
              onSelect: (i) => setState(() => _index = i),
              onFab: () => NewDeblurSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}
