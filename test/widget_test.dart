import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astro_admin/main.dart';

void main() {
  testWidgets('AstroAdmin app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AstroAdminApp());
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
