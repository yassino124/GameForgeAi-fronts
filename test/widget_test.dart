import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamefrogai/main.dart';

void main() {
  testWidgets('GameForge AI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GameForgeAI());

    // Verify that the app loads successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
