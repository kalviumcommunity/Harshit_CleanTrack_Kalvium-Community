import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/supervisor_dashboard_screen.dart';
import 'package:cleantrack/screens/supervisor_worker_list_screen.dart';
import 'package:cleantrack/screens/supervisor_assign_task_screen.dart';
import 'package:cleantrack/screens/supervisor_pending_verification_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
import 'package:cleantrack/services/auth_service.dart';
import 'package:cleantrack/services/firestore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSupervisor = UserModel(
    userId: 'sup-101',
    name: 'Rajesh Kumar',
    employeeId: 'SUP-001',
    email: 'rajesh.kumar@hospital.org',
    role: UserRole.supervisor,
    status: UserStatus.assigned,
    wardId: 'ward-icu',
  );

  final testWard = WardModel(
    wardId: 'ward-icu',
    name: 'ICU Ward',
    supervisorId: 'sup-101',
  );

  late FirestoreService firestoreService;

  setUp(() {
    AuthService().clearUsers();
    firestoreService = FirestoreService();
    firestoreService.clearAllData();
    firestoreService.seedWard(testWard);
  });

  Widget createSupervisorDashboard({UserModel? user}) {
    return MaterialApp(
      home: SupervisorDashboardScreen(
        user: user ?? testSupervisor,
        firestoreService: firestoreService,
      ),
    );
  }

  testWidgets('Renders Supervisor Dashboard exactly matching the design mockup with supervisor name', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSupervisorDashboard());
    await tester.pumpAndSettle();

    // 1. App Bar Header
    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('HOUSEKEEPING MANAGEMENT'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('RK'), findsOneWidget);

    // 2. Title & Subtitle
    expect(find.text('Supervisor Dashboard'), findsOneWidget);
    expect(find.text('Hospital workforce overview'), findsOneWidget);

    // 3. Supervisor Info Card with Supervisor's Name
    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('ICU Ward'), findsWidgets);

    // 4. 2x2 Grid of Stat Cards
    expect(find.text('AVAILABLE WORKERS'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    expect(find.text('BUSY WORKERS'), findsOneWidget);
    expect(find.text('On task'), findsOneWidget);

    expect(find.text('PENDING VERIFY'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);

    expect(find.text('OVERDUE TASKS'), findsOneWidget);
    expect(find.text('Alert'), findsOneWidget);

    // 5. Action Buttons
    expect(find.byKey(const Key('viewWorkerListButton')), findsOneWidget);
    expect(find.text('View Worker List'), findsOneWidget);

    expect(find.byKey(const Key('assignTaskButton')), findsOneWidget);
    expect(find.text('Assign Task'), findsOneWidget);

    // 6. Pending Verification Tile
    expect(find.byKey(const Key('pendingVerificationTile')), findsOneWidget);
    expect(find.text('Pending Verification'), findsOneWidget);
  });

  testWidgets('Supervisor profile avatar PopupMenu matches Admin Dashboard style', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSupervisorDashboard());
    await tester.pumpAndSettle();

    // Tap supervisor profile avatar in top right
    await tester.tap(find.byKey(const Key('supervisorLogoutButton')));
    await tester.pumpAndSettle();

    // Displays supervisor name, email, divider, and LOG OUT button exactly like admin dashboard
    expect(find.text('Rajesh Kumar'), findsWidgets);
    expect(find.text('rajesh.kumar@hospital.org'), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    // Tapping LOG OUT redirects to LoginScreen
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Pending supervisor sees pending verification screen matching mockup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pendingSupervisor = UserModel(
      userId: 'sup-pending',
      name: 'Pooja Verma',
      employeeId: 'SUP-002',
      email: 'pooja@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );

    await tester.pumpWidget(createSupervisorDashboard(user: pendingSupervisor));
    await tester.pumpAndSettle();

    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('Hospital Housekeeping Management'), findsOneWidget);
    expect(find.text('Dashboard access will become available after an administrator verifies your identity.'), findsOneWidget);
    expect(find.text('BACK TO LOGIN'), findsOneWidget);
  });

  testWidgets('Tapping View Worker List navigates to SupervisorWorkerListScreen placeholder', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSupervisorDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('viewWorkerListButton')));
    await tester.pumpAndSettle();

    expect(find.byType(SupervisorWorkerListScreen), findsOneWidget);
    expect(find.text('Worker List'), findsWidgets);
  });

  testWidgets('Tapping Assign Task navigates to SupervisorAssignTaskScreen placeholder', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSupervisorDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assignTaskButton')));
    await tester.pumpAndSettle();

    expect(find.byType(SupervisorAssignTaskScreen), findsOneWidget);
    expect(find.text('Assign Task'), findsWidgets);
  });

  testWidgets('Tapping Pending Verification tile navigates to SupervisorPendingVerificationScreen placeholder', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createSupervisorDashboard());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pendingVerificationTile')));
    await tester.pumpAndSettle();

    expect(find.byType(SupervisorPendingVerificationScreen), findsOneWidget);
    expect(find.text('Pending Verification'), findsWidgets);
  });
}
