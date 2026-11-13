import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';
import 'package:frontend/models/history_entry.dart';
import 'package:frontend/utils/format.dart';

/// Unmounts the app and lets pending network timeouts (health check) expire.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 3));
}

void main() {
  setUp(() {
    // No network in tests: fall back to the default font.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('first launch shows onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp(showSplash: false));
    await tester.pump();
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('01 / 03'), findsOneWidget);
    expect(find.text('RESTORED'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('returning user lands on Home with floating nav', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    await tester.pumpWidget(const MyApp(showSplash: false));
    await tester.pump();
    await tester.pump();

    expect(find.text('Home'), findsOneWidget); // active nav pill label
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.bySemanticsLabel('New deblur'), findsOneWidget);

    // Switch to Settings via the nav.
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Cache results'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('launch animation hands off to the app', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    // Splash falls back after at most 8 s even if Lottie can't load.
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gallery'), findsOneWidget);
    await _teardown(tester);
  });

  test('history entries from older app versions still load', () {
    final e = HistoryEntry.fromJson({
      'id': '1731590000000000',
      'originalPath': '/a.jpg',
      'deblurredPath': '/b.png',
      'createdAt': '2026-11-14T10:00:00.000',
      'processingTimeMs': 800,
    });
    expect(e.mode, 'server');
    expect(e.hash, isNull);
    expect(e.name, 'IMG_0000');
  });

  test('chip formatting', () {
    final now = DateTime(2026, 11, 14, 21, 30);
    expect(Fmt.ago(now.subtract(const Duration(minutes: 2)), now: now), '2 MIN');
    expect(Fmt.ago(now.subtract(const Duration(hours: 1)), now: now), '1 HR');
    expect(Fmt.when(DateTime(2026, 11, 14, 21, 4), now: now), 'TODAY · 21:04');
    expect(Fmt.when(DateTime(2026, 11, 13, 9), now: now), 'YESTERDAY');
    expect(Fmt.bytes(1536), '2 KB');
  });

  testWidgets('dark theme uses the design background', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    await tester.pumpWidget(const MyApp(showSplash: false));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFF0A0A0B));
    await _teardown(tester);
  });
}
