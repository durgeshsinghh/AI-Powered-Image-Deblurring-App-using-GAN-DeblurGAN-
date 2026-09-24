import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/deblur_provider.dart';
import 'package:frontend/providers/history_provider.dart';
import 'package:frontend/screens/main_screen.dart';

void main() {
  testWidgets('MainScreen shows app bar title and bottom action bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DeblurProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('AI Image Deblurring'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
  });
}
