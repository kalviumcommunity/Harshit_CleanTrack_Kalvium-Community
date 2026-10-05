import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/main.dart';

void main() {
  testWidgets('CleanTrack app launches and renders registration screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CleanTrackApp());
    await tester.pumpAndSettle();

    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
