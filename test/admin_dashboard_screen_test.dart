import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/admin_dashboard_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
import 'package:cleantrack/screens/pending_registrations_screen.dart';
import 'package:cleantrack/screens/supervisor_management_screen.dart';
import 'package:cleantrack/screens/ward_management_screen.dart';
import 'package:cleantrack/screens/worker_management_screen.dart';
import 'package:cleantrack/screens/monthly_reports_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdmin = UserModel(
    userId: 'admin-101',
    name: 'Rajesh Kumar',
    employeeId: 'ADM-001',
    email: 'rajesh.kumar@hospital.org',
    role: UserRole.admin,
    status: UserStatus.available,
  );

  Widget createAdminDashboard() {
    return MaterialApp(
      home: AdminDashboardScreen(
        user: testAdmin,
      ),
    );
  }

  setUp(() {
    AuthService().clearUsers();
  });

  testWidgets('Renders all Admin Dashboard header, dynamic snapshot, and destination tiles', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAdminDashboard());
    await tester.pumpAndSettle();

    // 1. Header
    expect(find.text('CleanTrack Admin'), findsOneWidget);
    expect(find.text('HOUSEKEEPING MANAGEMENT'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('RK'), findsOneWidget); // User initials from Rajesh Kumar

    // 2. Dashboard Title (without Live badge)
    expect(find.text('Admin Dashboard'), findsWidgets);
    expect(find.text('Hospital workforce overview'), findsOneWidget);
    expect(find.text('Live'), findsNothing); // Live button removed

    // 3. Workforce Snapshot (starts with real 0 counts, no hardcoded seeded numbers)
    expect(find.text('WORKFORCE SNAPSHOT'), findsOneWidget);
    expect(find.text('TOTAL WARDS'), findsOneWidget);
    expect(find.text('SUPERVISORS'), findsOneWidget);
    expect(find.text('WORKERS'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3)); // 0 total wards, 0 supervisors, 0 workers

    // 4. Quick Management Header & 5 destinations
    expect(find.text('QUICK MANAGEMENT'), findsOneWidget);
    expect(find.text('5 destinations'), findsOneWidget);

    // Destination 1: Pending registrations
    expect(find.byKey(const Key('pendingRegistrationsTile')), findsOneWidget);
    expect(find.text('Pending registrations'), findsOneWidget);
    expect(find.text('Review and assign personnel'), findsOneWidget);

    // Destination 2: Supervisor management
    expect(find.byKey(const Key('supervisorManagementTile')), findsOneWidget);
    expect(find.text('Supervisor management'), findsOneWidget);
    expect(find.text('Wards, teams and account status'), findsOneWidget);

    // Destination 3: Ward management
    expect(find.byKey(const Key('wardManagementTile')), findsOneWidget);
    expect(find.text('Ward management'), findsOneWidget);
    expect(find.text('Coverage across 0 wards'), findsOneWidget);

    // Destination 4: Worker management
    expect(find.byKey(const Key('workerManagementTile')), findsOneWidget);
    expect(find.text('Worker management'), findsOneWidget);
    expect(find.text('Roster, status and suspensions'), findsOneWidget);

    // Destination 5: Monthly ward reports
    expect(find.byKey(const Key('monthlyReportsTile')), findsOneWidget);
    expect(find.text('Monthly ward reports'), findsOneWidget);
    expect(find.textContaining('performance'), findsOneWidget);
  });

  testWidgets('Tapping destination tiles navigates to corresponding destination screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAdminDashboard());
    await tester.pumpAndSettle();

    // 1. Tap Pending registrations
    await tester.tap(find.byKey(const Key('pendingRegistrationsTile')));
    await tester.pumpAndSettle();
    expect(find.byType(PendingRegistrationsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 2. Tap Supervisor management
    await tester.tap(find.byKey(const Key('supervisorManagementTile')));
    await tester.pumpAndSettle();
    expect(find.byType(SupervisorManagementScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 3. Tap Ward management
    await tester.tap(find.byKey(const Key('wardManagementTile')));
    await tester.pumpAndSettle();
    expect(find.byType(WardManagementScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 4. Tap Worker management
    await tester.tap(find.byKey(const Key('workerManagementTile')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkerManagementScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 5. Tap Monthly reports
    await tester.tap(find.byKey(const Key('monthlyReportsTile')));
    await tester.pumpAndSettle();
    expect(find.byType(MonthlyReportsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin logout through header avatar PopupMenu redirects to LoginScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createAdminDashboard());
    await tester.pumpAndSettle();

    // Tap admin avatar popup menu button
    await tester.tap(find.byKey(const Key('adminLogoutButton')));
    await tester.pumpAndSettle();

    // Pop-up menu displays admin name, email, and LOG OUT action
    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);

    // Tap LOG OUT
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    // Confirms redirect to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
