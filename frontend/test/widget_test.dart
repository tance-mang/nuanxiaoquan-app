// This is a basic Flutter widget test for WarmCircle app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warmcircle/main.dart';

void main() {
  testWidgets('WarmCircle app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WarmCircleApp());

    // Verify that the app starts with splash screen or main content
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Wait for any initial animations
    await tester.pumpAndSettle();
    
    // The app should be running without errors
    expect(find.byType(WarmCircleApp), findsOneWidget);
  });
}
