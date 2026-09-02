import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_budget/utils/amount_input.dart';

void main() {
  testWidgets('accetta sia la virgola sia il punto come separatore decimale',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            keyboardType: amountKeyboardType,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '15,50');
    await tester.pump();
    expect(parseAmount(controller.text), 15.5);

    await tester.enterText(find.byType(TextField), '15.50');
    await tester.pump();
    expect(parseAmount(controller.text), 15.5);
  });
}
