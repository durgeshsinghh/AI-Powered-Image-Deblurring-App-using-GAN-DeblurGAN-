import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/providers/deblur_provider.dart';
import 'package:frontend/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen shows app bar title and picker buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeblurProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('AI Image Deblurring'), findsOneWidget);
    expect(find.text('Pick from Gallery'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
  });
}
