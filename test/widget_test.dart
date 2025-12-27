import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamingplat/main.dart';

void main() {
  testWidgets('Admin app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AdminApp());

    // Verify that the title is correct
    expect(find.text('Panel de Administración StreamZone'), findsOneWidget);

    // Verify that the add button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
