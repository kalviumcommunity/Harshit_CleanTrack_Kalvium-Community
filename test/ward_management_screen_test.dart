import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/ward_management_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/services/firestore_service.dart';
import 'package:cleantrack/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdmin = UserModel(
    userId: 'admin-001',
    name: 'Rajesh Kumar',
    employeeId: 'ADM-001',
    email: 'rajesh@cleantrack.org',
    role: UserRole.admin,
    status: UserStatus.available,
  );

  Widget createWardScreen({UserModel? admin}) {
    return MaterialApp(
      home: WardManagementScreen(
        adminUser: admin ?? testAdmin,
      ),
    );
  }

  setUp(() {
    FirestoreService().clearAllData();
    AuthService().clearUsers();
  });

  testWidgets('Renders Ward Management AppBar with back button, notifications and admin initials avatar', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Ward Management'), findsOneWidget);
    expect(find.byKey(const Key('wardManagementBackButton')), findsOneWidget);
    expect(find.byKey(const Key('wardManagementNotificationButton')), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);
  });

  testWidgets('Tapping notification button opens Admin Notifications dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wardManagementNotificationButton')));
    await tester.pumpAndSettle();

    expect(find.text('Admin Notifications'), findsOneWidget);
    expect(find.text('Ward Coverage Active'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Notifications'), findsNothing);
  });

  testWidgets('Renders Create Ward form card matching mockup', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Create Ward'), findsOneWidget);
    expect(find.text('Ward Name'), findsOneWidget);
    expect(find.byKey(const Key('wardNameInput')), findsOneWidget);
    expect(find.text('e.g. Ward B'), findsOneWidget);
    expect(find.byKey(const Key('createWardButton')), findsOneWidget);
    expect(find.text('CREATE WARD'), findsOneWidget);
  });

  testWidgets('Renders Wards section header with total count pill and default wards', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    expect(find.text('Wards'), findsOneWidget);
    expect(find.byKey(const Key('totalWardsCountPill')), findsOneWidget);
    expect(find.text('6 Wards'), findsOneWidget);

    // Initial default wards have no supervisor assigned -> displays Not Assigned badge
    expect(find.text('Not Assigned'), findsWidgets);
    expect(find.text('0 Workers'), findsWidgets);
    expect(find.text('ICU 1'), findsOneWidget);
  });

  testWidgets('Displays supervisor name when assigned and worker count per ward', (WidgetTester tester) async {
    // Seed a ward with supervisor
    final sup = UserModel(
      userId: 'sup-101',
      name: 'Neha Sharma',
      employeeId: 'SUP-101',
      email: 'neha@hospital.org',
      role: UserRole.supervisor,
      wardId: 'ward_icu_1',
      wardName: 'ICU 1',
      status: UserStatus.assigned,
    );
    final wrk = UserModel(
      userId: 'wrk-201',
      name: 'Ravi Kumar',
      employeeId: 'WRK-201',
      email: 'ravi@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu_1',
      wardName: 'ICU 1',
      status: UserStatus.available,
    );

    FirestoreService().seedWorker(sup);
    FirestoreService().seedWorker(wrk);

    final wardWithSup = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-101',
    );
    FirestoreService().seedWard(wardWithSup);

    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    // Verify supervisor name is shown for ICU 1
    expect(find.text('Neha Sharma'), findsOneWidget);
    expect(find.text('1 Worker'), findsOneWidget);
  });

  testWidgets('Admin creates new ward without supervisor initially', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    // Enter new ward name "Ward B"
    await tester.enterText(find.byKey(const Key('wardNameInput')), 'Ward B');
    await tester.pump();

    // Tap CREATE WARD
    await tester.tap(find.byKey(const Key('createWardButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Success feedback
    expect(find.textContaining('Ward "Ward B" created successfully.'), findsOneWidget);

    // Total wards count updated (6 default + 1 new = 7)
    expect(find.text('7 Wards'), findsOneWidget);

    // Newly created ward appears in list with Not Assigned badge
    expect(find.text('Ward B'), findsOneWidget);

    // Verify in FirestoreService that newly created ward has no supervisor
    final createdWard = await FirestoreService().getWard('ward_b');
    expect(createdWard, isNotNull);
    expect(createdWard?.name, 'Ward B');
    expect(createdWard?.supervisorId, isNull);
  });

  testWidgets('Validates empty ward name submission', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('createWardButton')));
    await tester.pump();

    expect(find.text('Please enter a ward name.'), findsOneWidget);
  });

  testWidgets('Validates duplicate ward name submission', (WidgetTester tester) async {
    await tester.pumpWidget(createWardScreen());
    await tester.pumpAndSettle();

    // "ICU 1" already exists
    await tester.enterText(find.byKey(const Key('wardNameInput')), 'ICU 1');
    await tester.pump();

    await tester.tap(find.byKey(const Key('createWardButton')));
    await tester.pump();

    expect(find.text('Ward "ICU 1" already exists.'), findsOneWidget);
  });
}
