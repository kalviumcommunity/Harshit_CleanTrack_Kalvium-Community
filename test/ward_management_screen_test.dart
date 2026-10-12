import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/ward_management_screen.dart';

void main() {
  testWidgets('Renders WardManagementScreen placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WardManagementScreen(),
      ),
    );
    expect(find.text('Ward Management'), findsNWidgets(2));
  });
}
