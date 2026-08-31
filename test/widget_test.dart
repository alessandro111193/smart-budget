import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_budget/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartBudgetApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
