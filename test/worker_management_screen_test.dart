import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/worker_management_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
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

  final testWards = [
    WardModel(wardId: 'ward_icu', name: 'ICU', supervisorId: 'sup-1'),
    WardModel(wardId: 'ward_a', name: 'Ward A', supervisorId: 'sup-2'),
    WardModel(wardId: 'ward_emergency', name: 'Emergency', supervisorId: 'sup-3'),
  ];

  final testWorkers = [
    UserModel(
      userId: 'wrk-125',
      name: 'Ravi Kumar',
      employeeId: 'WRK-125',
      email: 'ravi@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu',
      wardName: 'ICU',
      status: UserStatus.available,
    ),
    UserModel(
      userId: 'wrk-126',
      name: 'Aman Singh',
      employeeId: 'WRK-126',
      email: 'aman@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu',
      wardName: 'ICU',
      status: UserStatus.busy,
    ),
    UserModel(
      userId: 'wrk-130',
      name: 'Priya Sharma',
      employeeId: 'WRK-130',
      email: 'priya@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_emergency',
      wardName: 'Emergency',
      status: UserStatus.available,
    ),
    UserModel(
      userId: 'wrk-127',
      name: 'Sandeep Kumar',
      employeeId: 'WRK-127',
      email: 'sandeep@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_a',
      wardName: 'Ward A',
      status: UserStatus.suspended,
    ),
  ];

  Widget createWorkerScreen({UserModel? admin}) {
    return MaterialApp(
      home: WorkerManagementScreen(
        adminUser: admin ?? testAdmin,
      ),
    );
  }

  setUp(() {
    FirestoreService().clearAllData();
    AuthService().clearUsers();
  });

  testWidgets('Renders Worker Management AppBar with back button, notifications and admin initials avatar', (WidgetTester tester) async {
    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    expect(find.text('Worker Management'), findsOneWidget);
    expect(find.byKey(const Key('workerManagementBackButton')), findsOneWidget);
    expect(find.byKey(const Key('workerManagementNotificationButton')), findsOneWidget);
    expect(find.text('RK'), findsOneWidget); // Initials of Rajesh Kumar
  });

  testWidgets('Tapping notification button opens Admin Notifications dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workerManagementNotificationButton')));
    await tester.pumpAndSettle();

    expect(find.text('Admin Notifications'), findsOneWidget);
    expect(find.text('Housekeeping Workforce'), findsOneWidget);
    expect(find.text('Staff Roster Live'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Notifications'), findsNothing);
  });

  testWidgets('Renders subheader with title and active staff count pill', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    for (final worker in testWorkers) {
      FirestoreService().seedWorker(worker);
    }

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    expect(find.text('Manage Hospital Workers'), findsOneWidget);
    // 3 active (Ravi: available, Aman: busy, Priya: available), 1 suspended (Sandeep)
    expect(find.byKey(const Key('activeStaffCountPill')), findsOneWidget);
    expect(find.text('3 Staff Active'), findsOneWidget);
  });

  testWidgets('Renders ward filter tabs with All Wards and individual ward counts', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    for (final worker in testWorkers) {
      FirestoreService().seedWorker(worker);
    }

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Verify All Wards tab with total count 4
    expect(find.byKey(const Key('wardChip_all')), findsOneWidget);
    expect(find.text('All Wards (4)'), findsOneWidget);

    // Verify individual ward tabs
    expect(find.byKey(const Key('wardChip_ward_icu')), findsOneWidget);
    expect(find.text('ICU (2)'), findsOneWidget);

    expect(find.byKey(const Key('wardChip_ward_a')), findsOneWidget);
    expect(find.text('Ward A (1)'), findsOneWidget);

    expect(find.byKey(const Key('wardChip_ward_emergency')), findsOneWidget);
    expect(find.text('Emergency (1)'), findsOneWidget);
  });

  testWidgets('Displays all worker cards matching mockup when All Wards is selected', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    for (final worker in testWorkers) {
      FirestoreService().seedWorker(worker);
    }

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Card 1: Ravi Kumar, WRK-125, ICU, Available
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('ID: WRK-125'), findsOneWidget);
    expect(find.text('Available'), findsWidgets);

    // Card 2: Aman Singh, WRK-126, ICU, Busy
    expect(find.text('Aman Singh'), findsOneWidget);
    expect(find.text('ID: WRK-126'), findsOneWidget);
    expect(find.text('Busy'), findsOneWidget);

    // Card 3: Priya Sharma, WRK-130, Emergency, Available
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('ID: WRK-130'), findsOneWidget);

    // Card 4: Sandeep Kumar, WRK-127, Ward A, SUSPENDED
    expect(find.text('Sandeep Kumar'), findsOneWidget);
    expect(find.text('ID: WRK-127'), findsOneWidget);
    expect(find.text('SUSPENDED'), findsOneWidget);
  });

  testWidgets('Filtering by specific ward tab shows only workers belonging to that ward', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    for (final worker in testWorkers) {
      FirestoreService().seedWorker(worker);
    }

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Scroll and tap on ICU (2) tab
    await tester.ensureVisible(find.byKey(const Key('wardChip_ward_icu')));
    await tester.tap(find.byKey(const Key('wardChip_ward_icu')));
    await tester.pumpAndSettle();

    // Only ICU workers (Ravi Kumar and Aman Singh) should be visible
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Aman Singh'), findsOneWidget);

    // Other ward workers should be filtered out
    expect(find.text('Priya Sharma'), findsNothing);
    expect(find.text('Sandeep Kumar'), findsNothing);

    // Scroll and tap on Ward A (1) tab
    await tester.ensureVisible(find.byKey(const Key('wardChip_ward_a')));
    await tester.tap(find.byKey(const Key('wardChip_ward_a')));
    await tester.pumpAndSettle();

    expect(find.text('Sandeep Kumar'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);
    expect(find.text('Aman Singh'), findsNothing);
    expect(find.text('Priya Sharma'), findsNothing);

    // Scroll and tap on All Wards to reset
    await tester.ensureVisible(find.byKey(const Key('wardChip_all')));
    await tester.tap(find.byKey(const Key('wardChip_all')));
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('Aman Singh'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Sandeep Kumar'), findsOneWidget);
  });

  testWidgets('Displays clean empty state when no workers match the selected ward', (WidgetTester tester) async {
    final emptyWard = WardModel(wardId: 'ward_empty', name: 'Minor OT', supervisorId: 'sup-4');
    FirestoreService().seedWard(emptyWard);

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Scroll and tap on empty ward
    await tester.ensureVisible(find.byKey(const Key('wardChip_ward_empty')));
    await tester.tap(find.byKey(const Key('wardChip_ward_empty')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workerEmptyState')), findsOneWidget);
    expect(find.text('No workers found'), findsOneWidget);
    expect(find.text('No workers are currently assigned to this ward.'), findsOneWidget);
  });

  testWidgets('Does not show wards that are still not assigned a supervisor in ward filter tabs', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    // Seed a ward without a supervisor
    final unassignedWard = WardModel(wardId: 'ward_unassigned', name: 'General Ward', supervisorId: null);
    FirestoreService().seedWard(unassignedWard);

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Assigned wards must be shown
    expect(find.byKey(const Key('wardChip_ward_icu')), findsOneWidget);
    expect(find.byKey(const Key('wardChip_ward_a')), findsOneWidget);
    expect(find.byKey(const Key('wardChip_ward_emergency')), findsOneWidget);

    // Unassigned ward must NOT be shown
    expect(find.byKey(const Key('wardChip_ward_unassigned')), findsNothing);
    expect(find.textContaining('General Ward'), findsNothing);
  });

  testWidgets('Does not show workers whose verification is still pending by admin', (WidgetTester tester) async {
    for (final ward in testWards) {
      FirestoreService().seedWard(ward);
    }
    for (final worker in testWorkers) {
      FirestoreService().seedWorker(worker);
    }

    // Seed a worker whose verification is still pending
    final pendingWorker = UserModel(
      userId: 'wrk-pending-999',
      name: 'Pending Test Worker',
      employeeId: 'WRK-999',
      email: 'pending@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu',
      wardName: 'ICU',
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(pendingWorker);

    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    // Pending worker must not be visible in worker cards
    expect(find.text('Pending Test Worker'), findsNothing);
    expect(find.text('ID: WRK-999'), findsNothing);

    // Total count in All Wards must only count verified workers (4, not 5)
    expect(find.text('All Wards (4)'), findsOneWidget);

    // ICU count must only count verified workers (2, not 3)
    expect(find.text('ICU (2)'), findsOneWidget);

    // Active staff pill count must remain 3
    expect(find.text('3 Staff Active'), findsOneWidget);
  });

  testWidgets('Admin logout through header avatar PopupMenu redirects to LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(createWorkerScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adminLogoutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('rajesh@cleantrack.org'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);

    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
