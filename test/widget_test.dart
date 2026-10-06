import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/main.dart';

void main() {
  testWidgets(
    'CleanTrack app launches and renders splash screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const CleanTrackApp());

      expect(find.text('CleanTrack'), findsOneWidget);
      expect(find.text('Hospital Housekeeping Management'), findsOneWidget);

      // Advance clock past the splash screen delay to resolve pending timers
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}